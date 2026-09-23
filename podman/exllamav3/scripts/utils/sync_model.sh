#!/bin/bash
#
# Stage a model from the HF cache into /srv/models/exllamav3/<name> as a
# dereferenced COW copy (btrfs reflink: instant, no extra real disk usage).
#
# The HF cache stores model files as relative symlinks into ../blobs, which
# break when only the snapshot dir is bind-mounted into a container. A
# dereferenced copy makes each model a self-contained directory.
#
# Usage: sync_model.sh <repo-dir-name> <model-name> [snapshot-hash]
#   repo-dir-name : directory under /srv/models/hub (e.g. models--turboderp--Qwen3.8-27B-exl3)
#   model-name    : name the model will be served as (e.g. qwen3.8-27b-exl3)
#   snapshot-hash : optional; defaults to the newest snapshot in the repo
#
# Re-run after an `hf` update to refresh a staged model.

set -euo pipefail

repo="${1:?repo dir name under /srv/models/hub}"
name="${2:?model name to stage as}"
hub=/srv/models/hub
out=/srv/models/exllamav3

src="$hub/$repo"
[[ -d "$src" ]] || { echo "no such repo: $src" >&2; exit 1; }

snapshot="${3:-$(ls -1t "$src/snapshots" | head -1)}"
src="$src/snapshots/$snapshot"
[[ -d "$src" ]] || { echo "no such snapshot: $src" >&2; exit 1; }

mkdir -p "$out"
rm -rf "$out/$name"
cp -aL --reflink=auto "$src" "$out/$name"

echo "staged $out/$name (from $src)"
ls "$out/$name" | head -5
