#!/bin/bash

podman run -it --rm \
  --name llama-cpp \
  -v /srv/models:/models \
  --device nvidia.com/gpu=0 \
  --security-opt label=disable \
  llama-cpp
