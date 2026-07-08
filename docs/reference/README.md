# Reference material (not distributed)

This project was derived from Aitrepreneur's RunPod one-click install files,
which come from his **paid Patreon page** and are therefore **not included in
this repository** (everything in this directory except this README is
gitignored). If you have access, drop the originals here — they are useful
reference, but nothing in the build depends on them, with one exception noted
below.

Expected files and the compose service each one maps to:

- `AI-TOOLKIT_AUTO_INSTALL-RUNPOD_FAST-V2.sh` → `ai-toolkit` service.
  ostris/ai-toolkit (LoRA training UI), torch cu126/cu128 auto-detected.

- `KREA2_ULTRA-AUTO_INSTALL-RUNPOD-V2.sh` → `krea2` service. ComfyUI +
  Krea 2: torch 2.8.0+cu128, pinned transformers stack, 4 model files,
  6 custom nodes, ComfyUI-Manager pin protection.

- `IDEOGRAM_ULTRA-AUTO_INSTALL-RUNPOD.sh` → `ideogram` service. ComfyUI +
  Ideogram 4: 5 model files, 4 custom nodes. (Script's torch 2.4.0+cu121 has
  no RTX 50xx support; our container uses cu128.)

- `IDEOGRAM_ULTRA_WORKFLOW-V2.json` — the Ideogram Ultra workflow. **The one
  build dependency:** place a copy at
  `comfyui/apps/ideogram/workflows/IDEOGRAM_ULTRA_WORKFLOW-V2.json`
  (also gitignored) and it is seeded into the ideogram UI on first start.
  Without it the container still runs — you just load workflows manually.

- `IDEOGRAM-TEMPLATES.zip` — 52 template reference PNGs for that workflow.
  Extract to the directory pointed at by `IDEOGRAM_TEMPLATES_DIR` in `.env`;
  it is mounted read-only into the ideogram container at `input/templates`.

- `LTX-2-3-AUTO_INSTALL-RUNPOD-V2.sh` → `ltx` service. ComfyUI v0.21.1 +
  LTX-2.3 video: 8 model files (22B Q8_0 gguf ~23 GB), 14 custom nodes,
  requirements sanitizer protecting the torch stack. (Same cu121→cu128
  deviation as ideogram; xformers dropped.)

- `README-PROMPT.txt` — a system prompt for an LLM image-captioning assistant
  that prepares LoRA training datasets. Use it with a vision-capable chat
  model to caption a dataset before dropping it into
  `data/ai-toolkit/datasets/`.
