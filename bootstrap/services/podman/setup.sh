#!/bin/bash

# Setup Podman Rootless mode
#
# @see https://man.archlinux.org/man/podman.1#Rootless_mode
#
USERNAME=$(whoami)

echo "Attempting to add subordinate uids and gids 10000-75535 to user '$USERNAME'"; 

sudo usermod --add-subuids 10000-75535 $USERNAME
sudo usermod --add-subgids 10000-75535 $USERNAME

echo "Added subordinate uids 10000-75535 to user '$USERNAME'"; 
echo "Added subordinate group ids 10000-75535 to user '$USERNAME'"; 

