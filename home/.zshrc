# Profiling!!
#zmodload zsh/zprof

# Lines configured by zsh-newuser-install
unsetopt beep

# vi keybindings
bindkey -v
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/mklich/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

# maybe works?
autoload -Uz bashcompinit
bashcompinit

# STUFF
# STUFF
# STUFF

# Esc-. inserts last word from previous commands
bindkey '\e.' insert-last-word

export EDITOR='vim'
export VISUAL='vim'

export LESS="R"

alias ls='ls --color=auto'
alias ll='ls -l'

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path

path=(
  $HOME/bin
  $HOME/{.local,.cargo}/bin
  /usr/local/{bin,sbin}
  /usr/sbin
  $path
)

fpath=(
  $HOME/.zsh-fpath.d
  $fpath
)

if [[ -d ~/.homesick/repos/homeshick ]]; then
  # we have homeshick installed, use it
  #source $HOME/.homesick/repos/homeshick/homeshick.sh
  # now add all of the repos bin folders to our path
  for hd in $(find ~/.homesick/repos/ -maxdepth 1 -type d); do
    if [[ -d $hd/bin ]]; then
      path=(
        $path
        $hd/bin
      )
    fi
  done
  unset hd
fi

# STUFF
# STUFF
# STUFF

source ~/.zplug/init.zsh

# Depends on one of my dotfile "plugins"
[[ -f ~/.dircolors ]] && eval $(dircolors ~/.dircolors)

# added by travis gem
[ -f /Users/matt.klich/.travis/travis.sh ] && source /Users/matt.klich/.travis/travis.sh

# Profiling!!
#zprof
