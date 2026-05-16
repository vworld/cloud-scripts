#!/usr/bin/env bash

set -euo pipefail

WORKSPACE_DIR="/workspace"
STATE_DIR="$WORKSPACE_DIR/runtime"

CACHE_DIR="$STATE_DIR/cache"
TMP_DIR="$STATE_DIR/tmp"
LOCAL_SHARE_DIR="$STATE_DIR/local-share"

HF_HOME_DIR="$CACHE_DIR/huggingface"
TORCH_HOME_DIR="$CACHE_DIR/torch"
TRITON_CACHE_DIR="$CACHE_DIR/triton"
PIP_CACHE_DIR="$CACHE_DIR/pip"


echo "=== Verifying workspace mount ==="

if ! mountpoint -q "$WORKSPACE_DIR"; then
  echo "ERROR: $WORKSPACE_DIR is not mounted"
  exit 1
fi

echo "=== Creating state directories ==="

mkdir -p \
  "$CACHE_DIR" \
  "$LOCAL_SHARE_DIR" \
  "$TMP_DIR" \
  "$HF_HOME_DIR" \
  "$TORCH_HOME_DIR" \
  "$TRITON_CACHE_DIR" \
  "$PIP_CACHE_DIR" 


migrate_dir() {
  local SOURCE_PATH="$1"
  local TARGET_PATH="$2"

  echo "=== Migrating $SOURCE_PATH -> $TARGET_PATH ==="

  mkdir -p "$TARGET_PATH"

  # Already migrated
  if [ -L "$SOURCE_PATH" ]; then
    echo "Symlink already exists, skipping"
    return
  fi

  # Backup existing source dir if present
  if [ -e "$SOURCE_PATH" ]; then
    local BACKUP_PATH="${SOURCE_PATH}_migrated_$(date +%Y%m%d_%H%M%S)"

    echo "Backing up existing directory to:"
    echo "  $BACKUP_PATH"

    mv "$SOURCE_PATH" "$BACKUP_PATH"
  fi

  # Ensure persistent target exists
  mkdir -p "$TARGET_PATH"

  # Create symlink
  ln -s "$TARGET_PATH" "$SOURCE_PATH"

  echo "Symlink created:"
  echo "  $SOURCE_PATH -> $TARGET_PATH"
}


echo "=== Migrating ~/.cache ==="
migrate_dir "$HOME/.cache" "$CACHE_DIR"


echo "=== Migrating ~/.local/share ==="
migrate_dir "$HOME/.local/share" "$LOCAL_SHARE_DIR"

echo "=== Migrating /tmp ==="
migrate_dir "/tmp" "$TMP_DIR"


echo "=== Configuring persistent environment variables ==="

append_if_missing() {
  local LINE="$1"

  if ! grep -Fq "$LINE" "$HOME/.bashrc"; then
    echo "$LINE" >> "$HOME/.bashrc"
  fi
}

append_if_missing ''
append_if_missing '# Workspace runtime paths'

append_if_missing "export TMPDIR=$TMP_DIR"
append_if_missing "export HF_HOME=$HF_HOME_DIR"
append_if_missing "export TRANSFORMERS_CACHE=$HF_HOME_DIR"
append_if_missing "export TORCH_HOME=$TORCH_HOME_DIR"
append_if_missing "export TRITON_CACHE_DIR=$TRITON_CACHE_DIR"
append_if_missing "export PIP_CACHE_DIR=$PIP_CACHE_DIR"

echo "=== Bootstrap complete ==="

echo ""
echo "Run:"
echo "  source ~/.bashrc"
