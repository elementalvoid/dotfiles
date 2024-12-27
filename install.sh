#!/bin/bash
set -e

# Cache github server key
ssh -o StrictHostKeyChecking=no git@github.com || true

# Require private key!
if [[ ! (-f ~/.ssh/id_rsa || -f ~/.ssh/id_ed25519) ]]; then
  echo "SSH private key not found. Add before running installer."
  echo "A private key is required to clone GitHub repositories."
  exit 1
fi

##
# Chezmoi -- in /tmp because asdf will later manage the real install
##
sh -c "$(curl -fsLS git.io/chezmoi)" -- -b /tmp/ init --ssh --apply --refresh-externals --verbose elementalvoid/dotfiles
sh -c "$(curl -fsLS git.io/chezmoi)" -- -b /tmp/ init --ssh --apply --refresh-externals --verbose --source ~/.local/share/chezmoi-private elementalvoid/dotfiles-private

##
# Homebrew -- before asdf for deps
##
if [[ $OSTYPE =~ darwin.* ]]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval $(/opt/homebrew/bin/brew shellenv) || eval $(/usr/local/bin/brew shellenv)
  brew analytics off
  export HOMEBREW_CASK_OPTS="--appdir=~/Applications"
  ( cd ~/.local/share/chezmoi; brew bundle install )
else
  sudo apt update
  sudo apt install --yes git findutils gawk rsync thefuck watch wget zsh build-essential zlib1g-dev libssl-dev libbz2-dev libffi-dev libreadline-dev libncurses-dev zip unzip file
fi

##
# Pivot
##
which zsh && exec zsh
