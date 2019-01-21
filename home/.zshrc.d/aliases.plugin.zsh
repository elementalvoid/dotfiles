[[ $- = *i* ]] || return

alias history='history -iD'

# ls
alias ls='ls --color=auto'
alias ll='ls -l'
alias la='ls -A'

# Misc
alias vi='vim'
alias grep='grep --color=auto'
alias d='stat -c "%A (%a) %8s %.19y %n" ' # usage: d <filename>
alias apt-get='sudo /usr/bin/apt-get $@'
alias color='pygmentize -O style=monokai -f console256 -g'
alias sslyze="/usr/local/bin/sslyze --regular --hsts --chrome_sha1"
alias sbash='sudo -E bash'
alias bd='. bd -si'

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
# vim: set ft=sh ts=2 sw=2 tw=0 :
