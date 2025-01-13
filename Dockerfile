# syntax=docker/dockerfile:1
ARG WHISPER_MODEL=base
ARG LANG=en
ARG UID=1001
ARG VERSION=EDGE
ARG RELEASE=0

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

########################################
# Base stage
########################################
FROM python:3.11-slim AS base

# RUN mount cache for multi-arch: https://github.com/docker/buildx/issues/549#issuecomment-1788297892
ARG TARGETARCH
ARG TARGETVARIANT

# Missing dependencies for arm64 (needed for build-time and run-time)
# https://github.com/jim60105/docker-whisperX/issues/14
ARG TARGETPLATFORM
RUN --mount=type=cache,id=apt-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/var/cache/apt \
    --mount=type=cache,id=aptlists-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/var/lib/apt/lists \
    if [ "$TARGETPLATFORM" = "linux/arm64" ]; then \
    apt-get update && apt-get install -y --no-install-recommends \
    libgomp1=12.2.0-14 libsndfile1=1.2.0-1; \
    fi

########################################
# Build stage
########################################
FROM base AS build

# RUN mount cache for multi-arch: https://github.com/docker/buildx/issues/549#issuecomment-1788297892
ARG TARGETARCH
ARG TARGETVARIANT

WORKDIR /app

# Install under /root/.local
ARG PIP_USER="true"
ARG PIP_NO_WARN_SCRIPT_LOCATION=0
ARG PIP_ROOT_USER_ACTION="ignore"
ARG PIP_NO_COMPILE="true"
ARG PIP_NO_BINARY="all"
ARG PIP_DISABLE_PIP_VERSION_CHECK="true"

# Install requirements
RUN --mount=type=cache,id=pip-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/root/.cache/pip \
    pip install -U --force-reinstall pip setuptools wheel && \
    pip install -U --extra-index-url https://download.pytorch.org/whl/cu121 \
    torch==2.2.2 torchaudio==2.2.2 \
    pyannote.audio==3.1.1 \
    # https://github.com/jim60105/docker-whisperX/issues/40
    "numpy<2.0"

RUN --mount=type=cache,id=pip-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/root/.cache/pip \
    --mount=source=whisperX/requirements.txt,target=requirements.txt \
    pip install -r requirements.txt

# Install whisperX
RUN --mount=type=cache,id=pip-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/root/.cache/pip \
    --mount=source=whisperX,target=.,rw \
    --mount=type=tmpfs,target=/tmp \
    pip install .

# Test whisperX
RUN python3 -c 'import whisperx;'

########################################
# Final stage for no_model
########################################
FROM base AS no_model

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# We don't need them anymore
RUN pip3.11 uninstall -y pip wheel && \
    rm -rf /root/.cache/pip

# Create user
ARG UID
RUN groupadd -g $UID $UID && \
    useradd -l -u $UID -g $UID -m -s /bin/sh -N $UID

ARG CACHE_HOME
ARG CONFIG_HOME
ARG TORCH_HOME
ARG HF_HOME
ENV XDG_CACHE_HOME=${CACHE_HOME}
ENV TORCH_HOME=${TORCH_HOME}
ENV HF_HOME=${HF_HOME}

RUN install -d -m 775 -o $UID -g 0 /licenses && \
    install -d -m 775 -o $UID -g 0 /root && \
    install -d -m 775 -o $UID -g 0 ${CACHE_HOME} && \
    install -d -m 775 -o $UID -g 0 ${CONFIG_HOME}

# ffmpeg
COPY --link --from=ghcr.io/jim60105/static-ffmpeg-upx:7.1 /ffmpeg /usr/local/bin/
# COPY --link --from=ghcr.io/jim60105/static-ffmpeg-upx:7.1 /ffprobe /usr/local/bin/

# dumb-init
COPY --link --from=ghcr.io/jim60105/static-ffmpeg-upx:7.1 /dumb-init /usr/local/bin/

# Copy licenses (OpenShift Policy)
COPY --link --chown=$UID:0 --chmod=775 LICENSE /licenses/LICENSE
COPY --link --chown=$UID:0 --chmod=775 whisperX/LICENSE /licenses/whisperX.LICENSE

# Copy dependencies and code (and support arbitrary uid for OpenShift best practice)
# https://docs.openshift.com/container-platform/4.14/openshift_images/create-images.html#use-uid_create-images
COPY --link --chown=$UID:0 --chmod=775 --from=build /root/.local /home/$UID/.local

ENV PATH="/home/$UID/.local/bin:$PATH"
ENV PYTHONPATH="/home/$UID/.local/lib/python3.11/site-packages"

WORKDIR /app

VOLUME [ "/app" ]

USER $UID

STOPSIGNAL SIGINT

ENTRYPOINT [ "dumb-init", "--", "/bin/sh", "-c", "whisperx \"$@\"" ]

ARG VERSION
ARG RELEASE
LABEL name="jim60105/docker-whisperX" \
    # Authors for WhisperX
    vendor="Bain, Max and Huh, Jaesung and Han, Tengda and Zisserman, Andrew" \
    # Maintainer for this docker image
    maintainer="jim60105" \
    # Dockerfile source repository
    url="https://github.com/jim60105/docker-whisperX" \
    version=${VERSION} \
    # This should be a number, incremented with each change
    release=${RELEASE} \
    io.k8s.display-name="WhisperX" \
    summary="WhisperX: Time-Accurate Speech Transcription of Long-Form Audio" \
    description="This is the docker image for WhisperX: Automatic Speech Recognition with Word-Level Timestamps (and Speaker Diarization) from the community. For more information about this tool, please visit the following website: https://github.com/m-bain/whisperX."

########################################
# load_whisper stage
# This stage will be tagged for caching in CI.
########################################
FROM ${NO_MODEL_STAGE} AS load_whisper

ARG CONFIG_HOME
ARG XDG_CONFIG_HOME=${CONFIG_HOME}
ARG HOME="/root"

# Preload Silero vad model
RUN python3 <<EOF
import torch
torch.hub.load(repo_or_dir='snakers4/silero-vad',
               model='silero_vad',
               force_reload=False,
               onnx=False,
               trust_repo=True)
EOF

# Preload fast-whisper
ARG WHISPER_MODEL
ENV WHISPER_MODEL=${WHISPER_MODEL}

# Preload fast-whisper
RUN echo "Preload whisper model: ${WHISPER_MODEL}" && \
    python3 -c "import faster_whisper; model = faster_whisper.WhisperModel('${WHISPER_MODEL}')"

########################################
# load_align stage
########################################
FROM ${LOAD_WHISPER_STAGE} AS load_align

ARG LANG
ENV LANG=${LANG}

# Preload align models
RUN --mount=source=load_align_model.py,target=load_align_model.py \
    for i in ${LANG}; do echo "Preload align model: $i"; python3 load_align_model.py "$i"; done

########################################
# Final stage with model
########################################
FROM ${NO_MODEL_STAGE} AS final

ARG UID

ARG CACHE_HOME
COPY --link --chown=$UID:0 --chmod=775 --from=load_align ${CACHE_HOME} ${CACHE_HOME}

ARG LANG
ENV LANG=${LANG}
ARG WHISPER_MODEL
ENV WHISPER_MODEL=${WHISPER_MODEL}

# Take the first language from LANG env variable
ENTRYPOINT [ "dumb-init", "--", "/bin/sh", "-c", "LANG=$(echo ${LANG} | cut -d ' ' -f1); whisperx --model \"${WHISPER_MODEL}\" --language \"${LANG}\" \"$@\"" ]

ARG VERSION
ARG RELEASE
LABEL version=${VERSION} \
    release=${RELEASE}
