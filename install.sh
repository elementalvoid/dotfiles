#!/bin/bash
set -e

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
sh -c "$(curl -fsLS git.io/chezmoi)" -- -b ~/.local/bin init --ssh --apply --verbose elementalvoid/dotfiles
sh -c "$(curl -fsLS git.io/chezmoi)" -- -b ~/.local/bin init --ssh --apply --verbose --source ~/.local/share/chezmoi-private elementalvoid/dotfiles-private

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
  eval $(/opt/homebrew/bin/brew shellenv) || eval $(/usr/local/bin/brew shellenv)
  brew analytics off
  export HOMEBREW_CASK_OPTS="--appdir=~/Applications"
  ( cd ~/.local/share/chezmoi; brew bundle install )
fi

##
# asdf
##
if [[ -d ~/.asdf ]]; then
  source ~/.asdf/asdf.sh
  asdf update
else
  git clone https://github.com/asdf-vm/asdf.git ~/.asdf
  source ~/.asdf/asdf.sh
fi

set +e
asdf plugin add util git@github.com:elementalvoid/asdf-util.git

for plugin in $(awk '{print $1}' ~/.tool-versions); do
  asdf plugin add ${plugin}
done

asdf util global upgrade
asdf install

##
# Pivot
##
which zsh && exec zsh
