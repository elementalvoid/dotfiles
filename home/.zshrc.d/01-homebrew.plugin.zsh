[[ $- = *i* ]] || return

export HOMEBREW_CASK_OPTS="--appdir=~/Applications"

path=(
  /usr/local/opt/*/libexec/gnubin
  $path
)
