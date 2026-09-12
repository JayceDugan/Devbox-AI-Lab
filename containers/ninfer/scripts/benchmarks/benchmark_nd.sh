#!/bin/bash

podman run --rm -it \
  --device nvidia.com/gpu=0 \
  -v /srv/models/hub/models--neroued--Qwen3.8-27B-nvfp4-NInfer/snapshots/11dbbbbbc33db198afe2f02c9232c771ff7031be/qwen3_8_27b_nvfp4.ninfer:/qwen3_8_27b_nvfp4.ninfer:ro \
  ai-lab/ninfer-server:latest \
  python3 tools/bench/run_serve_concurrency.py \
  --serve build/apps/ninfer-serve \
  --artifact qwen3_8_27b=/qwen3_8_27b_nvfp4.ninfer \
  --mode dflash2_7 --sampling stochastic --suite corpus-makespan --concurrency 1 \
  --max-context 131072 --kv-capacity auto --prefill-chunk 1024 --port 18080 \
  --output profiles/bench/dflash2-single-kv-fix-20260906/nvfp4
