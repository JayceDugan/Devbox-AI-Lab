#!/bin/bash
# Launch the PR review agent sandbox.
#
#   ./run.sh                        -> sandbox "pr-review-agent", provider "github-review"
#   ./run.sh <name>                 -> custom sandbox name, default provider
#   ./run.sh <name> <provider>      -> custom provider (e.g. a different GITHUB_TOKEN)
#
# To point this agent at a different GitHub token, create a provider with the
# review profile and pass its name here:
#
#   GITHUB_TOKEN=<other-token> openshell provider create \
#     --name github-review-bot --type github-review --credential GITHUB_TOKEN
#   ./run.sh pr-review-bot github-review-bot
#
# Inference comes from the workspace-level route (`openshell inference set`),
# so no inference provider attachment is needed.
set -euo pipefail
NAME="${1:-pr-review-agent}"
PROVIDER="${2:-github-review}"
openshell sandbox create \
  --name "$NAME" \
  --from localhost/ai-lab/openshell-pi-pr-review-sandbox \
  --provider "$PROVIDER"
