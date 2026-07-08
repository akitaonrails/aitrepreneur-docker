# Upgrading components

Every version pin lives in one of two places:

- **`.env`** — things you change routinely (`AI_TOOLKIT_REF`, `CUDA_STREAM`).
- **`Dockerfile` ARG block** (top of file) — deeper pins you change rarely
  (torch, Node, CUDA base image).

After changing any pin: `make upgrade` (rebuild + restart). Data in `./data/`
is never affected.

## ai-toolkit itself (most common)

`AI_TOOLKIT_REF=main` in `.env` tracks upstream. `make upgrade` passes a fresh
`CACHEBUST`, forcing a re-clone plus re-resolution of `requirements.txt` and
the UI lockfile at that ref. Plain `make build` reuses cached layers and will
NOT pick up new commits on a branch.

For reproducibility, pin a commit sha instead:

```
AI_TOOLKIT_REF=1a2b3c4d...
```

`make version` prints the commit baked into the current image. If an upgrade
breaks something, set `AI_TOOLKIT_REF` back to the last good sha and
`make upgrade` again.

## PyTorch

`TORCH_VERSION` / `TORCHVISION_VERSION` / `TORCHAUDIO_VERSION` ARGs in the
`Dockerfile`. Keep them in lockstep (each torch release has one matching
torchvision/torchaudio — check the table in the
[PyTorch install docs](https://pytorch.org/get-started/locally/)) and follow
whatever upstream's own `docker/Dockerfile` uses — mismatched torch versions
against `requirements.txt` are the most likely source of dependency conflicts.

`CUDA_STREAM` (in `.env`) selects the wheel index: `cu128` is required for
Blackwell/RTX 50xx; `cu126` works for older GPUs.

## Node.js

`NODE_MAJOR` ARG. The UI needs Node ≥ 22; bump when upstream's docs say so.

## CUDA base image

`CUDA_IMAGE` ARG (`nvidia/cuda:*-devel-ubuntu*`). Only needs to move when a
new GPU generation or torch stream requires a newer CUDA toolkit. The `devel`
variant is intentional: some Python deps compile CUDA extensions during
`pip install`.

## UI database schema

Nothing to do manually. The entrypoint runs `prisma db push` on every start,
which upgrades the SQLite schema in `./data/db/aitk_db.db` in place.

## Checking an upgrade worked

```bash
make gpu-check   # torch sees the GPU
make logs        # UI + worker start cleanly
```

Then open http://localhost:8675 and confirm your existing jobs/datasets are
still listed.
