#!/bin/bash
# Launch the feature-delivery agent sandbox.
#
#   ./run.sh              -> creates sandbox "developer-agent" with provider "github"
#   ./run.sh <name>       -> custom sandbox name, default provider
#   ./run.sh <name> <provider> -> custom provider (e.g. a different GITHUB_TOKEN,
#                                see README.md "Using a different GitHub token")
#
# Inference comes from the workspace-level route (`openshell inference set`),
# so no inference provider attachment is needed. The GitHub provider
# supplies the token and its composed network policy.
set -euo pipefail
NAME="${1:-developer-agent}"
PROVIDER="${2:-github}"
openshell sandbox create \
  --name "$NAME" \
  --from localhost/ai-lab/openshell-pi-developer-sandbox \
  --provider "$PROVIDER"
