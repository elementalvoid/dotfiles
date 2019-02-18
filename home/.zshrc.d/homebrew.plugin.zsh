[[ $- = *i* ]] || return

export HOMEBREW_CASK_OPTS="--appdir=/Applications"

path=(
  /usr/local/opt/*/libexec/gnubin
  $path
)

if [[ -d /usr/local/etc/bash_completion.d ]]; then
  pushd /usr/local/etc/bash_completion.d &> /dev/null
  for f in *; do
    source $f
  done
  popd  &> /dev/null
fi
