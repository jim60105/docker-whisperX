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
# Python stage for all bases
########################################
FROM registry.access.redhat.com/ubi9/ubi-minimal AS python

# RUN mount cache for multi-arch: https://github.com/docker/buildx/issues/549#issuecomment-1788297892
ARG TARGETARCH
ARG TARGETVARIANT

ENV PYTHON_VERSION=3.11
ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=UTF-8

RUN --mount=type=cache,id=dnf-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/var/cache/dnf \
    microdnf -y upgrade --refresh --best --nodocs --noplugins --setopt=install_weak_deps=0 && \
    microdnf -y install --setopt=install_weak_deps=0 --setopt=tsflags=nodocs \
    python3.11
RUN ln -s /usr/bin/python3.11 /usr/bin/python3 && \
    ln -s /usr/bin/python3.11 /usr/bin/python

########################################
# Base stage for amd64
# Only install CUDA for amd64
# https://github.com/jim60105/docker-whisperX/issues/69
########################################
FROM python AS prepare_base_amd64

# RUN mount cache for multi-arch: https://github.com/docker/buildx/issues/549#issuecomment-1788297892
ARG TARGETARCH
ARG TARGETVARIANT

ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

WORKDIR /tmp

ENV CUDA_VERSION=12.6.3
ENV NV_CUDA_CUDART_VERSION=12.6.77-1
ENV NVIDIA_REQUIRE_CUDA=cuda>=12.6
ENV NV_CUDA_COMPAT_PACKAGE=cuda-compat-12-6

# Install CUDA partially
# https://docs.nvidia.com/cuda/cuda-installation-guide-linux/#network-repo-installation-for-rhel-rocky

RUN --mount=type=cache,id=dnf-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/var/cache/dnf \
    rpm --import https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/D42D0685.pub && \
    curl -o /etc/yum.repos.d/cuda-rhel9.repo https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/cuda-rhel9.repo && \
    microdnf -y upgrade --refresh --best --nodocs --noplugins --setopt=install_weak_deps=0 && \
    microdnf -y install --setopt=install_weak_deps=0 --setopt=tsflags=nodocs \
    # Installing the whole CUDA typically increases the image size by approximately **8GB**.
    # To decrease the image size, we opt to install only the necessary libraries.
    # Here is the package list for your reference: https://developer.download.nvidia.com/compute/cuda/repos/rhel9/x86_64/
    # !If you experience any related issues, replace the following line with `cuda-12-6` to obtain the complete CUDA package.
    cuda-cudart-12-6-${NV_CUDA_CUDART_VERSION} ${NV_CUDA_COMPAT_PACKAGE} libcudnn9-cuda-12 libcusparselt0 libcusparse-12-6 cuda-cupti-12-6 libcufft-12-6 libcurand-12-6 libcublas-12-6 libnccl libnvjitlink-12-6

ENV PATH="/usr/local/cuda-12.6/bin${PATH:+:${PATH}}"
ENV LD_LIBRARY_PATH=/venv/lib/python3.11/site-packages/nvidia/cudnn/lib:/usr/local/cuda-12.6/lib64${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}

########################################
# Base stage for arm64
########################################
FROM python AS prepare_base_arm64

# RUN mount cache for multi-arch: https://github.com/docker/buildx/issues/549#issuecomment-1788297892
ARG TARGETARCH
ARG TARGETVARIANT

# Missing dependencies for arm64
# https://github.com/jim60105/docker-whisperX/issues/14
RUN --mount=type=cache,id=dnf-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/var/cache/dnf \
    microdnf -y install --setopt=install_weak_deps=0 --setopt=tsflags=nodocs \
    libgomp libsndfile

# Select the base stage by target architecture
FROM prepare_base_$TARGETARCH$TARGETVARIANT AS base

########################################
# Build stage for amd64
########################################
FROM base AS prepare_build_amd64

# RUN mount cache for multi-arch: https://github.com/docker/buildx/issues/549#issuecomment-1788297892
ARG TARGETARCH
ARG TARGETVARIANT

WORKDIR /app

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV UV_PROJECT_ENVIRONMENT=/venv
ENV VIRTUAL_ENV=/venv
ENV UV_LINK_MODE=copy
ENV UV_PYTHON_DOWNLOADS=0
ENV UV_INDEX=https://download.pytorch.org/whl/cu126

