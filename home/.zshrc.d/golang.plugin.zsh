#export GOROOT=~/.local/go
export GOPATH=~/code/go

path=(
#  ${GOROOT}/bin
  ${GOPATH}/bin
  $path
)
