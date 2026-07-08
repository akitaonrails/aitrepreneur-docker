# Reference material

Original files this project was derived from — kept verbatim for reference,
not used by the build.

- **`AI-TOOLKIT_AUTO_INSTALL-RUNPOD_FAST-V2.sh`** — the RunPod one-click
  install/restart script (Aitrepreneur) that this Docker setup replicates.
  It installs apt packages, Node 22, a Python venv with torch cu126/cu128
  (auto-detected per GPU), the ai-toolkit requirements, then builds and starts
  the UI. Our `Dockerfile` performs the same steps at image build time; the
  README's comparison table maps each part.

- **`README-PROMPT.txt`** — a system prompt for an LLM image-captioning
  assistant that prepares LoRA training datasets (one natural-language `.txt`
  caption per image, zipped alongside the originals). Use it with a
  vision-capable chat model to caption a dataset before dropping it into
  `data/datasets/`.
