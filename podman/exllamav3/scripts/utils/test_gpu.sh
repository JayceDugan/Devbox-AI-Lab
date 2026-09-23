#!/bin/bash

# Verify torch sees the GPU inside the TabbyAPI image.
# Note: the image entrypoint is python3, so the command is just the args.
echo "Checking torch + GPU..."

podman run --rm -it \
  --device nvidia.com/gpu=0 \
  ghcr.io/theroyallab/tabbyapi:cu13 \
  -c "import torch; print(torch.__version__); print('CUDA available:', torch.cuda.is_available()); print('GPU:', torch.cuda.get_device_name(0)); print('Capability:', torch.cuda.get_device_capability(0))"
