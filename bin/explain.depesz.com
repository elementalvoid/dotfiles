#!/bin/bash

curl --silent --include --data-urlencode "plan=$(cat -)" http://explain.depesz.com/ | \
  perl -ne 'print if s/\ALocation:\s*(\S+)\s*\z/$1\n/'
