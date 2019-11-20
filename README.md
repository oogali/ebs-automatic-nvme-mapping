# Automatic Mapping of NVMe-style EBS Volumes to Standard Block Device Paths

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
      --device=/dev/sdf \
      --instance-id=i-44444444444444444 \
      --volume-id=vol-22222222222222222
```

Right, now let's verify our volume was attached.

```
[ec2-user@ip-10-81-66-128 ~]$ dmesg | grep xvdf
[ec2-user@ip-10-81-66-128 ~]$
```

Uh, there's no mention of our block device (`xvdf`) in the kernel output. What about NVMe devices?

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
0000: 2f 64 65 76 2f 78 76 64 66 20 20 20 20 20 20 20 "/dev/xvdf......."
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
00000c00  2f 64 65 76 2f 78 76 64  66 20 20 20 20 20 20 20  |/dev/xvdf       |
00000c10  20 20 20 20 20 20 20 20  20 20 20 20 20 20 20 20  |                |
00000c20  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
*
00001000
```

The information within the vendor-specific data we are looking for appears to start at an offset of
3,072 bytes, is a 32-byte record, and is padded with spaces (`0x20` == 32 dec == `<SPACE>`).

```
[ec2-user@ip-10-81-66-128 ~]$ sudo nvme id-ctrl --raw-binary /dev/nvme1n1 | cut -c3073-3104
/dev/xvdf<AND 23 SPACES YOU DO NOT READILY SEE>
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
/dev/xvdf
```

We now have our desired block device name. 

## The Hacky Solution

We can create a symbolic link from the origin NVMe device, to the desired block device name.

```
[ec2-user@ip-10-81-66-128 ~]$ sudo ln -s /dev/nvme1n1 /dev/xvdf
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
[ec2-user@ip-10-81-66-128 ~]$ cat <<EOF> ebs-nvme-mapping.sh
> #!/bin/bash
> 
> if [[ ! -x /usr/sbin/nvme ]]; then
>   echo "ERROR: NVME tools not installed." >> /dev/stderr
>   exit 1
> fi
> 
> if [[ ! -b ${1} ]]; then
>   echo "ERROR: cannot find block device ${1}" >> /dev/stderr
>   exit 1
> fi
> 
> # capture 32 bytes at an offset of 3072 bytes from the raw-binary data
> # not all block devices are extracted with /dev/ prefix
> # use `xvd` prefix instead of `sd`
> # remove all trailing space
> nvme_link=$( \
>   /usr/sbin/nvme id-ctrl --raw-binary "${1}" | \
>   /usr/bin/cut -c3073-3104 | \
>   /bin/sed 's/^\/dev\///g'| \
>   /bin/sed 's/^sd/xvd/'| \
>   /usr/bin/tr -d '[:space:]' \
> );
> echo $nvme_link;
> EOF
[ec2-user@ip-10-81-66-128 ~]$ sudo install -m 0755 ebs-nvme-mapping.sh /usr/local/sbin/
[ec2-user@ip-10-81-66-128 ~]$
```

...and a udev rule...

```
[ec2-user@ip-10-81-66-128 ~]$ cat <<EOF> 999-aws-ebs-nvme.rules
> SUBSYSTEM=="block", KERNEL=="nvme[0-9]*n[0-9]*", ATTRS{model}=="Amazon Elastic Block Store", PROGRAM+="/usr/local/sbin/ebs-nvme-mapping.sh /dev/%k" SYMLINK+="%c"
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
[...]
Reading rules file: /etc/udev/rules.d/999-aws-ebs-nvme.rules
[...]
starting '/usr/local/sbin/ebs-nvme-mapping.sh /dev/nvme1n1'
[...]
'/usr/local/sbin/ebs-nvme-mapping.sh /dev/nvme1n1'(out) 'xvdf'
[...]
creating link '/dev/xvdf' to '/dev/nvme1n1'
[...]
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
      --device=/dev/sdf \
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
