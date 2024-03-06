[[ $- = *i* ]] || return

# source <(mise activate --quiet zsh)

# Required (currently) for M1 + XCode Tools 14. Or something.
# In any case, this makes it possible to install ruby again.
# https://github.com/rbenv/ruby-build/discussions/1961
export RUBY_CONFIGURE_OPTS='--enable-shared'

# And also this: https://github.com/ffi/ffi/issues/869
export RUBY_CFLAGS=-DUSE_FFI_CLOSURE_ALLOC

# activate direnv
eval "$(mise exec direnv@2 -- direnv hook zsh)"

#if [[ -f ~/.asdf/plugins/java/set-java-home.sh ]]; then
#  . ~/.asdf/plugins/java/set-java-home.sh
#fi
# vim: set ft=sh ts=2 sw=2 tw=0 :
