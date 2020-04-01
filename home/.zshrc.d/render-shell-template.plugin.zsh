[[ $- = *i* ]] || return

function render-shell-template-file () {
    # Interpret template as a bash heredoc, implicitly expanding variables
    command=$(echo -e "cat <<COMMANDTEMPLATE
$(< "${1}")
COMMANDTEMPLATE
    ")

    eval "${command}"
}

function render-shell-template () {
    render-shell-template-file <(echo "${@}")
