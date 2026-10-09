#!/bin/bash
#
# Build the embeddings image: the latest vLLM nightly with PR #60631 applied.
#
#   ./build.sh                 # pull the latest nightly and build on it
#   ./build.sh <image>         # build on a specific base, e.g. vllm/vllm-openai:v0.32.0
#
# Then: systemctl --user restart embeddings
#
# Each build is tagged :latest and :<vllm version>, so a bad nightly can be
# rolled back by retagging the previous version as :latest.
#
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

BASE="${1:-docker.io/vllm/vllm-openai:nightly}"
IMAGE=localhost/ai-lab/embeddings

podman pull "$BASE"
VERSION=$(podman run --rm --network=none --entrypoint python3 "$BASE" \
  -c "import vllm; print(vllm.__version__)" 2>/dev/null | tail -1 | tr '+' '_')

podman build --format docker --build-arg BASE="$BASE" \
  --label vllm.version="$VERSION" \
  -t "$IMAGE:$VERSION" -t "$IMAGE:latest" .

echo "Built $IMAGE:$VERSION (also tagged :latest)"
