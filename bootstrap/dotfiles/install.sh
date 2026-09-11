#!/bin/bash

#################
#### SYMLINKS
#################
symlink_if_not_exists() {
	local symlink_source_path="$1"
	local symlink_destination_path="$2"

	if [ ! -d "$symlink_destination_path" ] && [ ! -L "$symlink_destination_path" ]; then
		echo "Symlinking $symlink_source_path to $symlink_destination_path";
		ln -s $symlink_source_path $symlink_destination_path;
	else
		echo "Symlink or directory already exists at $symlink_destination_path, ignoring.";
	fi
}

symlink_astrovim() {
	symlink_if_not_exists "$(pwd)/nvim/" "$HOME/.config/nvim"
}

symlink_tmux() {
	symlink_if_not_exists "$(pwd)/tmux/" "$HOME/.config/tmux"
}

symlink_astrovim
symlink_tmux
