#!/bin/bash

# SWT is busted
export GDK_NATIVE_WINDOWS=true

#don't use this here, it's just informational
#exec /usr/bin/awesome >> ~/.cache/awesome/stdout 2>> ~/.cache/awesome/stderr

setxkbmap -option terminate:ctrl_alt_bksp

#xrdb -merge ~/.Xdefaults
