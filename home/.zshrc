# Optional binary module
if [[ -f "$HOME/.zinit/bin/zmodules/Src/zdharma/zplugin.so" ]]; then
	module_path+=( "$HOME/.zinit/bin/zmodules/Src" )
	zmodload zdharma/zplugin
fi

# Lines configured by zsh-newuser-install
unsetopt beep

# vi keybindings
bindkey -v
# End of lines configured by zsh-newuser-install

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


# Prompt
zinit ice depth=1 atload'source ~/.p10k.zsh; _p9k_precmd' nocd
zinit load romkatv/powerlevel10k

export ENHANCD_FILTER='peco'
export ENHANCD_DISABLE_HOME=1
alias gcd='cd-gitroot'
zinit wait lucid depth=1 for \
    mollifier/cd-gitroot \
    bobsoppe/zsh-ssh-agent \
  atinit atpull'zinit cclear' \
    b4b4r07/enhancd \
    jimeh/zsh-peco-history \
    eastokes/aws-plugin-zsh \
    OMZ::plugins/asdf/asdf.plugin.zsh \
    zdharma/fast-syntax-highlighting \
  as"completion" \
    https://raw.githubusercontent.com/rbirnie/oh-my-zsh-keybase/master/keybase/_keybase \
  as"completion" \
    OMZ::plugins/docker/_docker \
  atload'bindkey -M vicmd "k" history-substring-search-up; bindkey -M vicmd "j" history-substring-search-down' \
    zsh-users/zsh-history-substring-search \
  from'gh-r' as'program' mv'peco_*/peco -> peco' \
    peco/peco \
  blockf multisrc'*.plugin.zsh' pick'/dev/null' \
    ~/.zshrc.d \
  as"completion" atpull'zinit creinstall .'\
    elementalvoid/dotfiles

# Couldn't get this to work reliably above ..
zinit ice wait lucid depth=1 blockf as'completion' cp'etc/hub.zsh_completion -> etc/_hub'
zinit load github/hub

# Bunch'o'completions
# Recommended to be loaded last.
zinit ice wait blockf lucid atpull'zinit creinstall -q .'
zinit load zsh-users/zsh-completions

zinit cdreplay -q
