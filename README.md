# docker-whisperX

[![CodeFactor](https://www.codefactor.io/repository/github/jim60105/docker-whisperx/badge)](https://www.codefactor.io/repository/github/jim60105/docker-whisperx) ![Docker Build](https://img.shields.io/github/actions/workflow/status/jim60105/docker-whisperX/04-build-matrix-images.yml?label=Docker%20Build)

This is the docker image for [WhisperX: Automatic Speech Recognition with Word-Level Timestamps (and Speaker Diarization)](https://github.com/m-bain/whisperX) from the community.

The objective of this project is to efficiently manage the continuous integration docker build workflow on the ***GitHub Free runner*** on a ***weekly basis***. Which includes building ***175*** Docker images ***in parallel***, each with a size of ***10GB.*** To ensure smooth operation, I have concentrated on utilizing docker layer caches efficiently, maximizing layer reuse, carefully managing cache read/write order to prevent any issues, and optimizing to minimize image size and build time.

Additionally, for my personal preference, I am dedicated to following best practices, industry standards and policies to the best of my ability.

Get the Dockerfile at [GitHub](https://github.com/jim60105/docker-whisperX), or pull the image from [ghcr.io](https://ghcr.io/jim60105/whisperx).

## 🚀 Get your Docker ready for GPU support

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

> [!TIP]  
> I have a Chinese blog about this topic:  
> [Podman GPU Configuration Notes for Fedora/RHEL](https://xn--jgy.tw/Container/configuring-gpu-in-linux-podman/)

## 📦 Available Pre-built Image

![GitHub Workflow Status (with event)](https://img.shields.io/github/actions/workflow/status/jim60105/docker-whisperX/04-build-matrix-images.yml?label=Docker%20Build) ![GitHub last commit (branch)](https://img.shields.io/github/last-commit/jim60105/docker-whisperX/master?label=Date)

> [!NOTE]  
> The WhisperX code base in these images aligns with the git submodule commit hash.  
> I have [a scheduled CI workflow](https://github.com/jim60105/docker-whisperX/actions/workflows/submodule_update.yml) runs weekly to target on [the main branch](https://github.com/m-bain/whisperX/tree/main) and rebuild all docker images.

```bash
docker run --gpus all -it -v ".:/app" ghcr.io/jim60105/whisperx:base-en     -- --output_format srt audio.mp3
docker run --gpus all -it -v ".:/app" ghcr.io/jim60105/whisperx:large-v3-ja -- --output_format srt audio.mp3
docker run --gpus all -it -v ".:/app" ghcr.io/jim60105/whisperx:no_model    -- --model tiny --language en --output_format srt audio.mp3
```

The image tags are formatted as `WHISPER_MODEL`-`LANG`, for example, `tiny-en`, `base-de` or `large-v3-zh`.  
Please be aware that the whisper models `*.en`,  `large-v1`, `large-v2` have been excluded as I believe they are not frequently used. If you require these models, please refer to the following section to build them on your own.

You can find the actual build matrix in [04-build-matrix-images.yml](.github/workflows/04-build-matrix-images.yml) and all available tags at [ghcr.io](https://github.com/jim60105/docker-whisperX/pkgs/container/whisperx/versions?filters%5Bversion_type%5D=tagged).

In addition, there is also a `no_model` tag that does not include any pre-downloaded models, also referred to as `latest`.

> Added a `distil-large-v3-en` model.  
> Only en, distil model seems to only support English.

## ⚡️ Preserve the download cache for the align models when working with various languages

You can mount the `/.cache` to share align models between containers.  
Please use tag `no_model` (`latest`) for this scenario.

```bash
docker run --gpus all -it -v ".:/app" -v whisper_cache:/.cache ghcr.io/jim60105/whisperx:latest -- --model large-v3 --language en --output_format srt audio.mp3
```

## 🛠️ Building the Docker Image

> [!IMPORTANT]  
> Clone the Git repository recursively to include submodules:  
> `git clone --recursive https://github.com/jim60105/docker-whisperX.git`

### Build Arguments

The [Dockerfile](Dockerfile) builds the image contained models. It accepts two build arguments: `LANG` and `WHISPER_MODEL`.

- `LANG`: The language to transcribe. The default is `en`. See [supported languages in load_align_model.py](https://github.com/jim60105/docker-whisperX/blob/master/load_align_model.py).
- `WHISPER_MODEL`: The model name. The default is `base`. See [fast-whisper](https://huggingface.co/Systran) for supported models.

In case of multiple language alignments needed, use space separated list of languages `"LANG=pl fr en"` when building the image. Also note that WhisperX is not doing well to handle multiple languages within the same audio file. Even if you do not provide the language parameter, it will still recognize the language (or fallback to en) and use it for choosing the alignment model. Alignment models are language specific. **This instruction is simply for embedding multiple alignment models into a docker image.**

### Build Command

For example, if you want to build the image with `en` language and `large-v3` model:

```bash
docker build --build-arg LANG=en --build-arg WHISPER_MODEL=large-v3 -t whisperx:large-v3-en .
```

If you want to build the image without any pre-downloaded models:

```bash
docker build --target no_model -t whisperx:no_model .
```

If you want to build all images at once, we have [a Docker bake file](docker-bake.hcl) available:

```bash
docker buildx bake build no_model
```

### Usage Command

Mount the current directory as `/app` and run WhisperX with additional input arguments:

```bash
docker run --gpus all -it -v ".:/app" whisperx:large-v3-ja -- --output_format srt audio.mp3
```

> [!NOTE]  
> Remember to prepend `--` before the arguments.  
> `--model` and `--language` args are defined in Dockerfile, no need to specify.

## 📝 LICENSE

> The main program, WhisperX, is distributed under [the BSD-4 license](https://github.com/m-bain/whisperX/blob/main/LICENSE).  
> Please consult their repository for access to the source code and license.

The Dockerfile and CI workflow files in this repository are licensed under [the MIT license](LICENSE).

## 🌟 Star History

<a href="https://www.star-history.com/#jim60105/docker-whisperX&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=jim60105/docker-whisperX&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=jim60105/docker-whisperX&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=jim60105/docker-whisperX&type=Date" />
 </picture>
</a>
