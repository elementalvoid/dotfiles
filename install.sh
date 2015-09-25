#!/bin/bash
set -xe

##
# Homeshick
##
if [[ ! -d $HOME/.homesick/repos/homeshick ]]; then
  git clone https://github.com/andsens/homeshick.git $HOME/.homesick/repos/homeshick
else
  ( cd $HOME/.homesick/repos/homeshick; git pull )
fi
type homeshick &> /dev/null || source $HOME/.homesick/repos/homeshick/homeshick.sh

repos="elementalvoid/dotfiles elementalvoid/liquidprompt"
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
    ssh -o StrictHostKeyChecking=no git@github.com || true
    git clone https://github.com/elementalvoid/vimrc.git ~/.vim
fi
( cd ~/.vim; ./install.sh )

if [[ -n ${SSH_CLIENT} ]]; then
  echo "Skipping powerline fonts installation on remote host (ssh)..."
elif command -pv fc-cache > /dev/null 2>&1; then
  if [[ -d ~/.fonts-powerline ]]; then
    ( cd ~/.fonts-powerline; git pull; ./install.sh )
  else
    git clone https://github.com/Lokaltog/powerline-fonts.git ~/.fonts-powerline
    ( cd ~/.fonts-powerline; ./install.sh )
  fi
else
  echo "Skipping powerline fonts installation (missing fc-cache)..."
fi

##
# Install sslyze
##
source ~/.bashrc.d/sslyze
