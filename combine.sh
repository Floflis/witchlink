#!/bin/bash

[ -p foobar.wl ] && rm foobar.wl

trap "[ -p foobar.wl ] && rm foobar.wl && exit" SIGINT

while [  true ]; do
  mkfifo foobar.wl
  echo "Writing File"
  cat file1.txt file2.txt > foobar.wl
  rm foobar.wl
done
#insp from https://superuser.com/a/763200/1619518 <3
