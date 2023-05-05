[[ $- = *i* ]] || return

complete -C terraform terraform

function tfgen() {
  local tfdir=$(basename $(pwd))
  echo "${tfdir}: Installing Terraform..."
  asdf install terraform
  echo "${tfdir}: Formatting..."
  terraform fmt .

  echo "${tfdir}: Installing Terraform Docs..."
  asdf install terraform-docs
  echo "${tfdir}: Generating docs..."
  terraform-docs . > README.md
}

function tfgen-all() {
  for i in *; do
    (cd $i; tfgen)
  done
}

# vim: set ft=sh ts=2 sw=2 tw=0 :
