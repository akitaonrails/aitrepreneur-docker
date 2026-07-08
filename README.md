# ai-toolkit — local Docker (NVIDIA GPU)

Runs [ostris/ai-toolkit](https://github.com/ostris/ai-toolkit) (LoRA training UI,
used for FLUX / Krea and friends) in a local Docker container instead of a
RunPod pod. It installs the same stack as the RunPod one-click script kept in
[`docs/reference/`](docs/reference/), but as a reproducible image: pinned
versions, persistent data on the host, one command to run or upgrade.

## Prerequisites

- NVIDIA driver + [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
  (verify with `make gpu-check` after building). Compose uses the legacy
  `nvidia` runtime rather than `gpus: all` because the latter reads the CDI
  spec (`/etc/cdi/nvidia.yaml`), which breaks after driver updates until you
  regenerate it (`sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml`).
- Docker with Compose v2
- ~30 GB free disk for the image + whatever your models need under `./data/`

Defaults target Blackwell / RTX 50xx GPUs (`cu128` PyTorch wheels). For older
cards set `CUDA_STREAM=cu126` in `.env`.

## Quick start

```bash
make setup     # creates .env — edit it to add your HF_TOKEN
make build     # ~10-20 min first time (torch + deps + UI build)
make up        # UI at http://localhost:8675
```

Day to day: `make up`, `make down`, `make logs`, `make shell`, `make gpu-check`.

## Data layout

Everything stateful lives outside the container. Rebuilding or upgrading never
touches your data.

```
./data/                                  # small, local (gitignored)
├── datasets/    # training datasets (drop image+caption folders here)
├── outputs/     # trained LoRAs, samples, checkpoints
└── db/          # the UI's SQLite job database (aitk_db.db)

/mnt/gigachad/comfyui/models/            # big, on the NAS
├── hf-cache/    # base models ai-toolkit downloads from Hugging Face
├── aitk-cache/  # torch.hub + misc library caches (CLIP, LPIPS, ...)
└── ...          # your existing ComfyUI models, mounted read-only at
                 # /comfyui-models inside the container
```

Every path the apps download to (`HF_HOME`, `TORCH_HOME`, `XDG_CACHE_HOME`,
`~/.cache`) is redirected onto these mounts, so nothing large can accumulate
in the container's writable layer — `docker diff ai-toolkit` should stay
near-empty. Datasets and outputs are local by default (LoRAs are small and
local disk is faster); set `DATASETS_DIR`/`OUTPUTS_DIR` in `.env` to move
them to the NAS.

Downloaded base models (FLUX/Krea checkpoints, text encoders — tens of GB
each) go to the NAS via `HF_CACHE_DIR`. Note they land in Hugging Face's own
cache layout (`models--org--name/...`), not ComfyUI's folder convention.

The read-only `/comfyui-models` mount lets a training config reference a
checkpoint you already have, e.g. a local path like
`/comfyui-models/diffusion_models/whatever.safetensors` instead of a HF repo
id, avoiding a re-download.

Inside the container the data dirs are symlinked to where ai-toolkit expects
them (`/app/ai-toolkit/datasets`, `/app/ai-toolkit/output`, repo-root db) by
`scripts/entrypoint.sh`.

## Configuration

All knobs live in `.env` (see `.env.example` for the full list):

| Variable | Default | Purpose |
|---|---|---|
| `AI_TOOLKIT_REF` | `main` | Git ref of ai-toolkit to build |
| `CUDA_STREAM` | `cu128` | PyTorch CUDA wheels (`cu126` for pre-RTX-50xx) |
| `UI_PORT` | `8675` | Host port for the web UI |
| `HF_CACHE_DIR` | `/mnt/gigachad/comfyui/models/hf-cache` | Where downloaded base models are stored |
| `COMFYUI_MODELS_DIR` | `/mnt/gigachad/comfyui/models` | Existing models, mounted read-only at `/comfyui-models` |
| `HF_TOKEN` | — | Hugging Face token for gated models |
| `AI_TOOLKIT_AUTH` | empty | Optional UI password |

Deeper pins (torch/node/CUDA base image versions) are build args at the top of
the `Dockerfile`. See [`docs/UPGRADING.md`](docs/UPGRADING.md).

## Upgrading

```bash
make upgrade   # re-clones AI_TOOLKIT_REF, rebuilds, restarts
make version   # show the exact ai-toolkit commit in the current image
```

Your datasets, outputs, models, and job database are untouched — the entrypoint
re-applies any DB schema changes (`prisma db push`) on start.

## How this differs from the RunPod script

The reference script ([`docs/reference/AI-TOOLKIT_AUTO_INSTALL-RUNPOD_FAST-V2.sh`](docs/reference/AI-TOOLKIT_AUTO_INSTALL-RUNPOD_FAST-V2.sh))
installs everything at pod boot into `/workspace`. Here the equivalent steps
happen once at image build time instead:

| RunPod script | This repo |
|---|---|
| apt/node/torch installed on every fresh pod | baked into the image |
| GPU detection picks cu126/cu128 at runtime | `CUDA_STREAM` in `.env` (default cu128 for RTX 50xx) |
| torch 2.7.0 (script's era) | torch 2.9.1, matching current upstream `main` |
| `/workspace` persistence + install marker | `./data/` bind mount; image is immutable |
| `git pull` on restart (moving target) | explicit `make upgrade`, commit recorded in image |
