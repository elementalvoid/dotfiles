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

#if [[ -f ~/.asdf/plugins/java/set-java-home.sh ]]; then
#  . ~/.asdf/plugins/java/set-java-home.sh
#fi
# vim: set ft=sh ts=2 sw=2 tw=0 :
