#!/usr/bin/env bash
# To be used with the udev rule: /etc/udev/rules.d/999-aws-ebs-nvme.rules

# check if lock file exists
script_name="$(basename $0)"
pid_file="/tmp/${script_name}.lock"
counter=0
until [ $counter -eq 5 ] || [[ ! -e "${pid_file}" ]] ; do
  sleep $(( counter++ ))
done

# create lock file if it does not exist
if [[ -e "${pid_file}" ]]; then
  echo "Lock file ${pid_file} still exists after counter ended" >&2
  exit 1
else
  touch "${pid_file}"
fi

kern_name=${1}
incr=0
while [[ -e "/dev/ephemeral${incr}" ]] && [[ $(readlink "/dev/ephemeral${incr}") != "${kern_name}" ]]; do
  incr=$[$i+1]
done
# remove lock file
rm "${pid_file}"
echo "ephemeral${incr}"
