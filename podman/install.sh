mkdir -p ~/.config/containers/systemd

ln -sf "$PWD/quadlet/unsloth.container" \
    ~/.config/containers/systemd/unsloth.container

systemctl --user daemon-reload
