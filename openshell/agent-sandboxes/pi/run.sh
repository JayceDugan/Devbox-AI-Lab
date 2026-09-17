#!/bin/bash
# Launch the base pi coding agent sandbox.
#   ./run.sh              -> sandbox "pi-agent" with provider "github"
#   ./run.sh <name> [provider]
# Inference comes from the workspace-level route (`openshell inference set`);
# the github provider supplies the token + composed GitHub network policy.
set -euo pipefail
NAME="${1:-pi-agent}"
PROVIDER="${2:-github}"
openshell sandbox create \
  --name "$NAME" \
  --from localhost/ai-lab/openshell-pi-sandbox \
  --provider "$PROVIDER"
