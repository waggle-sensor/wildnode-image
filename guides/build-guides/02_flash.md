# Standard Flashing Instructions

**Table of Contents**
- [Standard Flashing Instructions](#standard-flashing-instructions)
- [Putting the NVidia board into "Recovery Mode"](#putting-the-nvidia-board-into-recovery-mode)
- [Extract the Archive](#extract-the-archive)
- [Flashing the NVidia unit](#flashing-the-nvidia-unit)
  - [Option 1: Flashing a "NVidia developer flashing archive"](#option-1-flashing-a-nvidia-developer-flashing-archive)
  - [Option 2: Flashing a "NVidia mass flash archive"](#option-2-flashing-a-nvidia-mass-flash-archive)
- [Advanced Flashing Instructions](#advanced-flashing-instructions)
  - [Flash a Single Partition](#flash-a-single-partition)
  - [Creating an SD Card image file](#creating-an-sd-card-image-file)


During the ["build process"](./01_build.md) outlined above up-to 2 artifacts will have
been produced:

1. NVidia developer flashing archive (starting with "<name>_nx")
2. NVidia mass flash archive (starting with "<name>_mfi_nx") (*Hint: this probably the one you want to use*)

The *NVidia developer flashing archive* contains all images to be flashed to the NX unit
and developer tools for manipulating various NX models. This is basically an
un-filtered archive of all the tools (i.e. flashing, creating bootloaders,
signing images, blowing fuses, etc.) that NVidia provides for working with
the various NVidia platforms. Essentially, this is a combined archive of
the images to be flashed and the entire NVidia tool-set and is
**most often used during development**.

The *NVidia mass flash archive* is a compressed and filtered archive of **only**
the images needed for flashing specific NVidia hardware. Essentially, a
customized archive with the minimal items needed to flash a specific NVidia board.
This is **to be used if all you care about is flashing the software to your device**
and in factory environments (as it hides any secret keys).

These are the steps that need to be taken to flash an NVidia NX (Dev Kit or Photon
production unit):

<!-- no toc -->
1. Move the build artifact(s) to a Linux based machine (ex. Ubuntu)
2. [Put the NVidia device into "Recovery Mode"](#putting-the-nvidia-board-into-recovery-mode)
3. [Extract the archive](#extract-the-archive)
4. [Initiate the flash procedure](#flashing-the-nvidia-unit)

> **Important**
> at this time a Linux based machine is required to flash the
> NX hardware. It may be possible to use a virtualization system (i.e. VirtualBox)
> with Linux (ex. Ubuntu) installed, but this has not yet been verified.

> *Note*:
> For NVidia's general flashing instructions go to the NVidia L4T
> Developer Guide (see References section below) section "Flashing and Booting
> the Target Device".

# Putting the NVidia board into "Recovery Mode"

The NVidia Developer Kit and the Connect Tech Photon board have different
procedures for putting the board into "recovery mode".

> **Important:
> Flashing must be performed from a native Linux environment for proper USB enumeration.**

> *Note*
> You should start the flashing operation soon after putting the NVidia
> board into recovery mode. The NVidia board will eventually timeout in
> recovery mode and the flashing will fail. If this happens, just remove power
> from the device and re-enter recovery mode.

**Option 1: NVidia Developer Kit**

Entering recovery mode can be done by putting a jumper on pins 9 & 10 on the J14 header
when powering on the board.  See the "Developer Kit User Guide" downloadable from
the [Xavier NX Download Center](https://developer.nvidia.com/embedded/downloads#?search=Jetson%20Xavier%20NX%20Developer%20Kit%20User%20Guide)
linked off the main [NVidia NX Dev Kit site](https://developer.nvidia.com/embedded/jetson-xavier-nx-devkit).

Connect the Dev Kit micro USB (J5) to your Linux computer.

You can test that the Dev Kit has enumerated properly by using the `lsusb` command

```
$ lsusb | grep -i nvidia
Bus 002 Device 009: ID 0955:7e19 NVidia Corp.
```

Proceed to ["Extract the Archive"](#extract-the-archive)

**Option 2: Connect Tech Photon**

Entering recovery mode can be done by holding down the recovery button (SW2)
between the Ethernet jack (P7) and micro USB port (P6) (used for serial output)
for 10 seconds while the board is powered. You will know you successfully
entered recovery mode because the NX SoC fan will spin at max speed.  See the
[Photon Manual](https://connecttech.com/pdf/CTIM_NGX002_Manual.pdf), section
"Reset & Recovery Pushbutton" for details.

Connect the micro USB port (P13) (below the Ethernet jack) to your Linux computer.

You can test that the Photon has enumerated properly by using the `lsusb` command

```
$ lsusb | grep -i nvidia
Bus 002 Device 009: ID 0955:7e19 NVidia Corp.
```

Proceed to ["Extract the Archive"](#extract-the-archive)

---

# Extract the Archive

Extracting the "NVidia developer flashing archive" and the "mass flash" follow
similar procedures:

> *Note*: If you have release assets see the ["Release Build Assets"](./01_build.md#release-build-assets) for
> instructions on re-combining the assets into a tarball before continuing.

**Option 1: NVidia developer flashing archive**

```
mkdir full_archive
cd full_archive/
sudo tar xpf ../my_build.tbz2
```

Or multi-threaded (faster but more CPU intensive):

```
mkdir full_archive
cd full_archive/
sudo tar -x -Ipbzip2 -pf ../my_build.tbz2
```

This will produce a folder containing alot of files. The most important of which
is the `flash.sh` script that will be used during flashing.

Proceed to ["Flashing a NVidia developer flashing archive"](#option-1-flashing-a-nvidia-developer-flashing-archive)

**Option 2: NVidia mass flash archive**

```
mkdir mass_flash
cd mass_flash/
tar xf ../my_build_mfi.tbz2
```

Or multi-threaded (faster but more CPU intensive):

```
mkdir mass_flash
cd mass_flash/
tar -x -Ipbzip2 -f ../my_build_mfi.tbz2
```

This will produce a folder containing a "mfi_<board target>" (ex. "mfi_waggle_photon").
Within that folder you will find `nvmflash.sh` script that will be used during
flashing.

Proceed to ["Flashing a NVidia mass flash archive](#option-2-flashing-a-nvidia-mass-flash-archive)

---

# Flashing the NVidia unit

Flashing the "developer archive" and the "mass flash archive" follow 2
slightly different procedures:

## Option 1: Flashing a "NVidia developer flashing archive"

As this is a developer archive the flashing tools offer a flexibility that
requires additional context about the flash operation(s) to be performed.
The example given here flashes *most* of the partitions, but not some of the
rarely changed ones (like CBoot). If you want to flash a specific partition
you can see the [Flash a Single Partition](#flash-a-single-partition) section below. If you
want to ensure to flash *all* the partitions then you should use the
[Flashing a NVidia mass flash archive](#option-2-flashing-a-nvidia-mass-flash-archive) instructions below.

For a NX Developer Kit you will use the following command:

```
sudo ./flash.sh jetson-xavier-nx-devkit mmcblk0p1
```

For the Connect Tech Photon unit you will use the following command:

```
sudo ./flash.sh waggle_photon mmcblk0p1
```

The flashing procedure will take several minutes and the board should
automatically reboot to a standard Linux terminal upon completion.

Proceed to [Validate](./03_validate.md)

## Option 2: Flashing a "NVidia mass flash archive"

The "mass flash" is intended as a "one-stop-shop" flashing solution as it
flashes *all* the partitions and is pre-baked for a particular NVidia
hardware unit type (i.e. a Photon archive will **not** flash on a NVidia NX Dev Kit and vice-versa). This flashing method should be used in factory flashing conditions.

```
sudo ./nvmflash.sh
```

The flashing procedure will take several minutes and the board should
automatically reboot to a standard Linux terminal upon completion.

Proceed to [Validate](./03_validate.md)


# Advanced Flashing Instructions

The following sections outline the procedures that are rarely used but may
prove useful.

## Flash a Single Partition

It is possible to flash a specific partition with the NVidia L4T `./flash.sh` tool.
For details see the "Flashing and Booting the Target Device" ->
"Flashing a Specific Partition" section in the NVidia L4T Developer Guide
(see References section below).

To flash the rootfs partition the following command can be used.

```
sudo ./flash.sh -k APP jetson-xavier-nx-devkit mmcblk0p1
```

## Creating an SD Card image file

Follow the instructions for "Flashing to an SD Card" in the NVidia L4T
Developer Guide (see References section below).

```
./jetson-disk-image-creator.sh -o sd-blob.img -b jetson-xavier-nx-devkit
```

Then burn the image to the SD card (see: [Etcher](https://www.balena.io/etcher/))
