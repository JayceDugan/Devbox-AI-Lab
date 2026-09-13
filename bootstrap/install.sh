#!/bin/bash

#################
#### DOTFILES
#################
echo "Installing dotfiles...";

./dotfiles/install.sh;

#################
#### SYSTEM CONFIGURATION
#################
echo "Configuring System Services...";

./system-configuration/install.sh;

