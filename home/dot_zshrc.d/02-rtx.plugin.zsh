[[ $- = *i* ]] || return

source <(mise activate --quiet zsh)

# Handle some base mise stuff required for the rest of the setup
which cargo 2>&1 >/dev/null || mise use -g cargo
which cargo-binstall 2>&1 >/dev/null || mise use -g cargo-binstall
which ubi 2>&1 >/dev/null || mise use -g ubi
which uv 2>&1 >/dev/null || mise use -g uv

# Required (currently) for M1 + XCode Tools 14. Or something.
# In any case, this makes it possible to install ruby again.
# https://github.com/rbenv/ruby-build/discussions/1961
export RUBY_CONFIGURE_OPTS='--enable-shared'

# And also this: https://github.com/ffi/ffi/issues/869
export RUBY_CFLAGS=-DUSE_FFI_CLOSURE_ALLOC

_generate_completion() {
  local cmd=$1

  if command -v $cmd >/dev/null 2>&1; then
    echo -n "  $cmd: "
    local completion_file=~/.zsh_completions/_${cmd}
    if $cmd completion zsh 2>&1 | grep -q "#compdef"; then
      echo "complete"
      $cmd completion zsh >$completion_file
      return 0
    elif $cmd completions zsh 2>&1 | grep -q "#compdef"; then
      echo "complete"
      $cmd completions zsh >$completion_file
      return 0
    elif $cmd --completion zsh 2>&1 | grep -q "#compdef"; then
      echo "complete"
      $cmd --completion zsh >$completion_file
      return 0
    elif $cmd complete --shell zsh 2>&1 | grep -q "#compdef"; then
      echo "complete"
      $cmd complete --shell zsh >$completion_file
      return 0
    elif $cmd --generate complete-zsh 2>&1 | grep -q "#compdef"; then
      echo "complete"
      $cmd --generate complete-zsh >$completion_file
      return 0
    else
      echo "none found"
    fi
  fi
}

generate_completions() {
  echo "attempting to generate completions"
  local generate_completion_exclude_regex="(kubent|iam-policy-json-to-terraform|sopstool|stern|tonnage|viddy)"
  _generate_completion mise
  for cmd in $(mise ls -c | cut -d' ' -f1 | grep -vE "${generate_completion_exclude_regex}"); do
    _generate_completion $cmd
  done

  zcomet compinit
}

# vim: set ft=sh ts=2 sw=2 tw=0 :
