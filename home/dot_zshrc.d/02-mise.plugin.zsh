# shellcheck shell=bash
[[ $- = *i* ]] || return

source <(mise activate --quiet zsh)

# Handle some base mise stuff required for the rest of the setup
command -v cargo           >/dev/null 2>&1 || mise use -g cargo
command -v cargo-binstall  >/dev/null 2>&1 || mise use -g cargo-binstall
command -v ubi             >/dev/null 2>&1 || mise use -g ubi
command -v uv              >/dev/null 2>&1 || mise use -g uv

# cargo from github needs some help
export CARGO_NET_GIT_FETCH_WITH_CLI=true

# Required (currently) for M1 + XCode Tools 14. Or something.
# In any case, this makes it possible to install ruby again.
# https://github.com/rbenv/ruby-build/discussions/1961
export RUBY_CONFIGURE_OPTS='--enable-shared'

# And also this: https://github.com/ffi/ffi/issues/869
export RUBY_CFLAGS=-DUSE_FFI_CLOSURE_ALLOC

# Generate a zsh completion file for a single command.
#
# Reads two variables from the caller (zsh dynamic scoping):
#   _gc_force   = 1 to bypass mtime + recipe cache
#   _gc_quiet   = 1 to suppress per-tool log output
#
# Caches the winning probe recipe under ~/.zsh_completions/.probe-cache/<cmd>.recipe
# so subsequent runs make at most one subprocess call per tool.
generate_completion() {
  local cmd=${1##*/}                       # strip any `ubi:repo/` prefix
  local quiet=${_gc_quiet:-0}
  _gc_log() { (( quiet )) || print -- "  $cmd: $1"; }

  if ! command -v "$cmd" >/dev/null 2>&1; then
    _gc_log "not on PATH"
    return
  fi

  local bin; bin=$(command -v "$cmd")
  local out=~/.zsh_completions/_${cmd}
  local cache_dir=~/.zsh_completions/.probe-cache
  local recipe=$cache_dir/${cmd}.recipe
  local force=${_gc_force:-0}
  mkdir -p $cache_dir ~/.zsh_completions

  # Fast path: completion file is newer than the binary.
  if (( ! force )) && [[ -s $out && $out -nt $bin ]]; then
    _gc_log "up-to-date"
    return
  fi

  # Cached-recipe path: use the previously-discovered invocation.
  if (( ! force )) && [[ -s $recipe ]]; then
    local args; args=$(<"$recipe")
    if [[ $args == "none" ]]; then
      return
    fi
    if eval "$cmd $args" 2>/dev/null > "${out}.tmp" \
       && head -n1 "${out}.tmp" 2>/dev/null | grep -q '#compdef'; then
      mv "${out}.tmp" "$out"
      _gc_log "cached ($args)"
      return 0
    fi
    rm -f "${out}.tmp"
    # Stale recipe — fall through and re-probe.
  fi

  local probes=(
    'completion zsh'
    'completions zsh'
    'completions'
    '--completion zsh'
    'complete --shell zsh'
    '--generate complete-zsh'
    'generate-shell-completion zsh'
  )

  local p
  for p in "${probes[@]}"; do
    if eval "$cmd $p" 2>/dev/null | head -n1 | grep -q '#compdef'; then
      eval "$cmd $p" 2>/dev/null > "$out"
      print -- "$p" > "$recipe"
      _gc_log "complete ($p)"
      return 0
    fi
  done

  print -- "none" > "$recipe"
  _gc_log "none found"
}

# Generate zsh completions for mise itself and every tool mise manages.
#
# Usage: generate_completions [-f|--force] [-h|--help]
#   -f, --force   Ignore mtime + cached recipes; re-probe every tool.
#   -h, --help    Show this help.
generate_completions() {
  local _gc_force=0 _gc_quiet=0
  local jobs=8

  local -a _flag_force _flag_help
  zparseopts -D -E -- f=_flag_force -force=_flag_force h=_flag_help -help=_flag_help

  if (( ${#_flag_help} )); then
    print -- "Usage: generate_completions [-f|--force] [-h|--help]"
    print -- "  -f, --force  Re-probe all tools, ignoring caches."
    print -- "  -h, --help   Show this help."
    return 0
  fi

  if (( ${#_flag_force} )); then
    _gc_force=1
  fi



  if (( _gc_force )); then
    print -- "regenerating completions (force, jobs=$jobs)"
    rm -rf ~/.zsh_completions/.probe-cache
  else
    print -- "generating completions (jobs=$jobs)"
  fi

  local exclude='^(kubent|iam-policy-json-to-terraform|sopstool|stern|tonnage|viddy)$'

  autoload -Uz zargs

  generate_completion mise

  local -a tools
  local cmd
  while read -r cmd; do
    [[ -n $cmd ]] && tools+=("$cmd")
  done < <(mise ls -c | awk '{print $1}' | grep -vE "$exclude")

  # Run zargs in a subshell so option changes don't touch the interactive shell.
  # - no_monitor: suppresses [N] PID noise from zargs's internal & calls
  # - unsetopt vi: keeps vi out of _zarun's options snapshot (it sets
  #   options=( ${(j: :kv)options[@]} monitor off zle off ) at call time,
  #   and workers can't restore ZLE-dependent options in non-interactive subshells)
  # stdout/stderr are inherited so _gc_log output still reaches the terminal.
  (( ${#tools} )) && (
    setopt no_monitor
    unsetopt vi 2>/dev/null
    zargs -P $jobs -n 1 -- "${tools[@]}" -- generate_completion
  )

  # Rebuild the completion dump only if anything actually changed
  # (or if --force was used, in which case everything was regenerated).
  if (( _gc_force )) \
     || [[ ! -f ~/.zcompdump ]] \
     || [[ -n $(find ~/.zsh_completions -type f -newer ~/.zcompdump -print -quit 2>/dev/null) ]]; then
    zcomet compinit
  fi

}

# vim: set ft=sh ts=2 sw=2 tw=0 :
