#!/bin/bash
set -ex

mkdir -p ~/.config/containers/systemd/

rm -f ~/.config/containers/systemd/unsloth.container
cp deploy/unsloth.container ~/.config/containers/systemd/

systemctl --user daemon-reload
systemctl --user start unsloth.service

journalctl --user -u unsloth.service -f
