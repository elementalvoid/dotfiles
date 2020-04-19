#module_path+=( "/Users/matt.klich/.zinit/bin/zmodules/Src" )
#zmodload zdharma/zplugin

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

# bash completion support
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

# Ensure path arrays do not contain duplicates.
typeset -gU cdpath fpath mailpath path

path=(
  .
  $HOME/bin
  $HOME/{.local,.cargo,code/go}/bin
  $HOME/.krew/bin
  /usr/local/{bin,sbin}
  /usr/local/opt/mysql-client/bin
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

# Depends on one of my dotfile "plugins"
#[[ -f ~/.dircolors ]] && eval $(dircolors ~/.dircolors)

### Added by Zinit's installer
if [[ ! -f $HOME/.zinit/bin/zinit.zsh ]]; then
    print -P "%F{33}▓▒░ %F{220}Installing %F{33}DHARMA%F{220} Initiative Plugin Manager (%F{33}zdharma/zinit%F{220})…%f"
    command mkdir -p "$HOME/.zinit" && command chmod g-rwX "$HOME/.zinit"
    command git clone https://github.com/zdharma/zinit "$HOME/.zinit/bin" && \
        print -P "%F{33}▓▒░ %F{34}Installation successful.%f%b" || \
        print -P "%F{160}▓▒░ The clone has failed.%f%b"
fi

source "$HOME/.zinit/bin/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
#zinit light-mode for \
#    zinit-zsh/z-a-patch-dl \
#    zinit-zsh/z-a-as-monitor

### End of Zinit's installer chunk

zinit ice lucid wait'!0'
zinit light mollifier/cd-gitroot
alias gcd='cd-gitroot'

# a tad silly but this is only cloned in order to use the completion file
zinit ice lucid wait'!0'
zinit ice cp'etc/hub.zsh_completion -> etc/_hub'
zinit light github/hub
zinit add-fpath github/hub etc/

# a tad silly but this is only cloned in order to use the completion file
zinit ice lucid wait'!0'
zinit ice cp'contrib/completions.zsh -> contrib/_exa'
zinit light ogham/exa
zinit add-fpath ogham/exa contrib

zinit ice lucid wait'!0'
zinit light bobsoppe/zsh-ssh-agent

# Bunch'o'completions
zinit ice lucid wait'!0'
zinit ice blockf
zinit light zsh-users/zsh-completions

zinit ice lucid wait'!0' atinit'ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay'
zinit light zdharma/fast-syntax-highlighting

zinit ice lucid wait'!0' atload'bindkey -M vicmd "k" history-substring-search-up; bindkey -M vicmd "j" history-substring-search-down'
zinit light zsh-users/zsh-history-substring-search
#bindkey '^[[A' history-substring-search-up
#bindkey '^[[B' history-substring-search-down

zinit ice lucid wait'!0'
zinit ice from'gh-r' as'program' mv'peco_*/peco -> peco'
zinit load peco/peco

export ENHANCD_FILTER='peco'
export ENHANCD_DISABLE_HOME=1
zinit ice lucid wait'!0'
zinit light b4b4r07/enhancd

zinit ice lucid wait'!0'
zinit light jimeh/zsh-peco-history

# Prompt
zinit ice depth=1
zinit light romkatv/powerlevel10k
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# local stuff
zinit ice lucid wait'!0'
zinit ice multisrc'*.plugin.zsh' pick'/dev/null'
zinit light ~/.zshrc.d
