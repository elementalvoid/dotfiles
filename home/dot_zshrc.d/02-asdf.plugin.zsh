[[ $- = *i* ]] || return

# Find where asdf should be installed
ASDF_DIR="${ASDF_DIR:-$HOME/.asdf}"

# Load command
if [[ -f "$ASDF_DIR/asdf.sh" ]]; then
    . "$ASDF_DIR/asdf.sh"

    # Load completions
    #if [[ -f "$ASDF_COMPLETIONS/asdf.bash" ]]; then
    #    . "$ASDF_COMPLETIONS/asdf.bash"
    #fi
fi

# Required (currently) for M1 + XCode Tools 14. Or something.
# In any case, this makes it possible to install ruby again.
# https://github.com/rbenv/ruby-build/discussions/1961
export RUBY_CONFIGURE_OPTS='--enable-shared'

#if [[ -f ~/.asdf/plugins/java/set-java-home.sh ]]; then
#  . ~/.asdf/plugins/java/set-java-home.sh
#fi
# vim: set ft=sh ts=2 sw=2 tw=0 :
