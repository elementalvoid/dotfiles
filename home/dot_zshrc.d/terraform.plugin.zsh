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

function update-terraform-lockfiles() {
  fd providers.tf ${@} -x bash -c '
    echo == {//} ==
    cd {//}
    rm -rf .terraform .terraform.lock.hcl
    terraform get
    terraform providers lock --platform linux_amd64 --platform darwin_amd64 --platform darwin_arm64
  '
}

# vim: set ft=sh ts=2 sw=2 tw=0 :
