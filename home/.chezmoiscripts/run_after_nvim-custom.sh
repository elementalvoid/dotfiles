#!/bin/bash
if [ -d ~/.config/nvim ] && [ -d ~/.config/nvim-custom ]; then
  if [ ! -d ~/.config/nvim/lua/custom ]; then
    echo "Configuring nvim-custom"
    ln -s ~/.config/nvim-custom/lua/custom ~/.config/nvim/lua/custom
  fi
fi
