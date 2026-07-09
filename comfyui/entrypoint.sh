#!/usr/bin/env bash
# Wires ComfyUI's state dirs onto volumes, downloads the app's model files
# into the (NAS-mounted) models tree, and protects the pinned Python stack
# from ComfyUI-Manager before starting the UI.
set -euo pipefail

COMFY_ROOT=/comfyui
APP_DIR=/opt/app/appdir
DATA_DIR=/data

mkdir -p "$DATA_DIR/output" "$DATA_DIR/input" "$DATA_DIR/user" "$DATA_DIR/temp" \
         "$DATA_DIR/cache/torch" "$DATA_DIR/cache/xdg" "$DATA_DIR/cache/huggingface"

# --- keep every write out of the container layer -----------------------------
link_dir() {
  local app_path="$1" data_path="$2"
  if [[ -d "$app_path" && ! -L "$app_path" ]]; then
    cp -an "$app_path/." "$data_path/" 2>/dev/null || true
    rm -rf "$app_path"
  fi
  ln -sfn "$data_path" "$app_path"
}
link_dir "$COMFY_ROOT/output" "$DATA_DIR/output"
link_dir "$COMFY_ROOT/input" "$DATA_DIR/input"
link_dir "$COMFY_ROOT/user" "$DATA_DIR/user"
link_dir "$COMFY_ROOT/temp" "$DATA_DIR/temp"

if [[ -d /root/.cache && ! -L /root/.cache ]]; then
  cp -an /root/.cache/. "$DATA_DIR/cache/xdg/" 2>/dev/null || true
  rm -rf /root/.cache
fi
ln -sfn "$DATA_DIR/cache/xdg" /root/.cache

# --- model downloads (skip existing; .part suffix so an interrupted download
# --- is never mistaken for a finished file, and -C - resumes it — plain
# --- --retry skips errors like HTTP/2 stream resets, hence --retry-all-errors)
if [[ -f "$APP_DIR/models.txt" ]]; then
  echo "──── Checking model files"
  while read -r relpath url; do
    [[ -z "$relpath" || "$relpath" == \#* ]] && continue
    target="$COMFY_ROOT/models/$relpath"
    if [[ -f "$target" ]]; then
      echo " [OK]  $relpath"
      continue
    fi
    echo " [DL]  $relpath"
    mkdir -p "$(dirname "$target")"
    curl -L --fail -C - --retry 5 --retry-delay 5 --retry-all-errors -o "$target.part" "$url"
    mv "$target.part" "$target"
  done < "$APP_DIR/models.txt"
fi

# --- seed bundled workflows into the UI (never overwrite user edits) ---------
if [[ -d "$APP_DIR/workflows" ]]; then
  mkdir -p "$DATA_DIR/user/default/workflows"
  cp -an "$APP_DIR/workflows/." "$DATA_DIR/user/default/workflows/"
fi

# --- stop ComfyUI-Manager from replacing the locked stack --------------------
MANAGER_DIR="$DATA_DIR/user/__manager"
mkdir -p "$MANAGER_DIR"
cat > "$MANAGER_DIR/pip_blacklist.list" <<'EOF'
torch
torchvision
torchaudio
xformers
transformers
tokenizers
huggingface-hub
numpy
nvidia-
cuda-toolkit
cuda-bindings
triton
sageattention
EOF
if [[ ! -f "$MANAGER_DIR/config.ini" ]]; then
  cat > "$MANAGER_DIR/config.ini" <<'EOF'
[default]
always_lazy_install = False
use_uv = False
network_mode = public
security_level = normal
EOF
fi

exec "$@"
