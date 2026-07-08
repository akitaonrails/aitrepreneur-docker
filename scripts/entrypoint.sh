#!/usr/bin/env bash
#
# Wires the app's fixed on-disk paths to the /data volume so that all state
# (job database, datasets, training outputs, HF model cache) survives
# container rebuilds. The app itself is untouched — it just follows symlinks.
set -euo pipefail

APP_DIR=/app/ai-toolkit
DATA_DIR=/data

mkdir -p "$DATA_DIR/db" "$DATA_DIR/datasets" "$DATA_DIR/outputs" "$DATA_DIR/hf-cache"

# --- SQLite job database (the UI expects it at the repo root) ---------------
# A build may have seeded an empty db inside the image; keep the volume's copy
# if one exists, otherwise adopt the image's.
if [[ -e "$APP_DIR/aitk_db.db" && ! -L "$APP_DIR/aitk_db.db" ]]; then
  if [[ ! -e "$DATA_DIR/db/aitk_db.db" ]]; then
    mv "$APP_DIR/aitk_db.db" "$DATA_DIR/db/aitk_db.db"
  else
    rm -f "$APP_DIR/aitk_db.db"
  fi
fi
ln -sfn "$DATA_DIR/db/aitk_db.db" "$APP_DIR/aitk_db.db"

# --- datasets/ and output/ ---------------------------------------------------
link_dir() {
  local app_path="$1" data_path="$2"
  if [[ -d "$app_path" && ! -L "$app_path" ]]; then
    cp -an "$app_path/." "$data_path/" 2>/dev/null || true
    rm -rf "$app_path"
  fi
  ln -sfn "$data_path" "$app_path"
}
link_dir "$APP_DIR/datasets" "$DATA_DIR/datasets"
link_dir "$APP_DIR/output" "$DATA_DIR/outputs"

# --- apply any pending schema changes to the (possibly older) volume db -----
(cd "$APP_DIR/ui" && npx prisma db push --skip-generate)

exec "$@"
