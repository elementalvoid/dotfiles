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
# Homeshick
##
if [[ ! -d ~/.homesick/repos/homeshick ]]; then
  git clone git@github.com:andsens/homeshick.git ~/.homesick/repos/homeshick
else
  ( cd ~/.homesick/repos/homeshick; git pull )
fi
type homeshick &> /dev/null || source ~/.homesick/repos/homeshick/homeshick.sh

repos="git@github.com:elementalvoid/dotfiles git@github.com:elementalvoid/dotfiles-private"
for repo in ${repos}; do
  if homeshick list | grep -q ${repo}; then
    homeshick --batch pull ${repo/*\//}
  else
    homeshick --batch clone ${repo}
  fi
done
homeshick --force link

##
# Vim
##
if [[ -d ~/.vim ]]; then
  ( cd ~/.vim; git pull )
else
    git clone git@github.com:elementalvoid/vimrc.git ~/.vim
fi
( cd ~/.vim; ./install.sh )
