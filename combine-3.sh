#!/bin/bash

[ -p foobar.wl ] && rm foobar.wl

trap "[ -p foobar.wl ] && rm foobar.wl && exit" SIGINT

while [  true ]; do
  mkfifo foobar.wl
  echo "Writing File"
  echo "$(git cat-file -p 9eb4c0c897d21ac7db39a5d1a25bbeacf51c3ad4) $(git cat-file -p ed1f67e477de14798295ed6091452354196e261d)" > foobar.wl
  rm foobar.wl
done
#insp from https://superuser.com/a/763200/1619518 <3
