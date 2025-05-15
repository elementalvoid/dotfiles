[[ $- = *i* ]] || return

if command -v pipx &> /dev/null; then
  eval "$(register-python-argcomplete pipx)"
fi
