# RTX 5080 stack: ASR, aligner, embeddings, TTS

Four small models share the RTX 5080 and run all the time. The 5090 is left to
Strata / vllm / ninfer / unsloth. Every container gets the 5080 by UUID
(`GPU-e4668f97-…`) through CDI, so a change in device order can never put one on the 5090.

| Service | Model | Server | Host port | On the `inference` network |
| --- | --- | --- | --- | --- |
| `asr` | Qwen/Qwen3-ASR-1.7B | `vllm/vllm-openai:latest` | 8101 | `http://asr:8000` |
| `aligner` | Qwen/Qwen3-ForcedAligner-0.6B-hf | `ai-lab/aligner` (Transformers, `podman/aligner/`) | 8102 | `http://aligner:8000` |
| `embeddings` | google/embeddinggemma-2 (text + image) | `ai-lab/embeddings` (vLLM nightly + patch, `podman/embeddings/`) | 8103 | `http://embeddings:8000` |
| `kokoro` | hexgrad/Kokoro-82M | `kokoro-fastapi-gpu:v0.9.0-cu128` | 8104 | `http://kokoro:8880` |

| File | What |
| --- | --- |
| `podman/quadlet/{asr,aligner,embeddings,kokoro}.container` | The services |
| `podman/ai-5080/ai-5080.target` | Pulls in all four (for starting them by hand) |
| `podman/boot/ai-boot.target` | Everything started at boot: `ai-5080.target`, then `strata` |
| `podman/boot/ai-boot.timer` | Starts `ai-boot.target` 5 min after boot |
| `podman/install.sh` | Links the quadlets, copies the targets + timer to `~/.config/systemd/user`, enables the timer |

## Startup (why it is delayed)

Inference engines loading at boot used to black out the box. So no model service is
enabled; only `ai-boot.timer` is. It fires `OnBootSec=5min` (from kernel boot; the user
manager runs from boot because lingering is on, so no login is needed) and starts
`ai-boot.target`. The services then load **one at a time**: asr → aligner → embeddings
→ kokoro → strata, each `After=` the previous one, and each 5080 service only counts
as started once its health check passes (`Notify=healthy`), so the two GPUs never load
at the same moment. Expect the 5080 stack ready ~11 min after boot (5 min timer, ~90 s
`network-online.target` wait (Strata README, Gotchas), ~4 min loading), Strata a
couple of minutes later. `unsloth` is not started at boot (training only, start by hand).

A crash restarts after 60 s, at most 3 times in 15 min (`StartLimitBurst`), so a broken
engine cannot loop power spikes. After that: fix it, `systemctl --user reset-failed <svc>`.

```bash
systemctl --user start ai-5080.target          # all four, in order (not strata)
systemctl --user stop asr aligner embeddings kokoro
systemctl --user restart embeddings            # one
systemctl --user status ai-boot.timer asr aligner embeddings kokoro
journalctl --user -u asr -f
nvidia-smi -i 1                                # the 5080
```

After editing a quadlet: `systemctl --user daemon-reload && systemctl --user restart <svc>`.
After editing a target/timer: re-run `podman/install.sh` (they are copies).

## Bifrost

Custom providers, base type `openai`, base URL = container name + internal port, no
`/v1` (same as the Strata provider). Allow only the request types listed.

| Provider | Base URL | Allowed requests | Model in requests |
| --- | --- | --- | --- |
| `ASR` | `http://asr:8000` | transcription, list_models | `ASR/qwen3-asr` |
| `Embeddings` | `http://embeddings:8000` | embedding, list_models | `Embeddings/embeddinggemma-2` |
| `TTS` | `http://kokoro:8880` | speech, speech_stream, list_models | `TTS/kokoro` |

Tested 2026-10-09 through Bifrost (`:8080`): model list, transcription (`prompt` and
`language` are forwarded), speech, text embeddings all work.

Not through Bifrost, call these directly:
- **Aligner**: `/align` is not an OpenAI route. `http://aligner:8000/align` (host `:8102`).
- **Image embeddings**: `http://embeddings:8000/v1/embeddings` (host `:8103`) with the
  `messages` shape below. Bifrost requires `input`, drops unknown fields (an image sent via
  `extra_params` silently comes back as the embedding of the empty `input`), and its
  OpenAI-type providers reject non-text embedding parts (`core/providers/openai/embedding.go`);
  the running build (2026-09-29) does not even parse its own multimodal `input` items.

## VRAM (16 GB)

Measured with all four running: ~12.4 GB used.

