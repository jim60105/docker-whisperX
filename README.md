# docker-whisperX

## Description

This is a Docker image for [WhisperX](https://github.com/m-bain/whisperX): Automatic Speech Recognition with Word-Level Timestamps (and Speaker Diarization)

> [!IMPORTANT]
> Clone the Git repository recursively to include submodules:\
> `git clone --recursive https://github.com/jim60105/docker-whisperX.git`

## Building the Docker Image

This Dockerfile builds the image with contained models. The Dockerfile accepts two build arguments: `LANG` and `WHISPER_MODEL`.

- `LANG`: The language to transcribe. The default is `en`. See [here](load_align_model.py) for supported languages.

- `WHISPER_MODEL`: The model name. The default is `base`. See [fast-whisper](https://huggingface.co/guillaumekln) for supported models.

## Usage Example

Build the image with `ja` language and `large-v2` model:

```bash
docker build --build-arg LANG=ja --build-arg WHISPER_MODEL=large-v2 -t whisperx:largev2-ja .
```

Mount the current directory to `/app` and run WhisperX with other arguments and audio:

> [!NOTE]
> Remember to prepend `--` before the arguments.\
> `--model` and `--language` args are defined in Dockerfile, no need to specify.

```bash
docker run --gpus all -it -v "$(PWD):/app" whisperx:largev2-ja -- --output_format srt audio.mp3
```
