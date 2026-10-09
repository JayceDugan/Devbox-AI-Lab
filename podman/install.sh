#!/bin/bash
set -uex

######################
# Setup
######################

# Base container dir
mkdir -p ~/.config/containers/systemd

######################
# Netwokrs
######################
ln -sf "$PWD/quadlet/inference.network" \
    ~/.config/containers/systemd/inference.network

######################
# Containers
######################
ln -sf "$PWD/quadlet/unsloth.container" \
    ~/.config/containers/systemd/unsloth.container

ln -sf "$PWD/quadlet/beszel.container" \
    ~/.config/containers/systemd/beszel.container

ln -sf "$PWD/quadlet/beszel-agent.container" \
    ~/.config/containers/systemd/beszel-agent.container

ln -sf "$PWD/quadlet/postgres.container" \
    ~/.config/containers/systemd/postgres.container

ln -sf "$PWD/quadlet/vllm.container" \
    ~/.config/containers/systemd/vllm.container

ln -sf "$PWD/quadlet/openwebui.container" \
    ~/.config/containers/systemd/openwebui.container

ln -sf "$PWD/quadlet/bifrost.container" \
    ~/.config/containers/systemd/bifrost.container

ln -sf "$PWD/quadlet/ninfer.container" \
    ~/.config/containers/systemd/ninfer.container

ln -sf "$PWD/quadlet/strata.container" \
    ~/.config/containers/systemd/strata.container

# RTX 5080 stack (podman/ai-5080/README.md). Not enabled on their own:
# ai-boot.timer starts them (then strata) via ai-boot.target 5 min after boot.
for unit in asr aligner embeddings kokoro; do
    ln -sf "$PWD/quadlet/$unit.container" \
        ~/.config/containers/systemd/$unit.container
done

######################
# Plain user units
######################
# Copied, not symlinked: systemd does not notice a symlink's target vanishing
# (git checkout/pull), see bootstrap/system-configuration/install.sh
mkdir -p ~/.config/systemd/user
install -m 644 "$PWD/ai-5080/ai-5080.target" \
    "$PWD/boot/ai-boot.target" "$PWD/boot/ai-boot.timer" \
    ~/.config/systemd/user/

# Replaced by ai-boot.timer
if [ -e ~/.config/systemd/user/ai-5080.timer ]; then
    systemctl --user disable --now ai-5080.timer || true
    rm -f ~/.config/systemd/user/ai-5080.timer
fi

######################
# Reload
######################
systemctl --user daemon-reload
systemctl --user enable ai-boot.timer
