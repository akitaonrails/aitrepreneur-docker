#!/usr/bin/env bash
# Same check as the reference installer: this ComfyUI must ship native
# Krea 2 support.
set -euo pipefail
if [[ ! -f /comfyui/comfy/text_encoders/krea2.py ]]; then
  echo "ERROR: this ComfyUI ref has no native Krea 2 support (comfy/text_encoders/krea2.py missing). Use a newer COMFY_REF." >&2
  exit 1
fi
echo "Native Krea 2 support: OK"
