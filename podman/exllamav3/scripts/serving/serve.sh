#!/bin/bash

# Run TabbyAPI (ExLlamaV3 backend) with the 27B exl3 model on the 5090.
# Host port 8090 -> container port 5000.
#
# Uses the official TabbyAPI image (cu13 tag = CUDA 13, Blackwell-ready).
# Image entrypoint is python3, so the command is main.py + flags.
#
# ExLlamaV3 needs /dev/shm for TP handoff buffers and CPU MoE offload;
# the default 64MiB container shm is too small.
podman run --rm -it \
  --device nvidia.com/gpu=0 \
  --shm-size=8g \
  -v /srv/models/exllamav3:/app/models:ro \
  -p 8090:5000 \
  ghcr.io/theroyallab/tabbyapi:cu13 \
  main.py --host 0.0.0.0 --port 5000 \
  --model-dir /app/models \
  --model-name qwen3.8-27b-exl3 \
  --max-seq-len 131072  # must be a multiple of 256 (exllamav3 paging)