| Service | Used | Set by |
| --- | --- | --- |
| asr | 6.4 GB | `--gpu-memory-utilization 0.45` (0.35 does not start: no room for KV cache) |
| embeddings | 2.7 GB | `--gpu-memory-utilization 0.2` |
| aligner | 2.3 GB | model size (bf16) |
| kokoro | 1.0 GB | model size |

The two vLLM services check at startup that their share is free, so starting other
GPU work on the 5080 first can stop them from starting.

## API

### Speech to text: `POST :8101/v1/audio/transcriptions` (OpenAI)

Multipart: `file`, `model=qwen3-asr`, optional `language` (`en`), optional `prompt`
(vocabulary/context hints; it goes in as the system turn). A plain vocabulary list works
(`Australian English. Vocabulary: neighbours, Kubernetes, heartbeats` switched "neighbors"
to "neighbours" 3/3); instructions like "always spell X as Y" are ignored. Any format ffmpeg reads. Audio over 30 s is split into
30 s chunks, which can put a stray full stop at a boundary.

### Word timestamps: `POST :8102/align`

Multipart: `file` (any ffmpeg format), `transcript`, optional `language` (name or code;
the aligner supports zh, en, yue, fr, de, it, ja, ko, pt, ru, es). Max 300 s of audio
(`MAX_SECONDS`). Returns:

```json
{"duration": 4.029, "words": [{"word": "The", "start": 0.0, "end": 0.08}, ...]}
```

Punctuation is dropped from words. Requests run one at a time on the GPU.

### Embeddings: `POST :8103/v1/embeddings` (OpenAI, vLLM)

768-dim, normalised. `model=embeddinggemma-2`.

- Text: `{"input": ["...", "..."]}`. Add the model's task prefixes yourself:
  query `task: search result | query: <q>`, document `title: <title or none> | text: <body>`.
  Images take no prefix.
- Image (one per request): `{"messages": [{"role": "user", "content": [{"type": "image_url", "image_url": {"url": "data:image/png;base64,..."}}]}]}`.
  With the OpenAI SDK, send `messages` via `extra_body` or `client.post`.
- `dimensions` (Matryoshka) is rejected by vLLM for this model; always 768.
- bf16 only. The model card warns fp16 silently returns NaN/garbage.

### Text to speech: `POST :8104/v1/audio/speech` (OpenAI)

`{"model": "kokoro", "voice": "af_heart", "input": "...", "response_format": "mp3"}`.
Formats: mp3, wav, opus, flac, aac, pcm. 72 voices: `GET :8104/v1/audio/voices`.
Mixes: `"af_bella+af_sky"` or `"af_bella(2)+af_sky(1)"`.

## TODO: drop the vLLM patch (embeddings)

embeddinggemma-2 needs vLLM main (support merged 2026-10-06, PR #60254, not in v0.31.0)
**and** the unmerged https://github.com/vllm-project/vllm/pull/60631: without it the
encoder attention needs 160 KB of shared memory per block and the 5080 has ~99 KB, so
the engine dies at startup with `OutOfResources: Required: 163840, Hardware limit: 101376`.
`podman/embeddings/patch_vllm.py` applies the PR's 9 lines at build time.

When a release contains both:
1. `./podman/embeddings/build.sh docker.io/vllm/vllm-openai:latest`: the patch step prints
   `already contains the PR #60631 fix` if it is no longer needed.
2. Point `embeddings.container` at `docker.io/vllm/vllm-openai:latest`, delete
   `podman/embeddings/`, restart.

Until then, update with `./podman/embeddings/build.sh` (latest nightly). Builds are tagged
by vLLM version; roll back with `podman tag localhost/ai-lab/embeddings:<version> localhost/ai-lab/embeddings:latest`.

## Updating

- asr: `podman pull docker.io/vllm/vllm-openai:latest && systemctl --user restart asr`
- aligner: bump pins in `podman/aligner/Containerfile`, `./podman/aligner/build.sh`, restart
- kokoro: change the tag in `kokoro.container` (keep a `-cu128` or newer CUDA tag: the
  default cu126 image has no RTX 50xx kernels), restart

## Containment

Rootless, `DropCapability=ALL`, `NoNewPrivileges=true`, no runtime downloads
(`HF_HUB_OFFLINE=1`, `DOWNLOAD_MODEL=false`). Only `/srv/models/hub` is mounted, read-only,
never `/srv/models` itself: that is `HF_HOME` and holds the Hugging Face token. The same
goes for strata, vllm and unsloth (vllm and unsloth mount it writable to download). Kokoro
mounts nothing: its baked-in weights are byte-identical to the cached hexgrad/Kokoro-82M.
