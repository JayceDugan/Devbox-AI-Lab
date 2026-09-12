#!/bin/bash

podman run --rm -it \
  --device nvidia.com/gpu=0 \
  -v /srv/models/hub/models--neroued--Qwen3.8-27B-nvfp4-NInfer:/models:ro \
  -p 8088:8088 \
  ai-lab/ninfer-server:latest \
  ./build/apps/ninfer-serve /models/snapshots/11dbbbbbc33db198afe2f02c9232c771ff7031be/qwen3_8_27b_nvfp4.ninfer \
  --max-context 131072 \
  --kv-capacity auto \
  --max-concurrency 4 \
  --kv-dtype fp8 \
  --device-state-slots 4 \
  --host-state-slots 12 \
  --host-kv-mib 12288 \
  --spec mtp \
  --draft-tokens 3 \
  --lm-head-draft \
  --preserve-thinking \
  --host 0.0.0.0 \
  --port 8088
