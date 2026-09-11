#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

alias vi="nvim"
export EDITOR="nvim"
export VISUAL="nvim"
export MANPAGER='less --use-color -Dd+r -Du+b'

# Added by Hugging Face CLI installer
export PATH="/home/jayce/.local/bin:$PATH"

# Store HF models in BTRFS subvolume 
export HF_HOME="/srv/models"
