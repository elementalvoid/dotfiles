[[ $- = *i* ]] || return

if [[ -n $(command -v brew) ]]; then
  export HOMEBREW_CASK_OPTS="--appdir=~/Applications"

  path+=(/usr/local/opt/*/libexec/gnubin)
fi
