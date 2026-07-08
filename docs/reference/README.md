# Reference material

Original Aitrepreneur RunPod files this project was derived from — kept
verbatim for reference, not used by the build. Each installer script maps to
a compose service (see the root README for the deviations we made).

- **`AI-TOOLKIT_AUTO_INSTALL-RUNPOD_FAST-V2.sh`** → `ai-toolkit` service.
  Installs ostris/ai-toolkit (LoRA training UI) with torch cu126/cu128
  auto-detected per GPU.

- **`KREA2_ULTRA-AUTO_INSTALL-RUNPOD-V2.sh`** → `krea2` service. ComfyUI +
  Krea 2: torch 2.8.0+cu128, pinned transformers stack, 4 model files,
  6 custom nodes, ComfyUI-Manager pin protection.

- **`IDEOGRAM_ULTRA-AUTO_INSTALL-RUNPOD.sh`** → `ideogram` service. ComfyUI +
  Ideogram 4: 5 model files, 4 custom nodes. (Script's torch 2.4.0+cu121 has
  no RTX 50xx support; our container uses cu128.)

- **`IDEOGRAM_ULTRA_WORKFLOW-V2.json`** — the Ideogram Ultra workflow;
  operational copy lives in `comfyui/apps/ideogram/workflows/` and is seeded
  into the UI automatically.

- **`IDEOGRAM-TEMPLATES.zip`** — 52 template reference PNGs for that workflow
  (~150 MB, gitignored). Extracted to
  `/mnt/gigachad/comfyui/ideogram-templates/`, mounted read-only into the
  ideogram container at `input/templates`.

- **`LTX-2-3-AUTO_INSTALL-RUNPOD-V2.sh`** → `ltx` service. ComfyUI v0.21.1 +
  LTX-2.3 video: 8 model files (22B Q8_0 gguf ~23 GB), 14 custom nodes,
  requirements sanitizer protecting the torch stack. (Same cu121→cu128
  deviation as ideogram; xformers dropped.)

- **`README-PROMPT.txt`** — a system prompt for an LLM image-captioning
  assistant that prepares LoRA training datasets (one natural-language `.txt`
  caption per image, zipped alongside the originals). Use it with a
  vision-capable chat model to caption a dataset before dropping it into
  `data/ai-toolkit/datasets/`.
