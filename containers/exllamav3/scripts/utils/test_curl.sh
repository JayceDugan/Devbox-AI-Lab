#!/bin/bash

# Smoke test against the TabbyAPI OpenAI-compatible endpoint (host port 8090).
curl http://127.0.0.1:8090/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen3.8-27b-exl3",
    "messages": [{"role": "user", "content": "Reply with one short sentence."}],
    "max_tokens": 256
  }'
