# Only set some things when running interactively
if [[ -n "$PS1" ]]; then
  # check the window size after each command and, if necessary,
  # update the values of LINES and COLUMNS.
  shopt -s checkwinsize

  # chech that binary from hash lookup exists before attempting to execute it
  # then search the PATH if it does not
  shopt -s checkhash

  # set variable identifying the chroot you work in (used in the prompt below)
  if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
      debian_chroot=$(cat /etc/debian_chroot)
  fi

  # enable color support of ls and also add handy aliases
  if [ -x /usr/bin/dircolors ]; then
      test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
  fi

  if [ -f ~/.bash_aliases ]; then
      . ~/.bash_aliases
  fi

  if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
      . /etc/bash_completion
  fi
  if [ -f ~/.bash_completion ] && ! shopt -oq posix; then
      . ~/.bash_completion
  fi

  # STTY doesn't like being sourced
  # fucking control characters
  stty -echoctl
  # fucking flow control
  stty -ixon
fi

if [[ -d ${HOME}/.bashrc.d ]]; then
  while read dotd; do
    source "${dotd}"
  done < <(find ${HOME}/.bashrc.d -follow -type f -not -name '*.disabled')
  unset dotd
fi

# vim: set ft=sh ts=2 sw=2 tw=0 :
