[[ $- = *i* ]] || return

if command -v thefuck &> /dev/null; then
  eval $(thefuck --alias)
fi
# vim: set ft=sh ts=2 sw=2 tw=0 :
