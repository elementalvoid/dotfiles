KUBECTL153='kubectl_154'
KUBECTL184='kubectl_184'
HELM223='helm_223'
HELM272='helm_272'

awk '/cluster: .*shuttercloud.org/ { items[$2] += 1 } END { for (v in items) print v }' ~/.kube/config |
while read ctx; do
  account=$(echo $ctx | awk -F'.' '{ print $3 }')
  name=$(echo $ctx | awk -F'.' '{ print $1 }')

  kubectlbin=''
  helmbin=''

  if [[ $ctx =~ green ]]; then
    if [[ $ctx =~ ops ]]; then
      kubectlbin=$KUBECTL184
      helmbin=$HELM272
    else
      kubectlbin=$KUBECTL153
      helmbin=$HELM223
    fi
  elif [[ $ctx =~ blue ]]; then
    if [[ $ctx =~ ops ]]; then
      kubectlbin=$KUBECTL153
      helmbin=$HELM223
    else
      kubectlbin=$KUBECTL184
      helmbin=$HELM272
    fi
  fi

  eval "alias k$account-$name='$kubectlbin --context $ctx'"
  eval "alias krun$account-$name='$kubectlbin --context $ctx run -it --rm --image elementalvoid/net-tools mkfoo -- /bin/bash'"
  eval "alias h$account-$name='$helmbin --kube-context $ctx'"
done

# Generate and/or source the completions
for bin in $HELM223 $HELM272; do
  command -v $bin &> /dev/null || continue
  if [[ ! -f ~/.kube/completion_$bin.zsh ]]; then
    $bin completion zsh | sed -e "s/helm/$bin/g" > ~/.kube/completion_$bin.zsh
  fi
  source ~/.kube/completion_$bin.zsh
done

for bin in $KUBECTL153 $KUBECTL184; do
  command -v $bin &> /dev/null || continue
  if [[ ! -f ~/.kube/completion_$bin.zsh ]]; then
    $bin completion zsh | sed -e "s/kubectl/$bin/g" > ~/.kube/completion_$bin.zsh
  fi
  source ~/.kube/completion_$bin.zsh
done

# Now handle bare kubectl and helm commands specially
for bin in kubectl helm; do
  if command -v $bin &> /dev/null; then
    version=$($bin version --client --short | awk '{print $NF}')
    if [[ ! -f ~/.kube/completion_kubectl_$version.zsh ]]; then
      $bin completion zsh > ~/.kube/completion_$bin_$version.zsh
    fi
    source ~/.kube/completion_$bin_$version.zsh
  fi
done
