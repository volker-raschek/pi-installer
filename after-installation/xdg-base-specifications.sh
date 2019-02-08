#!/bin/bash

# XDG: create directories
mkdir ${HOME}/.cache \
      ${HOME}/.config \
      ${HOME}/.local/share -p

# XDG: set environment variables
cat >> ${HOME}/.bashrc <<EOF

# XDG Base Directory
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_DATA_HOME="${HOME}/.local/share"
EOF

# XDG: source new environment variables
source ${HOME}/.bashrc