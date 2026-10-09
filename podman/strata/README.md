# Strata

[Strata](https://github.com/Niko1221/Strata) serves Qwen3.8-Flash-Next (125B MoE)
from a mix of VRAM, RAM and SSD. It is an untrusted project, so it only ever
runs inside a locked-down rootless podman container. Never run its `setup.sh`
or `START-HERE.bat` on the host.

| File | What |
| --- | --- |
| `podman/strata/build.sh` | Builds/updates the image from upstream source |
| `podman/quadlet/strata.container` | The service: model choice, GPU, limits, env |
| `bootstrap/system-configuration/systemd-dropins/user@.service.d/memlock.conf` | Host memlock limit (200G) the quadlet needs |

## Day to day

```bash
systemctl --user start strata      # also started at boot: see below
systemctl --user stop strata
systemctl --user restart strata
systemctl --user status strata
journalctl --user -u strata -f     # logs; "ready: ..." means it is serving
curl localhost:8090/health         # {"status": "ok", "loaded": true, "images": true, ...}
```

- A normal start takes a couple of minutes: ~90 s waiting on `network-online.target`
  (see Gotchas), then 1-2 min loading ~50 GB into RAM and filling the GPU's expert cache.
- At boot, `ai-boot.timer` starts it 5 min after boot, after the RTX 5080 stack has
  loaded, so the GPUs never load at once (`podman/ai-5080/README.md`, Startup).
- Only one of `strata`, `vllm`, `ninfer` can run at a time: all three use the RTX 5090.
  To boot into one of the others instead, change `strata.service` in
  `podman/boot/ai-boot.target`, give that quadlet `After=kokoro.service`, and re-run
  `podman/install.sh`.
- After editing `strata.container`: `systemctl --user daemon-reload && systemctl --user restart strata`.

## Endpoints

Port **8090** on the host, **8080** inside the container. Any model name and any
API key work (no key is set).

| What | URL |
| --- | --- |
| Web chat, live monitor, settings | `http://homelab:8090/` |
| OpenAI-compatible | `http://homelab:8090/v1` (`/v1/chat/completions`, `/v1/models`) |
| OpenAI Responses (Codex CLI) | `http://homelab:8090/v1/responses` |
| Anthropic-compatible | `http://homelab:8090/v1/messages` (Claude Code: `ANTHROPIC_BASE_URL=http://homelab:8090`) |
| Health / what it is running | `/health`, `/v1/status` |
| From Bifrost / other containers on the `inference` network | `http://strata:8080/v1` |

Reasoning effort: `off | low | medium | high` (chat menu, or `reasoning_effort` in the request).

Strata only answers to host names it knows (DNS rebinding protection; IPs and
`localhost` always work). Reaching it under a new name gives a `403 ... not
allowed` error: add the name to `STRATA_ALLOWED_HOSTS` in the quadlet and restart.

## Models

The models come read-only from the HF hub cache (`/srv/models/hub`, mounted `:ro` at the
same path; not `/srv/models` itself, which holds the HF token).
`FAMILY`, `MODEL` and `GGUF_DIR` in the quadlet pick one:

| Model | `FAMILY` | `MODEL` | `GGUF_DIR` (under `/srv/models/hub/`) |
| --- | --- | --- | --- |
| **Qwen3.8-Flash-Next IQ3_XXS** (current; general use) | `qwen` | `IQ3_XXS` | `models--ISTA-DASLab--Qwen3.8-Flash-Next-GSQ-RCO-GGUF/snapshots/2c4721899b4382bd07dfb61ae4fbad90c09caf7d/IQ3_XXS` |
| **Coder IQ1_M** (half the experts, kept for code; faster, weaker outside code and in non-English text) | `coder` | `IQ1_M` | `models--ISTA-DASLab--Qwen3.8-Flash-Next-GSQ-RCO-Coder-GGUF/snapshots/5348543e0147355ac9cbcb031184a3546350988e/IQ1_M` |

The unsloth `Q8_0` in the cache is **not** usable: Strata only runs ISTA-DASLab's
GSQ-RCO files (Q2_0, IQ2_XS, IQ3_XXS, IQ3_S, Coder IQ1_M, Swift 1.5) and Unsloth's
UD-IQ4_XS / UD-Q4_K_XL. To add another, `hf download` it into the cache and add a row.

**Switching:** edit those three lines, `daemon-reload`, restart. The first start of
a model runs its setup (a few minutes: builds its pack in the volume) and saves a
config to `/data/config/strata-<model>.json`; after that, switching back and forth
is just the edit + restart.

## Changing settings (context, vision, KV cache)

Each model's settings are saved in its config on first setup, so changing
`CONTEXT`, `VISION`, `KV` (or `KV_STREAMING`, `LOW_RAM`) needs one setup pass:

1. Edit the value in the quadlet and add `Environment=REINSTALL=1`.
2. `systemctl --user daemon-reload && systemctl --user restart strata`, wait for `ready:`.
3. **Remove** `REINSTALL=1` again (otherwise every start re-runs setup) and `daemon-reload`.

Current settings: 262144 context (the model's trained max), 8-bit KV cache kept in
RAM, images on.

## Vision

On (`VISION=yes`). Images go in the web chat (**Picture** button) or as OpenAI
`image_url` / Anthropic `image` content parts (data URLs or http(s) URLs). The
encoder (`mmproj-Qwen3.8-Flash-Next-BF16.gguf`, 0.9 GB) is in the data volume and
is shared with the Coder. `VISION=cpu` runs the encoder on the CPU instead (frees
~1 GB of VRAM for the expert cache); `no` turns it off. Both need the
REINSTALL pass above.

## Updating

```bash
cd ~/Devbox-AI-Lab/podman/strata
./build.sh                 # latest main  (or: ./build.sh <tag|branch|commit>)
systemctl --user restart strata
```

The build clones upstream into a temp dir and builds with upstream's Dockerfile
for sm_120 only (~15-20 min). Each image is tagged `:latest` and `:<commit>`.

Rollback:

```bash
podman images localhost/ai-lab/strata                 # find the previous commit tag
podman tag localhost/ai-lab/strata:<commit> localhost/ai-lab/strata:latest
systemctl --user restart strata
```

If an update changes the setup/config format, the old config on the volume may
need one `REINSTALL=1` start.

## Data

Named volume `strata-data` (`/data`): per-model configs, packs, the MTP draft layer
(~5 GB, speculative decoding) and the vision encoder. Nothing else persists:
the container is recreated on every start. `podman volume rm strata-data`
resets everything (the next start re-downloads MTP + encoder and rebuilds packs).

## Containment

- Rootless podman, `DropCapability=ALL`, `NoNewPrivileges=true`.
- Model files mounted read-only (setup warns it cannot write its `.done` marks there; harmless).
- GPU: only the RTX 5090, passed by UUID via CDI, so device reordering can never
  hand it the 5080. There are no NVIDIA OCI hooks on this host, so CDI is the only path in.
- RAM: `Memory=200g` cgroup cap, and locked memory capped at 200 GiB.
- Network: the server itself makes no outbound calls except fetching image URLs or MCP
  servers a request asks for. Downloads happen only in the build (llama.cpp, pip) and in a
  model's first setup (MTP layer and vision encoder from Hugging Face).
- No API key, like the other services here; set one with `Environment=API_KEY=...` plus a
  REINSTALL start. Setting a key also turns the host-name check off.

## Host prerequisites / gotchas

- **memlock**: the quadlet sets `Ulimit=memlock=200G`, which rootless podman can only grant
  if the user manager's hard limit allows it, or the container fails to start. Install with
  `sudo bootstrap/system-configuration/install.sh`, then `sudo systemctl restart user@1000.service`
  (lingering is on, so logging out is not enough). Check:
  `systemctl show user@1000.service -p LimitMEMLOCK` → `214748364800`.
- **90 s start delay**: quadlets wait for the system's `network-online.target`, which nothing
  pulls in on this host, so every start waits out podman's 90 s timeout. Fix:
  `sudo systemctl add-wants multi-user.target network-online.target && sudo systemctl start network-online.target`.
- `unsloth` is not started at boot (training only) and only sees the 5090.
- RAM sizing: setup reads the host's 251 GB, not the 200 GB cap. Fine for every model here;
  for one whose experts exceed the cap, add `Environment=LOW_RAM=on`.
