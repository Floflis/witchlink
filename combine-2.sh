#!/bin/bash

[ -p foobar ] && rm foobar

trap "[ -p foobar ] && rm foobar && exit" SIGINT

while [  true ]; do
  mkfifo foobar
  echo "Writing File"
  cat file1.txt file2.txt > foobar
  rm foobar
done
