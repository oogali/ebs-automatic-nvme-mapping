#!/usr/bin/env bash

PATH="${PATH}:/usr/sbin"

for blkdev in $( nvme list | grep 'Amazon Elastic Block Store              ' | awk '/^\/dev/ { print $1 }' ) ; do
  mapping=$(nvme id-ctrl --raw-binary "${blkdev}" | cut -c3073-3104 | tr -s ' ' | sed 's/ $//g')
  if [[ "${mapping}" == /dev/* ]]; then
    ( test -b "${blkdev}" && test -L "${mapping}" ) || ln -s "${blkdev}" "${mapping}"
  elif [[ "/dev/${mapping}" == /dev/* ]]; then
    ( test -b "${blkdev}" && test -L "/dev/${mapping}" ) || ln -s "${blkdev}" "/dev/${mapping}"
  fi
done
