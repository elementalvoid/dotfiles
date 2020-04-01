#!/bin/bash
set -xe

## ZPlug
if [[ ! -d ~/.zplug ]]; then
  git clone https://github.com/zplug/zplug.git ~/.zplug
else
  ( cd ~/.zplug; git pull )
fi

##
# Homeshick
##
if [[ ! -d ~/.homesick/repos/homeshick ]]; then
  git clone https://github.com/andsens/homeshick.git ~/.homesick/repos/homeshick
else
  ( cd ~/.homesick/repos/homeshick; git pull )
fi
type homeshick &> /dev/null || source ~/.homesick/repos/homeshick/homeshick.sh

repos="elementalvoid/dotfiles elementalvoid/dotfiles-private elementalvoid/liquidprompt junegunn/fzf"
for repo in ${repos}; do
  if homeshick list | grep -q ${repo}; then
    homeshick --batch pull ${repo/*\//}
  else
    homeshick --batch clone ${repo}
  fi
done
homeshick --force link

##
# fzf
##
~/.homesick/repos/fzf/install --bin

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

##
# Install sslyze
##
source ~/.bashrc.d/sslyze
