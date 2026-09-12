#!/bin/bash

# This script confirms graphics card detection is working inside the ninfer image.
# TBH should add a bunch of checks here to confirm ninfer image is as expected..
echo "Checking for nvidia-smi...";

podman run --rm -it \
  --device nvidia.com/gpu=0 \
  ai-lab/ninfer-server:latest nvidia-smi
