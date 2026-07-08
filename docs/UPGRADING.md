# Upgrading components

Every version pin lives in one of three places:

- **`.env`** — things you change routinely: `AI_TOOLKIT_REF`, per-app
  `COMFY_REF_*`.
- **`comfyui/apps/<app>/`** — what makes each ComfyUI app itself: custom
  nodes (`nodes.txt`), pip pins (`constraints.txt`, `extras.txt`), model
  files (`models.txt`).
- **Dockerfile ARG blocks** (`ai-toolkit/Dockerfile`, `comfyui/Dockerfile`) —
  deeper pins you change rarely: torch, Node.js, CUDA base image.

After changing any pin: `make upgrade-<app>` (or `make upgrade` for all).
Data and downloaded models are never affected.

## Upstream code (most common)

`AI_TOOLKIT_REF` / `COMFY_REF_*` in `.env` select the git ref. Refs like
`main`/`master` track upstream — but plain `make build` reuses cached layers
and will NOT pick up new commits; `make upgrade-<app>` passes a fresh
`CACHEBUST` forcing a re-clone. For reproducibility, pin a commit sha or tag.
`make version` prints what each image currently contains; if an upgrade
breaks, set the ref back to the last good sha and upgrade again.

ComfyUI refs per app:

- `krea2` and `ideogram` need a recent ComfyUI (native Krea 2 / Ideogram 4
  model support — the krea2 build fails fast if the ref is too old).
- `ltx` is pinned to `v0.21.1`, the version its workflow and the pinned
  ComfyUI-LTXVideo commit were built against. Bump both together, carefully.

## Custom nodes (ComfyUI apps)

Append/edit lines in `comfyui/apps/<app>/nodes.txt` (`folder url [git-ref]`),
then `make upgrade-<app>`. Unpinned nodes get their latest commit on every
upgrade; pin a sha for nodes that break often. Node requirements are
sanitized at build (`comfyui/sanitize-reqs.py`): they can never replace
torch, transformers, numpy, opencv, etc. — those versions are governed solely
by `constraints.txt`.

## Model files (ComfyUI apps)

Append to `comfyui/apps/<app>/models.txt` and restart the app — downloads
happen at container start, straight to the NAS, skipping files that exist.
No rebuild needed. To force a re-download, delete the file from the NAS tree.

## PyTorch

- ai-toolkit: `TORCH_*` ARGs in `ai-toolkit/Dockerfile`; follow whatever
  upstream's own `docker/Dockerfile` uses.
- ComfyUI apps: `TORCH_*` ARGs in `comfyui/Dockerfile` (currently 2.8.0).

All must stay on a `cu128`-capable stream (torch ≥ 2.7) — older cu121/cu126
wheels have no RTX 50xx (sm_120) kernels; this is why we diverge from the
ideogram/ltx reference scripts' torch 2.4.0+cu121. Keep
torch/torchvision/torchaudio in lockstep per the table in the
[PyTorch install docs](https://pytorch.org/get-started/locally/).

## Node.js (ai-toolkit UI)

`NODE_MAJOR` ARG in `ai-toolkit/Dockerfile`. The UI needs Node ≥ 22.

## CUDA base image

`CUDA_IMAGE` ARG in both Dockerfiles (`nvidia/cuda:*-devel-ubuntu*`). Only
needs to move when a new GPU generation or torch stream requires a newer CUDA
toolkit. `devel` is intentional: some deps compile CUDA extensions at
install time.

## Checking an upgrade worked

```bash
make gpu-check       # torch sees the GPU
make logs-<app>      # app starts cleanly, models all [OK]
make version         # confirm the new commit is in the image
```
