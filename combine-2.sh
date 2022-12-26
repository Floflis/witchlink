#!/bin/bash

[ -p foobar.wl ] && rm foobar.wl

trap "[ -p foobar.wl ] && rm foobar.wl && exit" SIGINT

while [  true ]; do
  mkfifo foobar.wl
  echo "Writing File"
  cat file1.txt file2.txt > foobar.wl
  rm foobar.wl
done
