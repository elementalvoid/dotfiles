[[ $- = *i* ]] || return

export HOMEBREW_CASK_OPTS="--appdir=~/Applications"
path=(
    $(brew --prefix)/opt/*/libexec/gnubin
    $path
  )
