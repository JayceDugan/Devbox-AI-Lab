#!/bin/bash

mkdir -p $HOME/ninfer/models

hf download neroued/Qwen3.8-27B-nvfp4-NInfer \
  qwen3_8_27b_nvfp4.ninfer \
  --local-dir $HOME/ninfer/models
