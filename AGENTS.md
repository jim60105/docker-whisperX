# AGENTS.md — docker-whisperX

Authoritative instructions for AI coding agents working in this repository.
Read this file fully before taking any action.

> Repository: <https://github.com/jim60105/docker-whisperX>

---

## 1. Communication & Language

| Context | Language |
| --- | --- |
| Replies to the user in chat | **Traditional Chinese (`zh-TW` 正體中文)** |
| Source code, code comments, identifiers | **English** |
| Commit messages, branch names, PR titles | **English** (Conventional Commits) |
| PR descriptions / work reports | **Traditional Chinese** (code blocks stay English) |
| GitHub Issue descriptions | **Traditional Chinese** (code blocks stay English) |

Be precise, consult both this file and the conversation history before acting, and prefer asking over assuming when requirements are ambiguous.

---

## 2. Environment Constraints

- **No `docker` CLI is available.** Use `podman` for any container operations you run locally.
- Builds in CI use **Docker Buildx + `docker buildx bake`** — when reasoning about CI you are reasoning about Buildx semantics, not plain `docker build`.
- The repository is a **Git submodule host**: `whisperX/` is an upstream submodule. Always clone recursively (`git clone --recursive`) and remember that changes inside `whisperX/` belong upstream, not here.
- Target runtime is **GitHub Free runners** (`ubuntu-latest` for amd64, `ubuntu-24.04-arm` for arm64). Build cost and runner disk space (~10 GB free) are first-class concerns.

---

## 3. Project Overview

