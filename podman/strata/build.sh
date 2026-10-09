#!/bin/bash
#
# Build (or update) the Strata image from upstream source, using upstream's own
# Dockerfile. The engine is compiled during the build, so the container never
# compiles anything at runtime.
#
#   ./build.sh           # latest main
#   ./build.sh <ref>     # a tag, branch or commit
#
# Then: systemctl --user restart strata
#
# Each build is tagged :latest and :<commit>, so a bad update can be rolled
# back by retagging the previous commit as :latest.
#
set -euo pipefail

REF="${1:-main}"
REPO=https://github.com/Niko1221/Strata.git
IMAGE=localhost/ai-lab/strata

# RTX 5090 / 5080 are both sm_120; building one arch is much faster
CUDA_ARCHITECTURES="${CUDA_ARCHITECTURES:-120}"

SRC=$(mktemp -d)
trap 'rm -rf "$SRC"' EXIT

git clone --quiet --filter=blob:none "$REPO" "$SRC"
git -C "$SRC" checkout --quiet "$REF"
SHA=$(git -C "$SRC" rev-parse --short=12 HEAD)
echo "Building Strata $REF ($SHA)"

# --format docker keeps the image's HEALTHCHECK (OCI format drops it)
podman build \
  --format docker \
  --build-arg CUDA_ARCHITECTURES="$CUDA_ARCHITECTURES" \
  --label strata.commit="$SHA" \
  -t "$IMAGE:$SHA" \
  -t "$IMAGE:latest" \
  "$SRC"

echo "Built $IMAGE:$SHA (also tagged :latest)"
