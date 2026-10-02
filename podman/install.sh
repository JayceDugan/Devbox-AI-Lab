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

######################
# Reload
######################
systemctl --user daemon-reload
