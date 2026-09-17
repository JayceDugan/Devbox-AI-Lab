#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
podman build -t ai-lab/openshell-pi-pr-review-sandbox .
