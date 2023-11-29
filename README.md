# docker-whisperX

This is the docker image for [WhisperX: Automatic Speech Recognition with Word-Level Timestamps (and Speaker Diarization)](https://github.com/m-bain/whisperX) from the community.

Get the Dockerfile at [GitHub](https://github.com/jim60105/docker-whisperX), or pull the image from [ghcr.io](https://ghcr.io/jim60105/whisperx).

## Get your Docker ready for GPU support

### Windows

Once you have installed **Docker Desktop**, **CUDA Toolkit**, **NVIDIA Windows Driver**, and ensured that your Docker is running with **WSL2**, you are ready to go.

Here is the official documentation for further reference.  
<https://docs.nvidia.com/cuda/wsl-user-guide/index.html#nvidia-compute-software-support-on-wsl-2>
<https://docs.docker.com/desktop/wsl/use-wsl/#gpu-support>

### Linux, OSX

Install an NVIDIA GPU Driver if you do not already have one installed.  
<https://docs.nvidia.com/datacenter/tesla/tesla-installation-notes/index.html>

Install the NVIDIA Container Toolkit with this guide.  
<https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html>

## Available Pre-build Image

![GitHub last commit (branch)](https://img.shields.io/github/last-commit/jim60105/docker-whisperX/master?label=%20&style=for-the-badge) ![GitHub Workflow Status (with event)](https://img.shields.io/github/actions/workflow/status/jim60105/docker-whisperX/docker_publish.yml?label=%20&style=for-the-badge)

> [!NOTE]
> The WhisperX code version in these images corresponds to the git submodule commit hash.\
> The auto update CI runs weekly to update the submodule and rebuild the images.

```bash
docker run --gpus all -it -v ".:/app" ghcr.io/jim60105/whisperx:base-en     -- --output_format srt audio.mp3
docker run --gpus all -it -v ".:/app" ghcr.io/jim60105/whisperx:large-v3-ja -- --output_format srt audio.mp3
docker run --gpus all -it -v ".:/app" ghcr.io/jim60105/whisperx:no_model    -- --model tiny --language en --output_format srt audio.mp3
```

The image tags are formatted as `WHISPER_MODEL`-`LANG`, for example, `tiny-en`, `base-de`, or `large-v3-zh`.\
Please be aware that the whisper models `*.en` and `large-v1` have been excluded as I believe they are not frequently used. If you require these models, please refer to the following section to build them on your own.

You can find all available tags at [ghcr.io](https://ghcr.io/jim60105/whisperx).

In addition, there is also a `no_model` tag that does not include any pre-downloaded models, also referred to as `latest`.

## Preserve the download cache for the align models when working with various languages

You can mount the `/cache` to share align models between containers.  
Please use tag `no_model` (`latest`) for this scenario.

```bash
docker run --gpus all -it -v ".:/app" -v whisper_cache:/cache ghcr.io/jim60105/whisperx:latest -- --model large-v3 --language en --output_format srt audio.mp3
```

## Building the Docker Image

> [!IMPORTANT]
> Clone the Git repository recursively to include submodules:\
> `git clone --recursive https://github.com/jim60105/docker-whisperX.git`

### Build Arguments

The [Dockerfile](https://github.com/jim60105/docker-whisperX/blob/master/Dockerfile) builds the image contained models. It accepts two build arguments: `LANG` and `WHISPER_MODEL`.

- `LANG`: The language to transcribe. The default is `en`. See [here](https://github.com/jim60105/docker-whisperX/blob/master/load_align_model.py) for supported languages.

- `WHISPER_MODEL`: The model name. The default is `base`. See [fast-whisper](https://huggingface.co/guillaumekln) for supported models.

### Build Command

For example, if you want to build the image with `ja` language and `large-v3` model:

```bash
docker build --build-arg LANG=ja --build-arg WHISPER_MODEL=large-v3 -t whisperx:large-v3-ja .
```

If you want to build all images at once, we have [a Docker bake file](https://github.com/jim60105/docker-whisperX/blob/master/docker-bake.hcl) available:

```bash
docker buildx bake no_model build
```

> [!WARNING]
> [Bake](https://docs.docker.com/build/bake/) is currently an experimental feature, and it may require additional configuration in order to function correctly.

### Usage Command

Mount the current directory as `/app` and run WhisperX with additional input arguments:

```bash
docker run --gpus all -it -v ".:/app" whisperx:large-v3-ja -- --output_format srt audio.mp3
```

> [!NOTE]
> Remember to prepend `--` before the arguments.\
> `--model` and `--language` args are defined in Dockerfile, no need to specify.

## UBI9 Image

I have created an alternative [Dockerfile.ubi](Dockerfile.ubi) that is based on the **Red Hat UBI** image, unlike the default one which used the **Python official image** as the base image. If you are a Red Hat customer, I believe you will find its benefits.

> With the release of the Red Hat Universal Base Image (UBI), you can now take advantage of the greater reliability, security, and performance of official Red Hat container images where OCI-compliant Linux containers run - whether you're a customer or not. --[Red Hat](https://www.redhat.com/en/blog/introducing-red-hat-universal-base-image)

It is important to mention that it is *NOT* necessary obtaining a license from Red Hat to use UBI, however, if you are the subscriber and runs it on RHEL/OpenShift, you can get supports from Red Hat.

Despite my initial hesitation, I made the decision not to utilize the UBI version as the default image. The *Python official image* has a significantly larger user base compared to *UBI*, and I believe that opting for it aligns better with public expectations. Nevertheless, I would still suggest giving the *UBI* version a try.

You can get the pre-build image at tag [ubi-no_model](https://ghcr.io/jim60105/whisperx:ubi-no_model). Notice that only no_model is available. Feel free to build your own image with the [Dockerfile.ubi](Dockerfile.ubi) for your needs. This Dockerfile supports the same build arguments as the default one.

```bash
docker run --gpus all -it -v ".:/app" ghcr.io/jim60105/whisperx:ubi-no_model -- --model tiny --language en --output_format srt audio.mp3
```

## LICENSE

The main program, WhisperX, is distributed under [the BSD-4 license](https://github.com/m-bain/whisperX/blob/main/LICENSE).\
Please consult their repository for access to the source code and licenses.

The Dockerfile and CI workflow files in this repository are licensed under [the MIT license](/LICENSE).
