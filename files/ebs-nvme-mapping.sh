#!/bin/bash

PATH="${PATH}:/usr/sbin"

for blkdev in $( nvme list | awk '/^\/dev/ { print $1 }' ) ; do
  mapping=$(nvme id-ctrl --raw-binary "${blkdev}" | cut -c3073-3104 | tr -s ' ' | sed 's/ $//g' | sed 's/dev//g' | sed 's/\///g')
  if [[ "/dev/${mapping}" == /dev/* ]]; then
    ( test -b "${blkdev}" && test -L "/dev/${mapping}" ) || ln -s "${blkdev}" "/dev/${mapping}"
  fi
done
