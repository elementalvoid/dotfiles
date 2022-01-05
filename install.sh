#!/bin/bash
set -xe

# Cache github server key
ssh -o StrictHostKeyChecking=no git@github.com || true

# Require private key!
if [[ ! -f ~/.ssh/id_rsa ]]; then
  echo "SSH private key not found. Add before running installer."
  echo "A private key is required to clone GitHub repositories."
  exit 1
fi

##
# Chezmoi
##
sh -c "$(curl -fsLS git.io/chezmoi)" -- -b ~/.local/bin/ init --apply elementalvoid/dotfiles
sh -c "$(curl -fsLS git.io/chezmoi)" -- -b ~/.local/bin/ init --apply elementalvoid/dotfiles-private

##
# Vim
##
if [[ -d ~/.vim ]]; then
  ( cd ~/.vim; git pull )
else
    git clone git@github.com:elementalvoid/vimrc.git ~/.vim
fi
( cd ~/.vim; ./install.sh )

##
# Homebrew
##
if [[ $OSTYPE =~ darwin.* ]]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  export HOMEBREW_CASK_OPTS="--appdir=~/Applications"
  brew bundle install
fi

##
# asdf
##
if [[ -d ~/.asdf ]]; then
  source ~/.asdf/asdf.sh
  asdf update
else
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf
fi

set +e
asdf plugin add util git@github.com:elementalvoid/asdf-util.git

for plugin in $(awk '{print $1}' ~/.tool-versions); do
  asdf plugin add ${plugin}
done

asdf install
