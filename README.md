# docker-whisperX

This is the Docker image for [WhisperX: Automatic Speech Recognition with Word-Level Timestamps (and Speaker Diarization)](https://github.com/m-bain/whisperX)

## Building the Docker Image

> [!IMPORTANT]
> Clone the Git repository recursively to include submodules:\
> `git clone --recursive https://github.com/jim60105/docker-whisperX.git`

This Dockerfile builds the image with contained models. The Dockerfile accepts two build arguments: `LANG` and `WHISPER_MODEL`.

- `LANG`: The language to transcribe. The default is `en`. See [here](load_align_model.py) for supported languages.

- `WHISPER_MODEL`: The model name. The default is `base`. See [fast-whisper](https://huggingface.co/guillaumekln) for supported models.

## Usage Example

Build the image with `ja` language and `large-v2` model:

```bash
docker build --build-arg LANG=ja --build-arg WHISPER_MODEL=large-v2 -t whisperx:largev2-ja .
```

Mount the current directory to `/app` and run WhisperX with other arguments and audio:

```bash
docker run --gpus all -it -v "$(PWD):/app" whisperx:largev2-ja -- --output_format srt audio.mp3
```

> [!NOTE]
> Remember to prepend `--` before the arguments.\
> `--model` and `--language` args are defined in Dockerfile, no need to specify.

## LICENSE

The main program, WhisperX, is distributed under the BSD-4 license. Please refer to the git submodules for their respective source code licenses.

The Dockerfile from this repository is licensed under MIT.
