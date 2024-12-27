[[ $- = *i* ]] || return

# vi keybindings
setopt vi
# allow vv to edit the command line
autoload -Uz edit-command-line
zle -N edit-command-line
zstyle :zle:edit-command-line editor nvim
bindkey -M vicmd 'vv' edit-command-line

unsetopt beep

# stolen from: https://github.com/willghatch/zsh-saneopt
# no c-s/c-q output freezing
setopt noflowcontrol
# allow expansion in prompts
setopt prompt_subst
# whenever a command completion is attempted, make sure the entire command path
# is hashed first.
setopt hash_list_all
# not just at the end
setopt completeinword
# use zsh style word splitting
setopt noshwordsplit
# allow use of comments in interactive code
setopt interactivecomments
# end stealing

# Esc-<.> inserts last word from previous commands
bindkey '\e.' insert-last-word

export EDITOR='nvim'
export VISUAL='nvim'

export LESS="-R"
# alias less='bat --theme OneHalfLight --paging always --wrap never'
alias less='bat --paging always --wrap never'
alias yaml='less -l yaml'

# bat is cat
# alias cat='bat --theme OneHalfLight --paging=never --wrap=never'
alias cat='bat --paging=never --wrap=never'

# use `bat` as man viewer
export MANPAGER="sh -c 'col -bx | bat --paging always -l man -p'"

# use `bat` as "help" formatter
alias -g -- --help='--help 2>&1 | bat --language=help --style=plain'
help() {
    "$@" --help 2>&1 | bat --plain --language=help
}

# use `bat` to preview files when using `fzf` Ctrl-T
export FZF_CTRL_T_OPTS="
  --walker-skip .git,node_modules,target
  --preview 'bat -n --color=always {}'
  --bind 'ctrl-/:change-preview-window(down|hidden|)'"

# Allow approximation when completing
#zstyle ':completion:::::' completer _complete _approximate
#zstyle ':completion:*:approximate:*' max-errors 2

