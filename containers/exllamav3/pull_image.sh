#!/bin/bash

# Pull the official TabbyAPI image (cu13 tag = CUDA 13 build, Blackwell-ready).
# Other tags: latest (CUDA 12.8), latest-extras (12.8 + embeddings stack).
podman pull ghcr.io/theroyallab/tabbyapi:cu13
