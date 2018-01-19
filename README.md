# Automatic Mapping of NVMe-style EBS Volums to Standard Block Device Paths

1. [Introduction](#introduction)
2. [The Problem](#the-problem)
3. [Brainstorming](#brainstorming)
4. [The Hacky Solution](#the-hacky-solution)
5. [The Less Hacky Solution](#the-less-hacky-solution)
6. [A Test Run](#a-test-run)

## Introduction

So you've decided to use the new `c5.large` or `m5.large` instance type in EC2.

Congratulations! You get more IOPS!

```
$ aws --profile=personal-aws-testing ec2 --region=us-east-1 \
    run-instances \
      --count=1 \
      --instance-type=m5.large \
      --image-id=ami-8d3fd59b \
      --key-name=aws-testing \
      --subnet-id=subnet-bbbbbbbb \
      --security-group-ids=sg-77777777 \
      --ebs-optimized \
      --instance-initiated-shutdown-behavior=terminate \
      --tag-specifications='ResourceType=instance,Tags=[{Key=Name,Value=nvme-mapping-example}]'
```
But wait, when you go to look at mountpoints (and disk space), what is this new `/dev/nvme*` device
you see?

```
[ec2-user@ip-10-81-64-224 ~]$ df -h
Filesystem      Size  Used Avail Use% Mounted on
...
/dev/nvme0n1p1  7.8G  956M  6.8G  13% /
```

Oh, ok. That's a NVMe block device per the AWS documentation[1]. That's cool.

## The Problem

Now, let's create and attach a 10GB EBS volume.

```
$ aws --profile=personal-aws-testing ec2 --region=us-east-1 \
    create-volume \
      --availability-zone=us-east-1a \
      --size=10 \
      --volume-type=gp2 \
      --tag-specifications='ResourceType=volume,Tags=[{Key=Name,Value="nvme-mapping-example, Example EBS Volume"}]'
...

$ aws --profile=personal-aws-testing ec2 --region=us-east-1 \
    attach-volume \
      --device=/dev/xvdt \
      --instance-id=i-44444444444444444 \
      --volume-id=vol-22222222222222222
```

Right, now let's verify our volume was attached.

```
[ec2-user@ip-10-81-66-128 ~]$ dmesg | grep xvdt
[ec2-user@ip-10-81-66-128 ~]$
```

Uh, there's no mention of our block device (`xvdt`) in the kernel output. What about NVMe devices?

```
[  504.204889] nvme 0000:00:1f.0: enabling device (0000 -> 0002)
```

That's not quite what I'm expecting from the old days.

## Brainstorming

There's more to this NVMe business. Let's get to it.

### nvme-cli

We'll start by install the NVMe tools, and requesting a list of all NVMe devices in the system.

```
[ec2-user@ip-10-81-66-128 ~]$ sudo yum install nvme-cli
...
Installed:
  nvme-cli.x86_64 0:0.7-1.3.amzn1

Complete!

[ec2-user@ip-10-81-66-128 ~]$ sudo nvme list
Node             SN                   Model                                    Version  Namespace Usage                      Format           FW Rev
---------------- -------------------- ---------------------------------------- -------- --------- -------------------------- ---------------- --------
/dev/nvme0n1     vol11111111111111111 Amazon Elastic Block Store               1.0      1           0.00   B /   8.59  GB    512   B +  0 B   1.0
/dev/nvme1n1     vol22222222222222222 Amazon Elastic Block Store               1.0      1           0.00   B /  10.74  GB    512   B +  0 B   1.0
```

The summary output shows our root EBS device (`/dev/nvme0n1`) and our newly created-and-attached
device (`/dev/nvme1n1`).

#### Can we get more information about our device? Yes.

```
[ec2-user@ip-10-81-66-128 ~]$ sudo nvme id-ctrl /dev/nvme1n1
NVME Identify Controller:
vid     : 0x1d0f
ssvid   : 0x1d0f
sn      : vol22222222222222222
mn      : Amazon Elastic Block Store
fr      : 1.0
rab     : 32
ieee    : dc02a0
cmic    : 0
mdts    : 6
cntlid  : 0
ver     : 0
rtd3r   : 0
rtd3e   : 0
oaes    : 0
oacs    : 0
acl     : 4
aerl    : 0
frmw    : 0x3
lpa     : 0
elpe    : 0
npss    : 1
avscc   : 0x1
apsta   : 0
wctemp  : 0
cctemp  : 0
mtfa    : 0
hmpre   : 0
hmmin   : 0
tnvmcap : 0
unvmcap : 0
rpmbs   : 0
sqes    : 0x66
cqes    : 0x44
nn      : 1
oncs    : 0
fuses   : 0
fna     : 0
vwc     : 0x1
awun    : 0
awupf   : 0
nvscc   : 0
acwu    : 0
sgls    : 0
ps    0 : mp:0.01W operational enlat:1000000 exlat:1000000 rrt:0 rrl:0
          rwt:0 rwl:0 idle_power:- active_power:-
ps    1 : mp:0.00W operational enlat:0 exlat:0 rrt:0 rrl:0
          rwt:0 rwl:0 idle_power:- active_power:-
```

#### How about MORE information? Yes.

```
[ec2-user@ip-10-81-66-128 ~]$ sudo nvme id-ctrl --vendor-specific /dev/nvme1n1
...
vs[]:
       0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
0000: 2f 64 65 76 2f 78 76 64 74 20 20 20 20 20 20 20 "/dev/xvdt......."
0010: 20 20 20 20 20 20 20 20 20 20 20 20 20 20 20 20 "................"
0020: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0030: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0040: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0050: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0060: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0070: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0080: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0090: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
00a0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
00b0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
00c0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
00d0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
00e0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
00f0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0100: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0110: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0120: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0130: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0140: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0150: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0160: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0170: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0180: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0190: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
01a0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
01b0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
01c0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
01d0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
01e0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
01f0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0200: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0210: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0220: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0230: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0240: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0250: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0260: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0270: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0280: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0290: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
02a0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
02b0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
02c0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
02d0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
02e0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
02f0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0300: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0310: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0320: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0330: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0340: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0350: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0360: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0370: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0380: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
0390: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
03a0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
03b0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
03c0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
03d0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
03e0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
03f0: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 "................"
```

Whaddya know? There's our requested block device name, at the beginning of the vendor specific
information.

Let's extract it. How? The `nvme id-ctrl` command takes an option called `--raw-binary`, which dumps
out the information block inclusive of the vendor-specific data.

```
[ec2-user@ip-10-81-66-128 ~]$ sudo nvme id-ctrl --raw-binary /dev/nvme1n1 | hexdump -C
00000000  0f 1d 0f 1d 76 6f 6c 30  32 34 32 39 34 33 34 62  |....vol222222222|
00000010  38 61 35 35 37 66 66 32  41 6d 61 7a 6f 6e 20 45  |22222222Amazon E|
00000020  6c 61 73 74 69 63 20 42  6c 6f 63 6b 20 53 74 6f  |lastic Block Sto|
00000030  72 65 20 20 20 20 20 20  20 20 20 20 20 20 20 20  |re              |
00000040  31 2e 30 20 20 20 20 20  20 a0 02 dc 00 06 00 00  |1.0      .......|
00000050  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00000100  00 00 04 00 03 00 00 01  01 00 00 00 00 00 00 00  |................|
00000110  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00000200  66 44 00 00 01 00 00 00  00 00 00 00 00 01 00 00  |fD..............|
00000210  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00000800  01 00 00 00 40 42 0f 00  40 42 0f 00 00 00 00 00  |....@B..@B......|
00000810  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00000c00  2f 64 65 76 2f 78 76 64  74 20 20 20 20 20 20 20  |/dev/xvdt       |
00000c10  20 20 20 20 20 20 20 20  20 20 20 20 20 20 20 20  |                |
00000c20  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00001000
```

The information within the vendor-specific data we are looking for appears to start at an offset of
3,072 bytes, is a 32-byte record, and is padded with spaces (`0x20` == 32 dec == `<SPACE>`).

```
[ec2-user@ip-10-81-66-128 ~]$ sudo nvme id-ctrl --raw-binary /dev/nvme1n1 | cut -c3073-3104
/dev/xvdt<AND 23 SPACES YOU DO NOT READILY SEE>
```

It looks fine... but it has trailing spaces. How to verify that? Count the characters.

```
[ec2-user@ip-10-81-66-128 ~]$ sudo nvme id-ctrl --raw-binary /dev/nvme1n1 | cut -c3073-3104 | wc -c
33
```

(It says 33 characters: 32 characters from our original block, plus one byte for a newline added by
`cut`)

So, let's trim the trailing spaces for a viable block device name.

```
[ec2-user@ip-10-81-66-128 ~]$ sudo nvme id-ctrl --raw-binary /dev/nvme1n1 | cut -c3073-3104 | tr -s ' ' | sed 's/ $//g'
/dev/xvdt
```

We now have our desired block device name. 

## The Hacky Solution

We can create a symbolic link from the origin NVMe device, to the desired block device name.

```
[ec2-user@ip-10-81-66-128 ~]$ sudo ln -s /dev/nvme1n1 /dev/xvdt
[ec2-user@ip-10-81-66-128 ~]$
```

However, the original block device can change with each reboot of the EC2 instance, e.g. reboot an
EC2 instance with two volumes attached, and AWS can attach the two EBS volumes in different order,
resulting in `nvme1n1` and `nvme2n1` swapping places.

But it's not limited to reboots. The same behavior can happen whenever an EBS volume is detached or
attached.

## The Less Hacky Solution

To make this a bit more resilient to attach-detach events, we want to trigger our shell script upon
each of those events. This is what udev[2] was made for.

### udev

`udev`, the userspace /dev manager, operates as a daemon, that receives events each time a device is
attached/detached from the host. It reads each event, compares the attributes of that event to a set
of rules (located in `/etc/udev/rules.d`), and executes the specified actions of the rule.

What are the attributes of our NVMe device that we can match on?

```
[ec2-user@ip-10-81-66-128 ~]$ sudo udevadm info --query=all --attribute-walk --path=/sys/block/nvme1n1

Udevadm info starts with the device specified by the devpath and then
walks up the chain of parent devices. It prints for every device
found, all possible attributes in the udev rules key format.
A rule to match, can be composed by the attributes of the device
and the attributes from one single parent device.

  looking at device '/devices/pci0000:00/0000:00:1f.0/nvme/nvme1/nvme1n1':
    KERNEL=="nvme1n1"
    SUBSYSTEM=="block"
    DRIVER==""
    ATTR{ro}=="0"
    ATTR{size}=="20971520"
    ATTR{stat}=="      61        0      920      108        0        0        0        0        0      108      108"
    ATTR{range}=="0"
    ATTR{discard_alignment}=="0"
    ATTR{ext_range}=="256"
    ATTR{alignment_offset}=="0"
    ATTR{inflight}=="       0        0"
    ATTR{removable}=="0"
    ATTR{capability}=="50"

  looking at parent device '/devices/pci0000:00/0000:00:1f.0/nvme/nvme1':
    KERNELS=="nvme1"
    SUBSYSTEMS=="nvme"
    DRIVERS==""
    ATTRS{model}=="Amazon Elastic Block Store              "
    ATTRS{serial}=="vol22222222222222222"
    ATTRS{firmware_rev}=="1.0     "

  looking at parent device '/devices/pci0000:00/0000:00:1f.0':
    KERNELS=="0000:00:1f.0"
    SUBSYSTEMS=="pci"
    DRIVERS=="nvme"
    ATTRS{irq}=="10"
    ATTRS{subsystem_vendor}=="0x1d0f"
    ATTRS{broken_parity_status}=="0"
    ATTRS{class}=="0x010802"
    ATTRS{driver_override}=="(null)"
    ATTRS{consistent_dma_mask_bits}=="64"
    ATTRS{dma_mask_bits}=="64"
    ATTRS{local_cpus}=="3"
    ATTRS{device}=="0x8061"
    ATTRS{enable}=="1"
    ATTRS{msi_bus}=="1"
    ATTRS{local_cpulist}=="0-1"
    ATTRS{vendor}=="0x1d0f"
    ATTRS{subsystem_device}=="0x8061"
    ATTRS{numa_node}=="0"
    ATTRS{d3cold_allowed}=="0"

  looking at parent device '/devices/pci0000:00':
    KERNELS=="pci0000:00"
    SUBSYSTEMS==""
    DRIVERS==""
```

In order to identify EBS volumes, we want something that is stable across reboots. But not too
specific to this volume, otherwise you're flying in the face of automation and manually hard-coding
your configuation.

I've picked `ATTRS{model}`.

Let's combine what we've found into a shell script...

```
[ec2-user@ip-10-81-66-128 ~]$ cat <<EOF> ebs-nvme-mapping
> #!/bin/bash
> 
> PATH="${PATH}:/usr/sbin"
> 
> for blkdev in $( nvme list | awk '/^\/dev/ { print $1 }' ) ; do
>   mapping=$(nvme id-ctrl --raw-binary "${blkdev}" | cut -c3073-3104 | tr -s ' ' | sed 's/ $//g')
>   if [[ "${mapping}" == /dev/* ]]; then
>     ( test -b "${blkdev}" && test -L "${mapping}" ) || ln -s "${blkdev}" "${mapping}"
>   fi
> done
> EOF
[ec2-user@ip-10-81-66-128 ~]$ sudo install -m 0755 ebs-nvme-mapping /usr/local/bin/
[ec2-user@ip-10-81-66-128 ~]$
```

...and a udev rule...

```
[ec2-user@ip-10-81-66-128 ~]$ cat <<EOF> 999-aws-ebs-nvme.rules
> ACTION=="add", SUBSYSTEM=="block", KERNEL=="nvme[1-26]n1", ATTRS{model}=="Amazon Elastic Block Store              ", RUN+="/usr/local/bin/ebs-nvme-mapping"
> EOF
[ec2-user@ip-10-81-66-128 ~]$ sudo install -m 0644 999-aws-ebs-nvme.rules /etc/udev/rules.d/
[ec2-user@ip-10-81-66-128 ~]$
```

`udev` will automatically reload rules upon changes to files in the rules directory. So we're locked
and loaded.

Now, when we attach and detach EBS volumes, our shell script will run.

## A Test Run

### Dry run

```
[ec2-user@ip-10-81-66-128 ~]$ sudo udevadm test /sys/block/nvme1n1
run_command: calling: test
adm_test: version 173
This program is for debugging only, it does not run any program,
specified by a RUN key. It may show incorrect results, because
some values may be different, or not available at a simulation run.

parse_file: reading '/lib/udev/rules.d/10-console.rules' as rules file
parse_file: reading '/lib/udev/rules.d/10-dm.rules' as rules file
parse_file: reading '/lib/udev/rules.d/11-dm-lvm.rules' as rules file
parse_file: reading '/lib/udev/rules.d/13-dm-disk.rules' as rules file
parse_file: reading '/lib/udev/rules.d/42-qemu-usb.rules' as rules file
parse_file: reading '/lib/udev/rules.d/50-firmware.rules' as rules file
parse_file: reading '/lib/udev/rules.d/50-udev-default.rules' as rules file
parse_file: reading '/etc/udev/rules.d/51-ec2-hvm-devices.rules' as rules file
parse_file: reading '/etc/udev/rules.d/52-ec2-vcpu.rules' as rules file
parse_file: reading '/etc/udev/rules.d/53-ec2-network-interfaces.rules' as rules file
parse_file: reading '/etc/udev/rules.d/60-cdrom_id.rules' as rules file
parse_file: reading '/lib/udev/rules.d/60-floppy.rules' as rules file
parse_file: reading '/lib/udev/rules.d/60-net.rules' as rules file
parse_file: reading '/lib/udev/rules.d/60-persistent-alsa.rules' as rules file
parse_file: reading '/lib/udev/rules.d/60-persistent-input.rules' as rules file
parse_file: reading '/lib/udev/rules.d/60-persistent-serial.rules' as rules file
parse_file: reading '/lib/udev/rules.d/60-persistent-storage-tape.rules' as rules file
parse_file: reading '/lib/udev/rules.d/60-persistent-storage.rules' as rules file
parse_file: reading '/lib/udev/rules.d/60-persistent-v4l.rules' as rules file
parse_file: reading '/etc/udev/rules.d/60-raw.rules' as rules file
parse_file: reading '/lib/udev/rules.d/61-accelerometer.rules' as rules file
parse_file: reading '/lib/udev/rules.d/64-md-raid.rules' as rules file
parse_file: reading '/lib/udev/rules.d/65-md-incremental.rules' as rules file
parse_file: reading '/lib/udev/rules.d/69-dm-lvm-metad.rules' as rules file
parse_file: reading '/etc/udev/rules.d/70-ec2-nvme-devices.rules' as rules file
parse_file: reading '/lib/udev/rules.d/75-cd-aliases-generator.rules' as rules file
parse_file: reading '/lib/udev/rules.d/75-net-description.rules' as rules file
parse_file: reading '/etc/udev/rules.d/75-persistent-net-generator.rules' as rules file
parse_file: reading '/lib/udev/rules.d/75-probe_mtd.rules' as rules file
parse_file: reading '/lib/udev/rules.d/75-tty-description.rules' as rules file
parse_file: reading '/lib/udev/rules.d/78-sound-card.rules' as rules file
parse_file: reading '/lib/udev/rules.d/80-drivers.rules' as rules file
parse_file: reading '/lib/udev/rules.d/81-kvm-rhel.rules' as rules file
parse_file: reading '/lib/udev/rules.d/88-clock.rules' as rules file
parse_file: reading '/lib/udev/rules.d/95-dm-notify.rules' as rules file
parse_file: reading '/lib/udev/rules.d/95-keyboard-force-release.rules' as rules file
parse_file: reading '/lib/udev/rules.d/95-keymap.rules' as rules file
parse_file: reading '/lib/udev/rules.d/95-udev-late.rules' as rules file
parse_file: reading '/dev/.udev/rules.d/99-root.rules' as rules file
parse_file: reading '/etc/udev/rules.d/999-aws-ebs-nvme.rules' as rules file
udev_rules_new: rules use 23184 bytes tokens (1932 * 12 bytes), 15869 bytes buffer
udev_rules_new: temporary index used 15140 bytes (757 * 20 bytes)
udev_device_new_from_syspath: device 0x55e241effc90 has devpath '/devices/pci0000:00/0000:00:1f.0/nvme/nvme1/nvme1n1'
udev_device_new_from_syspath: device 0x55e241effdc0 has devpath '/devices/pci0000:00/0000:00:1f.0/nvme/nvme1/nvme1n1'
udev_device_read_db: device 0x55e241effdc0 filled with db file data
udev_rules_apply_to_event: GROUP 6 /lib/udev/rules.d/50-udev-default.rules:68
udev_rules_apply_to_event: IMPORT 'path_id /devices/pci0000:00/0000:00:1f.0/nvme/nvme1/nvme1n1' /lib/udev/rules.d/60-persistent-storage.rules:61
udev_event_spawn: starting 'path_id /devices/pci0000:00/0000:00:1f.0/nvme/nvme1/nvme1n1'
spawn_read: 'path_id /devices/pci0000:00/0000:00:1f.0/nvme/nvme1/nvme1n1'(out) 'ID_PATH=pci-0000:00:1f.0'
spawn_read: 'path_id /devices/pci0000:00/0000:00:1f.0/nvme/nvme1/nvme1n1'(out) 'ID_PATH_TAG=pci-0000_00_1f_0'
spawn_wait: 'path_id /devices/pci0000:00/0000:00:1f.0/nvme/nvme1/nvme1n1' [22764] exit with return code 0
udev_rules_apply_to_event: LINK 'disk/by-path/pci-0000:00:1f.0' /lib/udev/rules.d/60-persistent-storage.rules:62
udev_rules_apply_to_event: IMPORT '/sbin/blkid -o udev -p /dev/nvme1n1' /lib/udev/rules.d/60-persistent-storage.rules:74
udev_event_spawn: starting '/sbin/blkid -o udev -p /dev/nvme1n1'
spawn_wait: '/sbin/blkid -o udev -p /dev/nvme1n1' [22765] exit with return code 2
udev_device_new_from_syspath: device 0x55e241efff80 has devpath '/devices/pci0000:00/0000:00:1f.0/nvme/nvme1'
udev_rules_apply_to_event: 3 character(s) replaced
udev_rules_apply_to_event: LINK 'disk/by-id/nvme-Amazon_Elastic_Block_Store_vol22222222222222222-ns-1' /etc/udev/rules.d/70-ec2-nvme-devices.rules:17
udev_rules_apply_to_event: RUN '/usr/local/bin/ebs-nvme-mapping' /etc/udev/rules.d/999-aws-ebs-nvme.rules:1
udev_event_execute_rules: no node name set, will use kernel supplied name 'nvme1n1'
udev_node_add: creating device node '/dev/nvme1n1', devnum=259:3, mode=0660, uid=0, gid=6
udev_node_mknod: preserve file '/dev/nvme1n1', because it has correct dev_t
udev_node_mknod: preserve permissions /dev/nvme1n1, 060660, uid=0, gid=6
node_symlink: preserve already existing symlink '/dev/block/259:3' to '../nvme1n1'
link_find_prioritized: found 'b259:3' claiming '/dev/.udev/links/disk\x2fby-path\x2fpci-0000:00:1f.0'
link_update: creating link '/dev/disk/by-path/pci-0000:00:1f.0' to '/dev/nvme1n1'
node_symlink: preserve already existing symlink '/dev/disk/by-path/pci-0000:00:1f.0' to '../../nvme1n1'
link_find_prioritized: found 'b259:3' claiming '/dev/.udev/links/disk\x2fby-id\x2fnvme-Amazon_Elastic_Block_Store_vol22222222222222222-ns-1'
link_update: creating link '/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol22222222222222222-ns-1' to '/dev/nvme1n1'
node_symlink: preserve already existing symlink '/dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol22222222222222222-ns-1' to '../../nvme1n1'
udev_device_update_db: created db file '/dev/.udev/data/b259:3' for '/devices/pci0000:00/0000:00:1f.0/nvme/nvme1/nvme1n1'
UDEV_LOG=6
DEVPATH=/devices/pci0000:00/0000:00:1f.0/nvme/nvme1/nvme1n1
MAJOR=259
MINOR=3
DEVNAME=/dev/nvme1n1
DEVTYPE=disk
ACTION=add
SUBSYSTEM=block
ID_PATH=pci-0000:00:1f.0
ID_PATH_TAG=pci-0000_00_1f_0
DEVLINKS=/dev/disk/by-path/pci-0000:00:1f.0 /dev/disk/by-id/nvme-Amazon_Elastic_Block_Store_vol22222222222222222-ns-1
.ID_FS_TYPE_NEW=
ID_FS_TYPE=
run: '/usr/local/bin/ebs-nvme-mapping'
```

### Live run

We have no block device (symlink) before...

```
[ec2-user@ip-10-81-66-128 ~]$ ls -la /dev/xvdf
ls: cannot access /dev/xvdf: No such file or directory
```

Now let's create and attach a new volume...

```
$ aws --profile=personal-aws-testing ec2 --region=us-east-1 \
    create-volume \
      --availability-zone=us-east-1a \
      --size=30 \
      --volume-type=gp2 \
      --tag-specifications='ResourceType=volume,Tags=[{Key=Name,Value="nvme-mapping-example, Example EBS Volume #2"}]'
...

$ aws --profile=personal-aws-testing ec2 --region=us-east-1 \
    attach-volume \
      --device=/dev/xvdf \
      --instance-id=i-44444444444444444 \
      --volume-id=vol-22222222222222222
...
```

Et voila!

```
[ec2-user@ip-10-81-66-128 ~]$ ls -la /dev/xvdf
lrwxrwxrwx 1 root root 12 Jan 19 21:43 /dev/xvdf -> /dev/nvme2n1
```

1: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/nvme-ebs-volumes.html

2: https://en.wikipedia.org/wiki/Udev
