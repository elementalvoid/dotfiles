[[ $- != *i* ]] && return

# Default fzy flags.
declare -a ZSH_FZY_FLAGS=()

command -v fzy >/dev/null
if [[ $? -ne 0 ]]; then
    echo 'fzy is not installed. See https://github.com/jhawthorn/fzy'
    return 1
fi

__fzy_cmd () {
    fzy ${@} ${ZSH_FZY_FLAGS[@]}
}

# CTRL-T: Place the selected file path in the command line
__fzy_fsel () {
	command find -L . \( -path '*/\.*' -o -fstype dev -o -fstype proc \) -prune \
			-o -type f -print \
			-o -type d -print \
			-o -type l -print 2> /dev/null | sed 1d | cut -b3- | \
		__fzy_cmd -p 'file> ' | while read -r item ; do
		echo -n "${(q)item}"
	done
	echo
}

fzy-file-widget () {
	LBUFFER="${LBUFFER}$(__fzy_fsel)"
	zle redisplay
}
zle     -N   fzy-file-widget
bindkey '^T' fzy-file-widget

# ALT-C: cd into the selected directory
fzy-cd-widget () {
	cd "${$(command find -L . \( -path '*/\.*' -o -fstype dev -o -fstype proc \) -prune \
		-o -type d -print 2> /dev/null | sed 1d | cut -b3- | __fzy_cmd -p 'cd> '):-.}"
	zle reset-prompt
}
zle     -N    fzy-cd-widget
bindkey '\ec' fzy-cd-widget

# CTRL-R: Place the selected command from history in the command line
fzy-history-widget () {
	local selected num query
  if [[ -n ${LBUFFER//$/\\$} ]]; then
    query="-q '${LBUFFER//$/\\$}'"
  fi
	selected=( $(fc -l -r 1 | __fzy_cmd -p 'hist> ' ${query}) )
	if [[ -n ${selected} ]] ; then
		num=${selected[1]}
		if [[ -n ${num} ]] ; then
			zle vi-fetch-history -n ${num}
		fi
	fi
	zle redisplay
}
zle     -N   fzy-history-widget
bindkey '^R' fzy-history-widget
