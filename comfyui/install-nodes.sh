#!/usr/bin/env bash
# Build-time: clone each custom node from the manifest and install its
# requirements, sanitized and constrained so the locked GPU stack survives.
#
# Manifest lines: <folder> <git-url> [git-ref]
set -euo pipefail

MANIFEST="$1"
CONSTRAINTS=/opt/app/constraints.txt
NODES_DIR=/comfyui/custom_nodes

mkdir -p "$NODES_DIR"

while read -r dir url ref; do
  [[ -z "$dir" || "$dir" == \#* ]] && continue

  echo "──── node: $dir ${ref:+(pinned: $ref)}"
  if [[ -n "${ref:-}" ]]; then
    git clone "$url" "$NODES_DIR/$dir"
    git -C "$NODES_DIR/$dir" checkout "$ref"
  else
    git clone --depth=1 "$url" "$NODES_DIR/$dir"
  fi

  req="$NODES_DIR/$dir/requirements.txt"
  [[ -f "$req" ]] || continue

  sanitized="$(mktemp)"
  python /opt/app/sanitize-reqs.py "$req" "$sanitized"

  if grep -Evq '^\s*(#|$)' "$sanitized"; then
    # Prefer no build isolation (faster, sees installed torch); fall back once.
    pip install --no-cache-dir --prefer-binary --no-build-isolation \
      --upgrade-strategy only-if-needed -c "$CONSTRAINTS" -r "$sanitized" || \
    pip install --no-cache-dir --prefer-binary \
      --upgrade-strategy only-if-needed -c "$CONSTRAINTS" -r "$sanitized"
  else
    echo "   (no installable requirements after sanitizing)"
  fi
  rm -f "$sanitized"
done < "$MANIFEST"
