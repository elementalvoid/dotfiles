[[ $- = *i* ]] || return

alias history='history -iD'

# ls
alias ls='exa -F'
alias ll='ls -l'
alias la='ls -a'
alias lt='ls -T'
alias llt='ll -T'

# Misc
alias vi='nvim'
alias grep='grep --color=auto'
alias d='stat -c "%A (%a) %8s %.19y %n" ' # usage: d <filename>
alias apt-get='sudo /usr/bin/apt-get $@'
alias color='pygmentize -O style=monokai -f console256 -g'
alias sbash='sudo -E bash'

# dotfiles management
alias chezmoi-private='chezmoi --source ~/.local/share/chezmoi-private'

# kubernetes
alias kfoo='kubectl run --image elementalvoid/net-tools:latest --stdin --tty --restart=Never --rm mkfoo'

# Python HTTP server
alias pyhttp="python -m SimpleHTTPServer 10412"

# Directories
code=~/code

# Code
alias ccode='cd $code'
alias cgo='cd $code/go'
alias cgithub='cd $code/github'
alias cibotta='cd $code/ibotta'

alias cvim='cd ~/.vim'
alias cdownloads='cd ~/Downloads'
alias ctmp='cd ~/tmp'

# the standard 16x9 feh
alias f="command feh --borderless --zoom auto --geometry 1366x768"

# the standard 16x9 remote desktop with clipboard
alias rdesktop="command rdesktop -r clipboard:PRIMARYCLIPBOARD -g 1366x768"

if command -v hub &> /dev/null; then
  alias git=hub
fi

alias urldecode='python3 -c "import sys, urllib.parse as ul; print(ul.unquote_plus(sys.argv[1]))"'
alias urlencode='python3 -c "import sys, urllib.parse as ul; print (ul.quote_plus(sys.argv[1]))"'

# vim: set ft=sh ts=2 sw=2 tw=0 :
