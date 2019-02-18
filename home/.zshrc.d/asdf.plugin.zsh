[[ $- = *i* ]] || return

asdf_location=~/.asdf/
if [[ -d ${asdf_location} ]]; then
  source ${asdf_location}/asdf.sh
  source ${asdf_location}/completions/asdf.bash
fi
unset asdf_location
# vim: set ft=sh ts=2 sw=2 tw=0 :
