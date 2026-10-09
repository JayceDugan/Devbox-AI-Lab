#!/bin/bash
#
# Build the forced-aligner image. Versions are pinned in the Containerfile;
# bump them there and rebuild, then: systemctl --user restart aligner
#
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

# --format docker keeps the HEALTHCHECK (OCI format drops it)
podman build --format docker -t localhost/ai-lab/aligner:latest .
