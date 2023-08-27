ARG WHISPER_MODEL=base
ARG LANG=en

FROM nvcr.io/nvidia/pytorch:23.05-py3 as base
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app
ENV TORCH_HOME=/cache/torch
ENV HF_HOME=/cache/huggingface

# ffmpeg
COPY --link --from=mwader/static-ffmpeg:6.0 /ffmpeg /usr/local/bin/
COPY --link --from=mwader/static-ffmpeg:6.0 /ffprobe /usr/local/bin/

# Install requirements
COPY ./whisperX/requirements.txt .
RUN python3 -m pip install --no-cache-dir -r ./requirements.txt ujson torch==2.0.1 torchvision==0.15.2 torchaudio==2.0.2

FROM base AS load_model

# Preload fast-whisper
ARG WHISPER_MODEL
RUN python3 -c 'import faster_whisper; model = faster_whisper.WhisperModel("'${WHISPER_MODEL}'")'

# Preload align model
ARG LANG
COPY load_align_model.py .
RUN python load_align_model.py ${LANG}

FROM base AS final

# Install whisperX
COPY ./whisperX/ .
RUN python3 -m pip install --no-cache-dir .

# Non-root user
RUN useradd -m -s /bin/bash appuser
USER appuser

COPY --chown=appuser --from=load_model /cache /cache

ARG WHISPER_MODEL
ENV WHISPER_MODEL=${WHISPER_MODEL}
ARG LANG
ENV LANG=${LANG}

STOPSIGNAL SIGINT
ENTRYPOINT whisperx --model ${WHISPER_MODEL} --language ${LANG} $*
