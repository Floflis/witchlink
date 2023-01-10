#!/bin/bash -e

file_fullname="file3.txt"
file_name="${file_fullname%.*}"
#from https://stackoverflow.com/a/965072/5623661
file_ext="${file_fullname##*.}"

[ -p $file_name.$file_ext.wl ] && rm $file_name.$file_ext.wl && rm $file_name.$file_ext

trap "[ -p $file_name.$file_ext.wl ] && rm $file_name.$file_ext.wl && rm $file_name.$file_ext && exit" SIGINT

while [  true ]; do
  touch $file_name.$file_ext
  mkfifo $file_name.$file_ext.wl
  echo "Served $file_name.$file_ext witchlink."
  echo $(git cat-file -p 9eb4c0c897d21ac7db39a5d1a25bbeacf51c3ad4)$'\n'$(git cat-file -p ed1f67e477de14798295ed6091452354196e261d) > $file_name.$file_ext.wl
#git object cat insp from https://stackoverflow.com/a/56870314/5623661; echo newline insp from https://stackoverflow.com/a/8467448/5623661
  rm $file_name.$file_ext.wl && rm $file_name.$file_ext
done
#insp from https://superuser.com/a/763200/1619518 <3

#task: only continue if "touch" dont return error
#task: comment in https://superuser.com/a/763200/1619518 about mkfifo getting from files only at read, and not contantly on RAM