# Install torch separately as required
RUN --mount=type=cache,id=uv-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/root/.cache/uv \
    uv venv --system-site-packages /venv && \
    uv pip install --no-deps \
    torch==2.6.0+cu126 \
    pyannote.audio==3.3.2

# Install whisperX dependencies
RUN --mount=type=cache,id=uv-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/root/.cache/uv \
    --mount=type=bind,source=whisperX/pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=whisperX/uv.lock,target=uv.lock \
    uv sync --frozen --no-dev --no-install-project --no-editable

# Install whisperX project
RUN --mount=type=cache,id=uv-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/root/.cache/uv \
    --mount=source=whisperX,target=.,rw \
    uv sync --frozen --no-dev --no-editable

########################################
# Build stage for arm64
########################################
FROM base AS prepare_build_arm64

# RUN mount cache for multi-arch: https://github.com/docker/buildx/issues/549#issuecomment-1788297892
ARG TARGETARCH
ARG TARGETVARIANT

WORKDIR /app

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ENV UV_PROJECT_ENVIRONMENT=/venv
ENV VIRTUAL_ENV=/venv
ENV UV_LINK_MODE=copy
ENV UV_PYTHON_DOWNLOADS=0
ENV UV_INDEX=https://download.pytorch.org/whl/cpu

# Install torch separately as required
RUN --mount=type=cache,id=uv-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/root/.cache/uv \
    uv venv --system-site-packages /venv && \
    uv pip install --no-deps \
    torch==2.6.0+cpu \
    pyannote.audio==3.3.2

# Install whisperX dependencies
RUN --mount=type=cache,id=uv-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/root/.cache/uv \
    --mount=type=bind,source=whisperX/pyproject.toml,target=pyproject.toml,rw \
    --mount=type=bind,source=whisperX/uv.lock,target=uv.lock,rw \
    uv add torch==2.6.0+cpu && \
    uv sync --frozen --no-dev --no-install-project --no-editable

# Install whisperX project
RUN --mount=type=cache,id=uv-$TARGETARCH$TARGETVARIANT,sharing=locked,target=/root/.cache/uv \
    --mount=source=whisperX,target=.,rw \
    uv add torch==2.6.0+cpu && \
    uv sync --frozen --no-dev --no-editable

# Select the build stage by target architecture
FROM prepare_build_$TARGETARCH$TARGETVARIANT AS build

########################################
# Final stage for no_model
########################################
FROM base AS no_model

ARG CACHE_HOME
ARG CONFIG_HOME
ARG TORCH_HOME
ARG HF_HOME
ENV XDG_CACHE_HOME=${CACHE_HOME}
ENV TORCH_HOME=${TORCH_HOME}
ENV HF_HOME=${HF_HOME}

ARG UID
RUN install -d -m 775 -o $UID -g 0 /licenses && \
    install -d -m 775 -o $UID -g 0 /root && \
    install -d -m 775 -o $UID -g 0 ${CACHE_HOME} && \
    install -d -m 775 -o $UID -g 0 ${CONFIG_HOME}

# ffmpeg
COPY --from=ghcr.io/jim60105/static-ffmpeg-upx:7.1 /ffmpeg /usr/local/bin/
# COPY --from=ghcr.io/jim60105/static-ffmpeg-upx:7.1 /ffprobe /usr/local/bin/

# dumb-init
COPY --from=ghcr.io/jim60105/static-ffmpeg-upx:7.1 /dumb-init /usr/local/bin/

# Copy licenses (OpenShift Policy)
COPY --chown=$UID:0 --chmod=775 LICENSE /licenses/LICENSE
COPY --chown=$UID:0 --chmod=775 whisperX/LICENSE /licenses/whisperX.LICENSE

# Copy dependencies and code (and support arbitrary uid for OpenShift best practice)
# https://docs.openshift.com/container-platform/4.14/openshift_images/create-images.html#use-uid_create-images
COPY --chown=$UID:0 --chmod=775 --from=build /venv /venv

ENV PATH="/venv/bin${PATH:+:${PATH}}"
ENV PYTHONPATH="/venv/lib/python3.11/site-packages"

# Test whisperX
RUN python3 -c 'import whisperx;' && \
    whisperx -h

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
COPY --chown=$UID:0 --chmod=775 --from=load_align ${CACHE_HOME} ${CACHE_HOME}

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
