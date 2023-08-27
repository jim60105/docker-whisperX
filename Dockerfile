# Base image
FROM nvcr.io/nvidia/pytorch:23.07-py3
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app

# Install requirements
COPY ./whisperX/requirements.txt .
RUN python3 -m pip install --no-cache-dir -r ./requirements.txt ujson

# Preload fast-whisper
ARG WHISPER_MODEL=base
RUN python3 -c 'import faster_whisper; model = faster_whisper.WhisperModel("'${WHISPER_MODEL}'")'

# Preload align model
ARG LANG=en
COPY load_align_model.py .
RUN python load_align_model.py ${LANG}

# Install whisperX
COPY ./whisperX/ .
RUN python3 -m pip install --no-cache-dir .

# Create and switch to a non-root user
RUN useradd -m -s /bin/bash appuser
USER appuser

STOPSIGNAL SIGINT
ENTRYPOINT [ "whisperx" ]
