[[ $- = *i* ]] || return

export HOMEBREW_CASK_OPTS="--appdir=~/Applications"
path=(
    #$(brew --prefix)/opt/*/libexec/gnubin
    /opt/homebrew/opt/coreutils/libexec/gnubin/
    /opt/homebrew/opt/findutils/libexec/gnubin/
    /opt/homebrew/opt/gawk/libexec/gnubin/
    /opt/homebrew/opt/gnu-indent/libexec/gnubin/
    /opt/homebrew/opt/gnu-sed/libexec/gnubin/
    /opt/homebrew/opt/gnu-tar/libexec/gnubin/
    /opt/homebrew/opt/grep/libexec/gnubin/
    /opt/homebrew/opt/gsed/libexec/gnubin/
    # libtool removed because `bundle install` failed on `grpc` with it
    #/opt/homebrew/opt/libtool/libexec/gnubin/
    /opt/homebrew/opt/make/libexec/gnubin/
    $path
  )
