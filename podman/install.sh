#!/bin/bash
set -uex

mkdir -p ~/.config/containers/systemd


ln -sf "$PWD/quadlet/unsloth.container" \
    ~/.config/containers/systemd/unsloth.container

ln -sf "$PWD/quadlet/beszel.container" \
    ~/.config/containers/systemd/beszel.container

ln -sf "$PWD/quadlet/beszel-agent.container" \
    ~/.config/containers/systemd/beszel-agent.container

systemctl --user daemon-reload
