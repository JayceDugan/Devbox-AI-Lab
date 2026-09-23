#!/bin/bash

podman run --rm -it \
  --device nvidia.com/gpu=0 \
  -v /srv/models/hub/models--neroued--Qwen3.8-27B-nvfp4-NInfer/snapshots/11dbbbbbc33db198afe2f02c9232c771ff7031be/qwen3_8_27b_nvfp4.ninfer:/qwen3_8_27b_nvfp4.ninfer:ro \
  ai-lab/ninfer-server:latest \
  python3 tools/bench/run_serve_concurrency.py \
  --serve build/apps/ninfer-serve \
  --suite corpus-makespan \
  --artifact qwen3_8_27b=/qwen3_8_27b_nvfp4.ninfer \
  --concurrency 1 --concurrency 2 --concurrency 4 --concurrency 8 \
  --mode mtp0 --sampling stochastic \
  --output profiles/bench/serve_corpus_qwen3_8_27b_nvfp4_mtp0_20260817
