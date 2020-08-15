# QEMU Notes
This document has some useful commands and explanations that I have written while studying QEMU, and developed QEMU Reeves.

## General Setup Commands
Before I wrote the QEMU Reeves script, I kept track of some of the different commands I used to setup a Debian VM. These aren't optimal (the commands produced by QEMU Reeves pretty much are, for my setup, though), but I keep these here for historical purposes. The one thing that is here that is absent from that script is the nonfunctional networking portion.
```sh
# This command creates a new disk to install to:
qemu-img create -f qcow2 debian-base.img 15G
# The qcow2 format allows zlib file compression (As opposed to the file "compression" of a raw disk
# with "holes", only writing used parts to the disk.), as well as snapshots. It's the format for
# QEMU, but can be exported with the qemu-nbd tool, or converted with qemu-img convert. The
# tradeoff of using this format is that it's less performant than the raw disk image.

qemu-system-x86_64 -machine pc,accel=kvm -cpu host -m 512M debian-9.9.0-amd64-xfce-CD-1.iso --enable-kvm
# This command specifies the installation media as the main raw hard disk image, but QEMU always
# complains about the format for it not being specified. I'm not really sure how I would
# specify the installer though.

# This is the final command I ended up with for running the installer.
qemu-system-x86_64 -machine pc,accel=kvm -cpu host -boot d -m 2G -hda debian-base.img -cdrom debian-9.9.0-amd64-xfce-CD-1.iso --enable-kvm

# This command creates a disk to record changes made to the base. The potential use for this would
# be running the installer, installing Debian to "debian-base.img", and not writing to that image
# from that point on. Therefore, we can derive images, like "debian-main.img", and still have the
# ability to start fresh. The issue of this in practice is that the base image becomes quickly
# outdated.
qemu-img create -f qcow2 -b debian-base.img debian-main.img 15G

# These commands create a bridge connection for use with QEMU. I never got this working, because
# there are somewhat significant complexities in setting up a bridge with a wireless connection.
nmcli c add type bridge ifname br0 con-name "QEMU Bridge" stp no
nmcli c add type bridge-slave ifname wlp37s0 con-name "Main Wireless Slave" master br0
```
This is the `fstab` from my Debian installation, setup for a Plan folder share, which I no longer use in favor of some more portable solutions like SMB shares and SPICE folder shares.
```
# This is a filesystem table that I ripped from my Debian 10 QEMU installation. The main thing of
# interest is the shared folder.

# Debian root parition on the disk image.
UUID=91109490-7714-4510-b695-3b4a24f648d1 /                 ext4    errors=remount-ro                                           0 1
# Swap partition on the disk image.
UUID=a9501a38-5326-46ef-b427-3b811581df27 none              swap    sw                                                          0 0
# Shared directory on the 9p "share" tag. Don't halt the boot if not present, so that the VM can be
# started without the Plan 9 folder sharing being properly setup on the host.
share                                     /home/koopa/Share 9p      noauto,x-systemd.automount,nofail,x-systemd.mount-timeout=1 0 0
```
This is the command used for installing necessary guest software on Debian.
```
sudo apt install qemu-guest-agent xserver-xorg-video-qxl spice-vdagent
```
These are the Debian `build-essential` packages. I honestly kind of forget why this is here. I think it was because I wanted to see what each package does.
```
The following additional packages will be installed:
  binutils binutils-common binutils-x86-64-linux-gnu dpkg-dev fakeroot g++ g++-8 gcc gcc-8 libalgorithm-diff-perl libalgorithm-diff-xs-perl libalgorithm-merge-perl libasan5 libbinutils libc-dev-bin libc6-dev
  libcc1-0 libdpkg-perl libfakeroot libfile-fcntllock-perl libgcc-8-dev libitm1 liblsan0 libmpx2 libstdc++-8-dev libtsan0 libubsan1 linux-libc-dev make manpages-dev patch
Suggested packages:
  binutils-doc debian-keyring g++-multilib g++-8-multilib gcc-8-doc libstdc++6-8-dbg gcc-multilib autoconf automake libtool flex bison gdb gcc-doc gcc-8-multilib gcc-8-locales libgcc1-dbg libgomp1-dbg
  libitm1-dbg libatomic1-dbg libasan5-dbg liblsan0-dbg libtsan0-dbg libubsan1-dbg libmpx2-dbg libquadmath0-dbg glibc-doc git bzr libstdc++-8-doc make-doc ed diffutils-doc
The following NEW packages will be installed:
  binutils binutils-common binutils-x86-64-linux-gnu build-essential dpkg-dev fakeroot g++ g++-8 gcc gcc-8 libalgorithm-diff-perl libalgorithm-diff-xs-perl libalgorithm-merge-perl libasan5 libbinutils
  libc-dev-bin libc6-dev libcc1-0 libdpkg-perl libfakeroot libfile-fcntllock-perl libgcc-8-dev libitm1 liblsan0 libmpx2 libstdc++-8-dev libtsan0 libubsan1 linux-libc-dev make manpages-dev patch
0 upgraded, 32 newly installed, 0 to remove and 0 not upgraded.
Need to get 38.9 MB of archives.
After this operation, 155 MB of additional disk space will be used.
```

## Windows XP
There are some adversities to using Windows XP today, but it is totally doable, and [there is a community behind it](https://xpforever.miraheze.org/). These are the loose steps I used for setting up my VM:
- Obtain a Windows XP VM installation disc, preferably SP3.
- Install the virtual system, [with virtio drivers](https://wiki.archlinux.org/index.php/QEMU#Preparing_a_Windows_guest) if you are using a virtio disk.
- Wait, and allow the VM to download Windows Updates. I don't know of any better way to monitor this, but when it happens, there will be a Windows Update icon in the tray.
  - No internet configuration within the guest should be necessary. You can configure an always-on broadband connection, but this doesn't seem to actually change anything.
- Download and install all Windows Updates from Internet Explorer (Tools > Windows Update).
  - [This](https://blog.dhampir.no/content/installing-windows-live-essentials-on-windows-xp-error-oncatalogresult-0x80190194) workaround is necessary to install the Windows Live update.
- [Mount the Windows XP disk to the host](https://wiki.archlinux.org/index.php/QEMU#Mounting_a_partition_from_a_qcow2_image).
- Copy the installer for an [XP compatible installer](https://xpforever.miraheze.org/wiki/Internet_Access) to the guest disk.
  - I use Mypal, and it works well.
- Install spice-guest-tools and the Spice WebDAV daemon from [here](https://www.spice-space.org/download.html).
- Install [BitKinex](http://www.bitkinex.com/) to the host. This allows it to use the WebDAV share exposed by SPICE. This is necessary because [webdav does not seem to work on Windows XP](https://lists.freedesktop.org/archives/spice-devel/2020-July/051780.html).
  - Note that the new versions of spice-webdavd do not work on Windows XP. See that mailing list archive for more info on that.
