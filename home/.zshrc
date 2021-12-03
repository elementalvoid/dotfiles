# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Optional binary module
if [[ -f "$HOME/.zinit/bin/zmodules/Src/zdharma/zplugin.so" ]]; then
	module_path+=( "$HOME/.zinit/bin/zmodules/Src" )
	zmodload zdharma/zplugin
fi

unsetopt beep

# vi keybindings
bindkey -v

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
  for hd in $(find ~/.homesick/repos -maxdepth 2 -type d -name bin); do
    path+=($hd)
  done
  unset hd

  # source homeshick function since ^^ that pulls in it's bin dir
  source ~/.homesick/repos/homeshick/homeshick.sh
fi

# STUFF
# STUFF
# STUFF

### Added by Zinit's installer
if [[ ! -f $HOME/.zinit/bin/zinit.zsh ]]; then
    print -P "%F{33}▓▒░ %F{220}Installing %F{33}DHARMA%F{220} Initiative Plugin Manager (%F{33}zdharma/zinit%F{220})…%f"
    command mkdir -p "$HOME/.zinit" && command chmod g-rwX "$HOME/.zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.zinit/bin" && \
        print -P "%F{33}▓▒░ %F{34}Installation successful.%f%b" || \
        print -P "%F{160}▓▒░ The clone has failed.%f%b"
fi

source "$HOME/.zinit/bin/zinit.zsh"
autoload -Uz _zinit
autoload bashcompinit && bashcompinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
#zinit light-mode for \
#    zinit-zsh/z-a-patch-dl \
#    zinit-zsh/z-a-as-monitor

zinit ice depth=1 atload'source ~/.p10k.zsh; _p9k_precmd' nocd
zinit load romkatv/powerlevel10k

export ENHANCD_FILTER='peco'
export ENHANCD_DISABLE_HOME=1
alias gcd='cd-gitroot'
zinit pack for ls_colors
zinit light-mode wait lucid depth=1 for \
  mollifier/cd-gitroot \
  atinit atpull'zinit cclear' \
    b4b4r07/enhancd \
  jimeh/zsh-peco-history \
  as"completion" \
    https://raw.githubusercontent.com/asdf-vm/asdf/master/completions/_asdf \
  atinit"ZINIT[COMPINIT_OPTS]=-C; zicompinit; zicdreplay" \
    zdharma-continuum/fast-syntax-highlighting \
  as"completion" \
    https://raw.githubusercontent.com/rbirnie/oh-my-zsh-keybase/master/keybase/_keybase \
  atload'bindkey -M vicmd "k" history-substring-search-up; bindkey -M vicmd "j" history-substring-search-down' \
    zsh-users/zsh-history-substring-search \
  from'gh-r' as'program' mv'peco_*/peco -> peco' \
    peco/peco \
  blockf multisrc'*.plugin.zsh' pick'/dev/null' \
    ~/.zshrc.d \
  as"completion" atpull'zinit creinstall .'\
    elementalvoid/dotfiles

# Couldn't get this to work reliably above ..
zinit ice light-mode wait lucid depth=1 blockf as'completion' cp'etc/hub.zsh_completion -> etc/_hub'
zinit load github/hub

# Bunch'o'completions
# Recommended to be loaded last.
zinit wait lucid atload"zicompinit; zicdreplay" blockf for \
      zsh-users/zsh-completions

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
(( ! ${+functions[p10k]} )) || p10k finalize
