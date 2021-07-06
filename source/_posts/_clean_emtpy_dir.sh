#!/bin/bash

post_list=$(ls -A)
for dir in $post_list
do
  if [ -d $dir ]; then
    if [ ! "$(ls -A $dir)" ]; then
      echo "$dir is empty, remove it."
      `rm -rf $dir`
    fi
  fi

done
