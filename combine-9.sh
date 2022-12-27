#!/bin/bash

[ -p file3.txt.wl ] && rm file3.txt.wl

trap "[ -p file3.txt.wl ] && rm file3.txt.wl && exit" SIGINT

while [  true ]; do
  mkfifo file3.txt.wl
  echo "Serving File"
  echo $(git cat-file -p 9eb4c0c897d21ac7db39a5d1a25bbeacf51c3ad4)$'\n'$(git cat-file -p ed1f67e477de14798295ed6091452354196e261d) > file3.txt.wl
#git object cat insp from https://stackoverflow.com/a/56870314/5623661
#echo newline insp from https://stackoverflow.com/a/8467448/5623661
  rm file3.txt.wl
done
#insp from https://superuser.com/a/763200/1619518 <3

#task: comment in https://superuser.com/a/763200/1619518 about mkfifo getting from files only at read, and not contantly on RAM
