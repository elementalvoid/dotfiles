[[ $- = *i* ]] || return

export HOMEBREW_CASK_OPTS="--appdir=/Applications"

path=(
  /usr/local/opt/coreutils/libexec/gnubin
  /usr/local/opt/gnu-indent/libexec/gnubin
  /usr/local/opt/gnu-tar/libexec/gnubin
  /usr/local/opt/grep/libexec/gnubin
  /usr/local/opt/gnu-sed/libexec/gnubin
  /usr/local/opt/gawk/libexec/gnubin
  /usr/local/opt/findutils/libexec/gnubin
  $path
)

if [[ -d /usr/local/etc/bash_completion.d ]]; then
  pushd /usr/local/etc/bash_completion.d &> /dev/null
  for f in *; do
    source $f
  done
  popd  &> /dev/null
fi
