# docker-whisperX

This is the Docker image for [WhisperX: Automatic Speech Recognition with Word-Level Timestamps (and Speaker Diarization)](https://github.com/m-bain/whisperX)

Get the Dockerfile at [GitHub](https://github.com/jim60105/docker-whisperX), or pull the image from [ghcr.io](https://ghcr.io/jim60105/whisperx).

## Available Image Tags

> [!WARNING]
> These images have such large file sizes that I am unable to set up continuous integration, so they will not update automatically.\
> If their versions become outdated, please build them manually.

The image tags are formatted as `WHISPER_MODEL`-`LANG`, for example, `tiny-en`, `base-de`, or `large-v2-zh`. Please note that whisper models `*.en` and `large-v1` are excluded.

You can find all available tags at [ghcr.io](https://ghcr.io/jim60105/whisperx).

In addition, there is also a `no_model` tag that does not include any pre-downloaded models. It is also referred to as `latest`.

## Building the Docker Image

> [!IMPORTANT]
> Clone the Git repository recursively to include submodules:\
> `git clone --recursive https://github.com/jim60105/docker-whisperX.git`

### Build Arguments

The [Dockerfile](https://github.com/jim60105/docker-whisperX/blob/master/Dockerfile) builds the image contained models. It accepts two build arguments: `LANG` and `WHISPER_MODEL`.

- `LANG`: The language to transcribe. The default is `en`. See [here](https://github.com/jim60105/docker-whisperX/blob/master/load_align_model.py) for supported languages.

- `WHISPER_MODEL`: The model name. The default is `base`. See [fast-whisper](https://huggingface.co/guillaumekln) for supported models.

### Build Command

For example, if you want to build the image with `ja` language and `large-v2` model:

```bash
docker build --build-arg LANG=ja --build-arg WHISPER_MODEL=large-v2 -t whisperx:large-v2-ja .
```

### Usage Command

Mount the current directory as `/app` and run WhisperX with additional input arguments:

```bash
docker run --gpus all -it -v "$(PWD):/app" whisperx:large-v2-ja -- --output_format srt audio.mp3
```

> [!NOTE]
> Remember to prepend `--` before the arguments.\
> `--model` and `--language` args are defined in Dockerfile, no need to specify.

## LICENSE

The main program, WhisperX, is distributed under [the BSD-4 license](https://github.com/m-bain/whisperX/blob/main/LICENSE).\
Please refer to the git submodules for their respective source code licenses.

The Dockerfile from this repository is licensed under [MIT](/LICENSE).
