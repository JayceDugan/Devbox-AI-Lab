#!/usr/bin/env bash
set -euo pipefail

cat > /opt/comfyui/extra_model_paths.yaml <<EOF
qwen_image:
    base_path: /models/qwen-image/snapshots/${QWEN_SNAPSHOT}
    diffusion_models: diffusion_models
    text_encoders: text_encoders
    vae: vae
EOF

exec python main.py --listen 0.0.0.0 --port 8188 "$@"
