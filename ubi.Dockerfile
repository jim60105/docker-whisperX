# syntax=docker/dockerfile:1
ARG WHISPER_MODEL=base
ARG LANG=en
ARG UID=1001
ARG GIT_SHA

# These ARGs are for caching stage builds in CI
# Leave them as is when building locally
ARG LOAD_WHISPER_STAGE=load_whisper
ARG NO_MODEL_STAGE=no_model

# When downloading diarization model with auth token, it seems that it is not respecting the TORCH_HOME env variable.
# So it is necessary to ensure that the CACHE_HOME is set to the exact same path as the default path.
# https://github.com/jim60105/docker-whisperX/issues/27
ARG CACHE_HOME=/.cache
ARG CONFIG_HOME=/.config
ARG TORCH_HOME=${CACHE_HOME}/torch
ARG HF_HOME=${CACHE_HOME}/huggingface

######
# Base stage
######
FROM registry.access.redhat.com/ubi9/ubi-minimal as base

ENV PYTHON_VERSION=3.11
ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=UTF-8

ARG GIT_SHA
LABEL name="jim60105/docker-whisperX" \
    # Authors for WhisperX
    vendor="Bain, Max and Huh, Jaesung and Han, Tengda and Zisserman, Andrew" \
    # Maintainer for this docker image
    maintainer="jim60105" \
    # Dockerfile source repository
    url="https://github.com/jim60105/docker-whisperX" \
    version="ubi-no_model" \
    # This should be a number, but we are using the git sha for convenience here.
    release=${GIT_SHA} \
    io.k8s.display-name="WhisperX" \
    summary="WhisperX: Time-Accurate Speech Transcription of Long-Form Audio" \
    description="This is the docker image for WhisperX: Automatic Speech Recognition with Word-Level Timestamps (and Speaker Diarization) from the community. For more information about this tool, please visit the following website: https://github.com/m-bain/whisperX."

RUN microdnf -y upgrade --refresh --best --nodocs --noplugins --setopt=install_weak_deps=0 && \
    microdnf -y install --setopt=install_weak_deps=0 --setopt=tsflags=nodocs python3.11 && \
    microdnf -y clean all
RUN ln -s /usr/bin/python3.11 /usr/bin/python3 && \
    ln -s /usr/bin/python3.11 /usr/bin/python

# Missing dependencies for arm64
# https://github.com/jim60105/docker-whisperX/issues/14
ARG TARGETPLATFORM
RUN if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
    microdnf -y install libgomp libsndfile && microdnf clean all; \
    fi

######
# Build stage
######
FROM base as build

# Install build time requirements
RUN microdnf -y install --setopt=install_weak_deps=0 --setopt=tsflags=nodocs git python3.11-pip findutils && \
    microdnf -y clean all

# RUN mount cache for multi-arch: https://github.com/docker/buildx/issues/549#issuecomment-1788297892
ARG TARGETARCH
ARG TARGETVARIANT

WORKDIR /app

# Install under /root/.local
ENV PIP_USER="true"
ARG PIP_NO_WARN_SCRIPT_LOCATION=0
ARG PIP_ROOT_USER_ACTION="ignore"

# Install requirements
RUN --mount=type=cache,id=pip-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/root/.cache/pip \
    pip3.11 install --extra-index-url https://download.pytorch.org/whl/cu118 \
    torch==2.1.1 torchaudio==2.1.1 pyannote.audio==3.1.1

RUN --mount=type=cache,id=pip-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/root/.cache/pip \
    --mount=source=whisperX/requirements.txt,target=requirements.txt \
    pip3.11 install -r requirements.txt

# Install whisperX
RUN --mount=type=cache,id=pip-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/root/.cache/pip \
    --mount=source=whisperX,target=.,rw \
    pip3.11 install . && \
    # Cleanup
    find "/root/.local" -name '*.pyc' -print0 | xargs -0 rm -f || true ; \
    find "/root/.local" -type d -name '__pycache__' -print0 | xargs -0 rm -rf || true ;

######
# Final stage for no_model
######
FROM base as no_model

ARG UID

# ffmpeg
COPY --link --from=mwader/static-ffmpeg:6.1.1 /ffmpeg /usr/local/bin/
COPY --link --from=mwader/static-ffmpeg:6.1.1 /ffprobe /usr/local/bin/

# Copy dist and support arbitrary user ids (OpenShift best practice)
# https://docs.openshift.com/container-platform/4.14/openshift_images/create-images.html#use-uid_create-images
COPY --chmod=775 \
    --from=build /root/.local /root/.local
ENV PATH="/root/.local/bin:$PATH"
ENV PYTHONPATH="${PYTHONPATH}:/root/.local/lib/python3.11/site-packages" 

RUN install -d -m 775 -o $UID -g 0 /licenses
COPY --chmod=775 LICENSE /licenses/LICENSE
COPY --chmod=775 whisperX/LICENSE /licenses/whisperX.LICENSE

ARG CACHE_HOME
ARG CONFIG_HOME
ARG TORCH_HOME
ARG HF_HOME
ENV XDG_CACHE_HOME=${CACHE_HOME}
ENV TORCH_HOME=${TORCH_HOME}
ENV HF_HOME=${HF_HOME}

RUN install -d -m 775 -o $UID -g 0 ${CACHE_HOME} && \
    install -d -m 775 -o $UID -g 0 ${CONFIG_HOME}

ARG WHISPER_MODEL
ENV WHISPER_MODEL=
ARG LANG
ENV LANG=

USER $UID
WORKDIR /app
VOLUME [ "/app" ]

STOPSIGNAL SIGINT
ENTRYPOINT ["sh", "-c", "whisperx \"$@\""]

######
# load_whisper stage: This stage will be tagged for caching in CI.
######
FROM ${NO_MODEL_STAGE} as load_whisper

ARG TORCH_HOME
ARG HF_HOME

# Preload vad model
RUN python3 -c 'from whisperx.vad import load_vad_model; load_vad_model("cpu");'

# Preload fast-whisper
ARG WHISPER_MODEL
RUN python3 -c 'import faster_whisper; model = faster_whisper.WhisperModel("'${WHISPER_MODEL}'")'

######
# load_align stage
######
FROM ${LOAD_WHISPER_STAGE} as load_align

ARG TORCH_HOME
ARG HF_HOME

# Preload align models
ARG LANG

RUN --mount=source=load_align_model.py,target=load_align_model.py \
    for i in ${LANG}; do echo "Aliging lang $i"; python3 load_align_model.py "$i"; done

######
# Final stage with model
######
FROM ${NO_MODEL_STAGE} as final

ARG UID

ARG CACHE_HOME
COPY --link --chown=$UID:0 --chmod=775 \
    --from=load_align ${CACHE_HOME} ${CACHE_HOME}

ARG WHISPER_MODEL
ENV WHISPER_MODEL=${WHISPER_MODEL}
ARG LANG
ENV LANG=${LANG}

# Take the first language from LANG env variable
ENTRYPOINT ["sh", "-c", "LANG=$(echo ${LANG} | cut -d ' ' -f1); whisperx --model \"${WHISPER_MODEL}\" --language \"${LANG}\" \"$@\""]