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

repos="elementalvoid/dotfiles"
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
