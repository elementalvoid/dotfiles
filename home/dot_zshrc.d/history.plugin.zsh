HISTFILE=~/.histfile
HISTSIZE=10000
SAVEHIST=10000
HISTDUP=erase

alias history-reload="fc -RI"

# History sharing -- these are all mutually exclusive
# setopt inc_append_history        # Write to the history file immediately, not when the shell exits.
setopt inc_append_history_time   # Write to the history file immediately upon command completion, not when the shell exits.
#setopt share_history             # Share history between all sessions.

#setopt bang_hist                 # Treat the '!' character specially during expansion.
setopt extended_history          # Write the history file in the ":start:elapsed;command" format.
setopt hist_expire_dups_first    # Expire duplicate entries first when trimming history.
setopt hist_ignore_dups          # Don't record an entry that was just recorded again.
setopt hist_ignore_all_dups      # Delete old recorded entry if new entry is a duplicate.
setopt hist_find_no_dups         # Do not display a line previously found.
setopt hist_ignore_space         # Don't record an entry starting with a space.
setopt hist_save_no_dups         # Don't write duplicate entries in the history file.
setopt hist_reduce_blanks        # Remove superfluous blanks before recording entry.
setopt hist_verify               # Don't execute immediately upon history expansion.

export FZF_CTRL_R_OPTS="
  --preview 'echo {}' --preview-window down:3:wrap
  --bind 'ctrl-/:toggle-preview'
  --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
  --color header:italic
  --header 'Press CTRL-Y to copy command into clipboard'"
