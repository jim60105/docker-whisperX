ARG LANG=en

# Base image
FROM nvcr.io/nvidia/pytorch:23.07-py3 as base
ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /app

# Install requirements
COPY ./whisperX/requirements.txt .
RUN python3 -m pip install --no-cache-dir -r ./requirements.txt ujson

# Preload fast-whisper
ARG WHISPER_MODEL=tiny.en
RUN python3 -c 'import faster_whisper; model = faster_whisper.WhisperModel("'${WHISPER_MODEL}'")'

# Preload align model
FROM base AS align-en
ARG ALIGN_MODEL=WAV2VEC2_ASR_BASE_960H
RUN python3 -c 'import torchaudio; bundle = torchaudio.pipelines.__dict__["'${ALIGN_MODEL}'"]; align_model = bundle.get_model(); labels = bundle.get_labels()'

FROM base AS align-fr
ARG ALIGN_MODEL=VOXPOPULI_ASR_BASE_10K_FR
RUN python3 -c 'import torchaudio; bundle = torchaudio.pipelines.__dict__["'${ALIGN_MODEL}'"]; align_model = bundle.get_model(); labels = bundle.get_labels()'

FROM base AS align-de
ARG ALIGN_MODEL=VOXPOPULI_ASR_BASE_10K_DE
RUN python3 -c 'import torchaudio; bundle = torchaudio.pipelines.__dict__["'${ALIGN_MODEL}'"]; align_model = bundle.get_model(); labels = bundle.get_labels()'

FROM base AS align-es
ARG ALIGN_MODEL=VOXPOPULI_ASR_BASE_10K_ES
RUN python3 -c 'import torchaudio; bundle = torchaudio.pipelines.__dict__["'${ALIGN_MODEL}'"]; align_model = bundle.get_model(); labels = bundle.get_labels()'

FROM base AS align-it
ARG ALIGN_MODEL=VOXPOPULI_ASR_BASE_10K_IT
RUN python3 -c 'import torchaudio; bundle = torchaudio.pipelines.__dict__["'${ALIGN_MODEL}'"]; align_model = bundle.get_model(); labels = bundle.get_labels()'

FROM base AS align-ja
ARG ALIGN_MODEL=jonatasgrosman/wav2vec2-large-xlsr-53-japanese
RUN python3 -c 'from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor; processor = Wav2Vec2Processor.from_pretrained("'${ALIGN_MODEL}'"); align_model = Wav2Vec2ForCTC.from_pretrained("'${ALIGN_MODEL}'")'

FROM base AS align-zh
ARG ALIGN_MODEL=jonatasgrosman/wav2vec2-large-xlsr-53-chinese-zh-cn
RUN python3 -c 'from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor; processor = Wav2Vec2Processor.from_pretrained("'${ALIGN_MODEL}'"); align_model = Wav2Vec2ForCTC.from_pretrained("'${ALIGN_MODEL}'")'

FROM align-${LANG} AS final

# Install whisperX
COPY ./whisperX/ .
RUN python3 -m pip install --no-cache-dir .

# Create and switch to a non-root user
RUN useradd -m -s /bin/bash appuser
USER appuser

STOPSIGNAL SIGINT
ENTRYPOINT [ "whisperx" ]
