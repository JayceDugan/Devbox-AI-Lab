#!/bin/bash

podman run --rm -it \
--device nvidia.com/gpu=0 \
-v /srv/models/hub/models--neroued--Qwen3.8-27B-nvfp4-NInfer:/models:ro \
ai-lab/ninfer-server:latest \
python3 tools/bench/run_serve_concurrency.py \
--serve build/apps/ninfer-serve \
--artifact qwen3_8_27b=/models/snapshots/11dbbbbbc33db198afe2f02c9232c771ff7031be/qwen3_8_27b_nvfp4.ninfer \
--mode mtp3 --suite corpus-makespan \
--concurrency 1 --concurrency 2 --concurrency 4 --concurrency 8 \
--max-context 131072 --kv-capacity auto \
--output profiles/bench/concurrent_corpus_qwen3_8_27b_nvfp4_mtp3
