##
# zplug config
##
zplug 'zplug/zplug', hook-build:'zplug --self-manage'

zplug "mollifier/cd-gitroot"
alias gcd="cd-gitroot"

zplug "github/hub", \
  hook-build:"mkdir -p zplug-autoload && \
              cp etc/hub.zsh_completion zplug-autoload/_hub && \
              fpath=($ZPLUG_REPOS/github/hub/zplug-autoload/ $fpath) && \
              autoload -U compinit && \
              compinit", \
  use:"zplug-autoload"

zplug "bobsoppe/zsh-ssh-agent", use:ssh-agent.zsh, from:github
zplug "zsh-users/zsh-completions"
zplug "zdharma/fast-syntax-highlighting" # should be before zsh-history-substring-search
zplug "plugins/cargo", from:oh-my-zsh

# Enhanced CD -- depends on fzy or peco or .....
export ENHANCD_FILTER="peco:fzy"
zplug "b4b4r07/enhancd", use:init.sh
zplug "peco/peco", \
  as:command, \
  rename-to:peco, \
  hook-build:"go build -o peco cmd/peco/peco.go"
zplug "jhawthorn/fzy", \
  as:command, \
  rename-to:fzy, \
  hook-build:"make"

# Prompt line
zplug mafredri/zsh-async, from:github
zplug sindresorhus/pure, use:pure.zsh, from:github, as:theme

# Now all my local stuff
zplug "~/.zshrc.d", from:local, use:"*.zsh", defer:2

# kubectl -- deferred after the dot.d dir since it changes the $path var
# and that swaps the `stat` command used by the kube prompt
zplug superbrothers/zsh-kubectl-prompt, from:github, defer:3
export RPROMPT='%{$fg[$color]%}($ZSH_KUBECTL_PROMPT)%{$reset_color%}'


# Install plugins if there are plugins that have not been installed
if ! zplug check --verbose; then
    printf "Install? [y/N]: "
    if read -q; then
        echo; zplug install
    fi
fi

# Then, source plugins and add commands to $PATH
zplug load
