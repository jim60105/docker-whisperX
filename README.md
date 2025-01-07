# docker-whisperX

[![CodeFactor](https://www.codefactor.io/repository/github/jim60105/docker-whisperx/badge)](https://www.codefactor.io/repository/github/jim60105/docker-whisperx) ![Docker Build](https://img.shields.io/github/actions/workflow/status/jim60105/docker-whisperX/docker_publish.yml?label=Docker%20Build) [![Image Scan](https://img.shields.io/github/actions/workflow/status/jim60105/docker-whisperX/scan.yml?label=Image%20Scan)](https://github.com/jim60105/docker-whisperX/actions/workflows/scan.yml) [![Image Scan UBI](https://img.shields.io/github/actions/workflow/status/jim60105/docker-whisperX/scan_ubi.yml?label=Image%20Scan%20UBI)](https://github.com/jim60105/docker-whisperX/actions/workflows/scan_ubi.yml)

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

## 📦 Available Pre-built Image

![GitHub Workflow Status (with event)](https://img.shields.io/github/actions/workflow/status/jim60105/docker-whisperX/docker_publish.yml?label=Docker%20Build) ![GitHub last commit (branch)](https://img.shields.io/github/last-commit/jim60105/docker-whisperX/master?label=Date)

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

You can find the actual build matrix in [docker_publish.yml](.github/workflows/docker_publish.yml#L212) and all available tags at [ghcr.io](https://github.com/jim60105/docker-whisperX/pkgs/container/whisperx/versions?filters%5Bversion_type%5D=tagged).

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

- `LANG`: The language to transcribe. The default is `en`. See [here](https://github.com/jim60105/docker-whisperX/blob/master/load_align_model.py) for supported languages.
- `WHISPER_MODEL`: The model name. The default is `base`. See [fast-whisper](https://huggingface.co/Systran) for supported models.

In case of multiple language alignments needed, use space separated list of languages `"LANG=pl fr en"` when building the image. Also note that WhisperX is not doing well to handle multiple languages within the same audio file. Even if you do not provide the language parameter, it will still recognize the language (or fallback to en) and use it for choosing the alignment model. Alignment models are language specific. **This instruction is simply for embedding multiple alignment models into a docker image.**

### Build Command

> [!NOTE]  
> If you are using an earlier version of the docker client, it is necessary to [enable the BuildKit mode](https://docs.docker.com/build/buildkit/#getting-started) when building the image. This is because I used the `COPY --link` feature which enhances the build performance and was introduced in Buildx v0.8.  
> With the Docker Engine 23.0 and Docker Desktop 4.19, Buildx has become the default build client. So you won't have to worry about this when using the latest version.

For example, if you want to build the image with `en` language and `large-v3` model:

```bash
docker build --build-arg LANG=en --build-arg WHISPER_MODEL=large-v3 -t whisperx:large-v3-en .
```

If you want to build the image without any pre-downloaded models:

```bash
docker build --target no_model -t whisperx:no_model .
```

If you want to build all images at once, we have [a Docker bake file](docker-bake.hcl) available:

> [!WARNING]  
> [Bake](https://docs.docker.com/build/bake/) is currently an experimental feature, and it may require additional configuration in order to function correctly.

```bash
docker buildx bake build no_model ubi-no_model
```

### Usage Command

Mount the current directory as `/app` and run WhisperX with additional input arguments:

```bash
docker run --gpus all -it -v ".:/app" whisperx:large-v3-ja -- --output_format srt audio.mp3
```

> [!NOTE]  
> Remember to prepend `--` before the arguments.  
> `--model` and `--language` args are defined in Dockerfile, no need to specify.

## ⛑️ Red Hat UBI based Image

[![Image Scan UBI](https://img.shields.io/github/actions/workflow/status/jim60105/docker-whisperX/scan_ubi.yml?label=Image%20Scan%20UBI)](https://github.com/jim60105/docker-whisperX/actions/workflows/scan_ubi.yml)

I have created an alternative [ubi.Dockerfile](ubi.Dockerfile) that is based on the **Red Hat Universal Base Image (UBI)** image, unlike the default one which used the **Python official image** as the base image. If you are a Red Hat subscriber, I believe you will find its benefits.

> [!TIP]
> With the release of the Red Hat Universal Base Image (UBI), you can now take advantage of the greater reliability, security, and performance of official Red Hat container images where OCI-compliant Linux containers run - whether you're a customer or not. -- [Red Hat blog](https://www.redhat.com/en/blog/introducing-red-hat-universal-base-image)

It is important to mention that it is *NOT* necessary obtaining a license from Red Hat to use UBI, however, if you are the subscriber and runs it on RHEL/OpenShift, you may get supports from Red Hat.

Despite my initial hesitation, I made the decision not to utilize the *UBI* version as the default image. The *Python official image* has a significantly larger user base compared to *UBI*, and I believe that opting for it aligns better with public expectations. Nevertheless, I would still suggest giving the *UBI* version a try.

Please refer to [the latest vulnerability scan report](https://github.com/jim60105/docker-whisperX/actions/workflows/scan.yml?query=is%3Asuccess) from our scanning workflow artifact. You can see that the *UBI* version has fewer vulnerabilities compared to the *Python official image* version.

You can get the pre-built image at tag `ubi-no_model`. Notice that only `no_model` is available. Feel free to build your own image with the [ubi.Dockerfile](ubi.Dockerfile) for your needs. This Dockerfile supports the same build arguments as the default one.

```bash
docker run --gpus all -it -v ".:/app" ghcr.io/jim60105/whisperx:ubi-no_model -- --model tiny --language en --output_format srt audio.mp3
```

> [!WARNING]
> ***DISCLAIMER***:  
> I have created the image in accordance with the specifications outlined in the [Red Hat Container Certification Requirement](https://access.redhat.com/documentation/en-us/red_hat_software_certification/8.72/html/red_hat_openshift_software_certification_policy_guide/assembly-requirements-for-container-images_openshift-sw-cert-policy-introduction) but I am not going to pursue the actual [certification](https://connect.redhat.com/en/partner-with-us/red-hat-container-certification).

## 📝 LICENSE

> The main program, WhisperX, is distributed under [the BSD-4 license](https://github.com/m-bain/whisperX/blob/main/LICENSE).  
> Please consult their repository for access to the source code and license.

The Dockerfile and CI workflow files in this repository are licensed under [the MIT license](LICENSE).
