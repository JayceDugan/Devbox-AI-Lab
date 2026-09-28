#!/bin/bash
set -uex

######################
# Setup
######################

# Base container dir
mkdir -p ~/.config/containers/systemd

# Nginx
ln -sTf "$PWD/nginx" ~/nginx

######################
# Networks
######################
ln -sf "$PWD/quadlet/proxy.network" \
    ~/.config/containers/systemd/proxy.network

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

ln -sf "$PWD/quadlet/nginx.container" \
    ~/.config/containers/systemd/nginx.container

ln -sf "$PWD/quadlet/dynacat.container" \
    ~/.config/containers/systemd/dynacat.container

######################
# Reload
######################
systemctl --user daemon-reload
