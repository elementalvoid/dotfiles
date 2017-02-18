#!/bin/bash

xrdb -merge ~/.Xresources
xmodmap ~/.Xmodmap
#synclient HorizTwoFingerScroll=1 VertEdgeScroll=0 PalmDetect=1 TapButton3=2 LockedDrags=1 VertScrollDelta=-114 HorizScrollDelta=-114 AreaBottomEdge=4000
synclient HorizTwoFingerScroll=1 VertEdgeScroll=0 TapButton3=2 VertScrollDelta=-114 HorizScrollDelta=-114 MaxTapTime=0
#syndaemon -d -i 0.5 -t -K -R
