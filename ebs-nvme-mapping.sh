#!/bin/bash
# Inspired by https://github.com/oogali/ebs-automatic-nvme-mapping
# Thanks Oogali!
# Tested on Ubuntu 16.04
# To be used with the below udev rule (/etc/udev/rules.d/999-aws-ebs-nvme.rules)
# SUBSYSTEM=="block", KERNEL=="nvme[0-9]*n[0-9]*", ATTRS{model}=="Amazon Elastic Block Store", PROGRAM+="/usr/local/sbin/ebs-nvme-mapping.sh /dev/%k" SYMLINK+="%c"

if [[ -x /usr/sbin/nvme ]] && [[ -b ${1} ]]; then
  # capture 32 bytes at an offset of 3072 bytes from the raw-binary data
  # not all block devices are extracted with /dev/ prefix
  # use `xvd` prefix instead of `sd`
  # remove all trailing space
  nvme_link=$( \
    /usr/sbin/nvme id-ctrl --raw-binary "${1}" | \
    /usr/bin/cut -c3073-3104 | \
    /bin/sed 's/^\/dev\///g'| \
    /bin/sed 's/^sd/xvd/'| \
    /usr/bin/tr -d '[:space:]' \
  );
  echo $nvme_link;
fi
