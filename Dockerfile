ARG WHISPER_MODEL=base
ARG LANG=en
ARG TORCH_HOME=/cache/torch
ARG HF_HOME=/cache/huggingface

FROM python:3.10-slim as dependencies

# Setup venv
RUN python3 -m venv /venv
ARG PATH="/venv/bin:$PATH"
RUN python3 -m pip install --upgrade pip setuptools
# Install requirements
RUN python3 -m pip install torch torchaudio --extra-index-url https://download.pytorch.org/whl/cu118

# Add git
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends git

# Install whisperX
COPY ./whisperX /code
RUN python3 -m pip install /code


FROM dependencies as load_model

ARG TORCH_HOME
ARG HF_HOME
ARG PATH="/venv/bin:$PATH"

# Preload vad model
RUN python3 -c 'from whisperx.vad import load_vad_model; load_vad_model("cpu");'

# Preload fast-whisper
ARG WHISPER_MODEL
RUN python3 -c 'import faster_whisper; model = faster_whisper.WhisperModel("'${WHISPER_MODEL}'")'

# Preload align model
ARG LANG
COPY load_align_model.py .
RUN python3 load_align_model.py ${LANG}


FROM python:3.10-slim

# Copy and use venv
COPY --from=dependencies /venv /venv
ARG PATH="/venv/bin:$PATH"
ENV PATH=${PATH}

# Non-root user
RUN useradd -m -s /bin/bash appuser
USER appuser

COPY --chown=appuser --from=load_model /cache /cache

WORKDIR /app
ARG TORCH_HOME
ARG HF_HOME
ENV TORCH_HOME=${TORCH_HOME}
ENV HF_HOME=${HF_HOME}

# ffmpeg
COPY --link --from=mwader/static-ffmpeg:6.0 /ffmpeg /usr/local/bin/
COPY --link --from=mwader/static-ffmpeg:6.0 /ffprobe /usr/local/bin/

ARG WHISPER_MODEL
ENV WHISPER_MODEL=${WHISPER_MODEL}
ARG LANG
ENV LANG=${LANG}

STOPSIGNAL SIGINT
ENTRYPOINT whisperx --model ${WHISPER_MODEL} --language ${LANG} $@
