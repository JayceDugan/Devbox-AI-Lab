#!/usr/bin/env bash
set -euo pipefail

REPO=/srv/models/hub/models--Comfy-Org--Qwen-Image-2.1
SNAP=$(cat "$REPO/refs/main")
DATA=/srv/comfyui

podman rm -f comfyui 2>/dev/null || true

podman run -d --name comfyui \
  --device nvidia.com/gpu=all \
  --security-opt=label=disable \
  -p 8188:8188 \
  -v "$REPO":/models/qwen-image:ro \
  -v "$DATA/output":/opt/comfyui/output \
  -v "$DATA/input":/opt/comfyui/input \
  -e QWEN_SNAPSHOT="$SNAP" \
  comfyui
