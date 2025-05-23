[[ $- = *i* ]] || return

# make less more colorful
export LESS="-R"

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"
if [[ $OSTYPE =~ darwin.* ]]; then
  export LESSOPEN="|$(brew --prefix)/bin/lesspipe.sh %s" LESS_ADVANCED_PREPROCESSOR=1
else
  [ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"
fi

# vim: set ft=sh ts=2 sw=2 tw=0 :
