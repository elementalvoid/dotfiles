[[ $- = *i* ]] || return

docker () {
    local cmd=$(command -v docker-${1});
    if [[ -n ${cmd} ]]; then
        shift;
        ${cmd} ${@};
    else
        #command -p docker -- ${@};
        command docker ${@};
    fi
}
# vim: set ft=sh ts=2 sw=2 tw=0 :
