[[ $- = *i* ]] || return

if [[ -n $(command -pv brew) ]]; then
  export HOMEBREW_CASK_OPTS="--appdir=~/Applications"

  path=(
    /usr/local/opt/*/libexec/gnubin
    $path
  )
fi