This repository packages [WhisperX](https://github.com/m-bain/whisperX) (Automatic Speech Recognition with word-level timestamps and speaker diarization) into reproducible, GPU-capable Docker images published to `ghcr.io/jim60105/whisperx`.

The engineering focus is **not** WhisperX itself but the **build pipeline**:

- Around **370+ image variants** (`WHISPER_MODEL` × `LANG`) are produced **weekly** on free runners.
- Each final image is roughly **10 GB**.
- Success depends on disciplined **layer caching, stage reuse, parallel matrix builds, and multi-architecture support** (`linux/amd64` + `linux/arm64`).

Touch the Dockerfile, `docker-bake.hcl`, or workflows with this constraint in mind: any change that breaks cache reuse or balloons image size is a regression.

---

## 4. Repository Layout

```
docker-whisperX/
├── Dockerfile              # Multi-stage build (see §5)
├── docker-bake.hcl         # Buildx bake matrix (models × languages)
├── load_align_model.py     # Preloads wav2vec2 alignment models per LANG
├── whisperX/               # Git submodule — upstream WhisperX source
├── .hadolint.yml           # Hadolint ignore list for the Dockerfile
├── .github/
│   ├── copilot-instructions.md  # Mirror of this guidance for Copilot
│   └── workflows/          # CI pipelines (build base → cache → matrix → publish)
└── README.md
```

---

## 5. Dockerfile Architecture

The Dockerfile is a deliberately ordered multi-stage graph. Preserve the stage names and their roles — CI references them by name.

| Stage | Purpose |
| --- | --- |
| `prepare_base_amd64` / `prepare_base_arm64` | Install arch-specific runtime libs (e.g. `libnppicc12` on amd64, `libgomp1` + `libsndfile1` on arm64). |
| `base` | Selected dynamically via `prepare_base_${TARGETARCH}${TARGETVARIANT}`. |
| `build` | Installs `uv`, fetches `dumb-init`, runs `uv sync` against the `whisperX/` submodule into `/venv`. |
| `no_model` | Runtime image: non-root user (`UID=1001`), ffmpeg, copies `/venv` from `build`, sets `PATH`/`PYTHONPATH`/`LD_LIBRARY_PATH`, smoke-tests `whisperx -h`. Tagged in CI as `latest` / `no_model`. |
| `load_whisper` | Preloads Silero VAD + a specific `faster_whisper` model (`WHISPER_MODEL`). Cached per model in CI. |
| `load_align` | Runs `load_align_model.py` for each entry in `LANG`. |
| `final` | Combines `no_model` runtime with the populated `/.cache` from `load_align`; sets entrypoint to launch `whisperx` with the resolved model + first language. |

Key conventions:

- **Cache mounts** use stable IDs scoped by arch: `--mount=type=cache,id=apt-$TARGETARCH$TARGETVARIANT,sharing=locked,...`. Match this pattern when adding new package installs.
- `LOAD_WHISPER_STAGE` and `NO_MODEL_STAGE` ARGs let CI swap entire stages with pre-built remote images for caching. Locally they default to in-tree stage names — leave the defaults alone.
- The `CACHE_HOME=/.cache` path is **load-bearing**: the diarization model does not honour `TORCH_HOME`, see issue #27. Do not relocate it.
- Run as `USER $UID` (1001) with `chown $UID:0 chmod 775` on writable dirs — this is required for OpenShift compatibility. Preserve it on any new `COPY`/`RUN install -d`.
- **Never use `,z` or `,Z` mount flags** — Buildx does not support them, even though `podman` does.
- Hadolint runs against the Dockerfile. The ignored rule list lives in `.hadolint.yml`; do not silence additional rules without justification.

---

## 6. `docker-bake.hcl` & Build Matrix

- `target "build"` is a matrix over `WHISPER_MODEL` (`tiny`, `base`, `small`, `medium`, `large-v3`, `distil-large-v3`) × `LANG` (~40 languages — see the file for the canonical list).
- `target "no_model"` produces the model-less runtime image tagged `latest` and `no_model`.
- All targets build for both `linux/amd64` and `linux/arm64` and use a local cache directory (`type=local,mode=max,src=cache`).
- When adding a language: update both `docker-bake.hcl` **and** ensure a model entry exists in `load_align_model.py` (either `DEFAULT_ALIGN_MODELS_TORCH` or `DEFAULT_ALIGN_MODELS_HF`). The script raises `ValueError("Unsupported language")` otherwise and CI will fail.

---

## 7. CI/CD Workflow (`.github/workflows/`)

Pipeline order (each triggers the next via `workflow_run`):

1. `01-build-base-images.yml` — builds the shared `no_model` base.
2. `02-build-model-cache.yml` — builds per-model `load_whisper` cache images.
3. `03-build-distil-en.yml` — special-case distil model (English only).
4. `04-build-matrix-images.yml` — the main matrix; splits into `build_matrix_1` (tiny, base) and `build_matrix_2` (small, medium, large-v3) to stay within runner limits, then merges per-platform digests and publishes manifest lists.
5. `docker_publish.yml`, `scan.yml`, `submodule_update.yml`, `auto_merge.yml` — publishing, security scans, weekly submodule bump, Dependabot auto-merge.

Guidelines when editing workflows:

- Preserve the **digest-then-manifest** strategy (`push-by-digest=true` → `docker buildx imagetools create`). Don't collapse it into a single multi-platform push: it breaks parallelism across runners.
- Use `actions/attest-build-provenance` for SLSA attestations; keep `sbom: true` and `provenance: true` on `docker/build-push-action`.
- Free disk space with `jlumbroso/free-disk-space@main` and the `man-db`/`dpkg` exclude trick before heavy build/test steps — runners run out of space otherwise.
- Excluded languages on the GitHub matrix: `no`, `nn` (transcribe models too large for free runners). Reference [run 8405597972](https://github.com/jim60105/docker-whisperX/actions/runs/8405597972) before re-adding them.
- Test fixtures live in `.github/workflows/test/` (`en.webm`, `zh.webm`). The `test-medium-zh` job greps for `充满`/`充滿` to validate Chinese transcription; keep that assertion intact when modifying tests.

---

## 8. Coding Standards

### Docker

- Multi-stage builds, minimal final image, BuildKit cache mounts, ARG-driven configuration.
- Run as a non-root UID; minimise installed packages; copy licences into `/licenses` (OpenShift policy).
- Do not pin via `apt-get install <pkg>=<version>` unless necessary — Hadolint DL3008 is intentionally ignored.

### Python (`load_align_model.py`)

- Standalone script; takes language code as `sys.argv[1]`; prints nothing on success.
- When adding a language, prefer existing model families (torchaudio bundles or `jonatasgrosman/wav2vec2-large-xlsr-53-*`) for consistency.

### Workflows

- Pin third-party actions to a major version (`@v4`, `@v6`, etc.). `jlumbroso/free-disk-space` intentionally tracks `@main`.
- Keep step names descriptive — they show up in build logs that contributors search.

### Documentation

- English for everything user-facing in `README.md`, code comments, and ARG documentation.
- When you add a new ARG, document its accepted values in both the Dockerfile (comment) and README's "Build Arguments" section.

---

## 9. Decision Checklist Before Submitting Changes

Run through this before declaring a task complete:

- [ ] Does the change keep both `linux/amd64` and `linux/arm64` building?
- [ ] Are BuildKit cache mounts still keyed by `$TARGETARCH$TARGETVARIANT`?
- [ ] Did stage names referenced by CI (`build`, `no_model`, `load_whisper`, `load_align`, `final`) stay intact?
- [ ] If a new `LANG` was added: is it in `docker-bake.hcl` **and** `load_align_model.py`?
- [ ] Were `,z` / `,Z` mount flags avoided?
- [ ] Are runtime dirs still owned `$UID:0` with mode `775`?
- [ ] Does Hadolint still pass (no new ignored rules without reason)?
- [ ] Are commit/PR conventions (language, sign-off, author, target remote) honoured?
- [ ] Does the README still accurately describe new ARGs / tags?

Adherence to this document is mandatory; it encodes the project's architectural and stylistic norms.
