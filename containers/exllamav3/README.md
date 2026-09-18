# exllamav3 container

ExLlamaV3 inference on the 5090, served via **TabbyAPI** (the official
OpenAI-compatible server for ExLlamaV3). Runs the **official TabbyAPI image**
(`ghcr.io/theroyallab/tabbyapi:cu13` — CUDA 13 build, Blackwell-ready), with
models staged from the HF cache and the GPU piped through `nvidia.com/gpu=0`.

## Layout

| File | Purpose |
|---|---|
| `pull_image.sh` | `podman pull ghcr.io/theroyallab/tabbyapi:cu13` |
| `exllamav3.container` | systemd unit (port 8090→5000, staged models → `/app/models:ro`, GPU 0, shm 8g) |
| `scripts/serving/serve.sh` | one-shot `podman run` with the serving flags |
| `scripts/utils/sync_model.sh` | stage a model from the HF cache into `/srv/models/exllamav3/` (deref'ed btrfs COW copy) |
| `scripts/utils/test_gpu.sh` | verify torch sees the GPU inside the image |
| `scripts/utils/test_curl.sh` | smoke test the chat completions endpoint |

Image tags: `latest` (CUDA 12.8), `cu13` (CUDA 13, used here),
`latest-extras` (12.8 + embeddings stack). The image bakes in the prebuilt
exllamav3 wheels pinned to its torch/CUDA build — no local compilation.

## Usage

```sh
./pull_image.sh                       # fetch the image
./scripts/serving/serve.sh            # run interactively (Ctrl-C to stop)

# or via systemd:
# copy exllamav3.container into ~/.config/containers/systemd/ (or /etc) and:
systemctl --user start exllamav3
```

API: OpenAI-compatible on `http://127.0.0.1:8090` (host) → container port 5000.
Model name: `qwen3.8-27b-exl3`.

## Models

Models are staged into `/srv/models/exllamav3/<name>` with
`scripts/utils/sync_model.sh` (deref'ed btrfs reflink copy of the HF snapshot —
instant, no extra real disk usage). HF cache files are relative symlinks into
`../blobs`, so a snapshot-only bind mount looks intact to `ls` but fails to
open; the staged dir is self-contained. `/srv/models/exllamav3` is mounted at
`/app/models`, so each staged folder becomes a servable model name.

Staged now: `qwen3.8-27b-exl3` (6-bit exl3 v1.4.2 safetensors-sharded format).
To stage the other exl3 model:

```sh
./scripts/utils/sync_model.sh models--turboderp--Qwen3.8-Flash-Next-exl3 qwen3.8-flash-next-exl3
```

Re-run `sync_model.sh` after an `hf` update to refresh a staged model.

## Notes

- Only one of ninfer / exllamav3 can use the 5090 at a time (both load the
  27B model); stop `nice_williamson` (ninfer) before starting exllamav3.
- `--shm-size=8g` is required: ExLlamaV3 uses `/dev/shm` for tensor-parallel
  handoff buffers and CPU MoE offload; the 64 MiB default is too small.
- `--max-seq-len 179968` matches the ninfer serving profile (~180k) rounded
  down to a multiple of 256, which exllamav3's paged cache requires.
  The model's native context is 262144 (hybrid attention). Lower it if the
  KV cache is too big for 32 GB.
