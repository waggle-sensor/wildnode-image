# Wild Waggle Node Image Build

Creates artifact(s) containing images for all bootloader, kernel and file system partitions including all necessary tools to flash the NVidia NX hardware of a [Wild Waggle Node](https://github.com/waggle-sensor/wild-waggle-node).

Build options allow suppling an external base rootfs (i.e. NVidia sample rootfs)
or building a custom Waggle rootfs from the `Dockerfile.rootfs`. Supports creating
artifcats for the [NVidia Jetson NX Developer Kit](https://developer.nvidia.com/embedded/jetson-xavier-nx-devkit)
and the [Connect Tech Photon production unit](https://connecttech.com/jetson/nvidia-jetson-support/jetson-xavier-nx-support/).

These are the steps that need to be taken to build & flash an NVidia NX (Dev Kit or Photon
production unit):

1. Build: follow the ["Build Instructions"](#bi) for your unit
2. Flash: follow the ["Flashing Instructions"](#fi) for your unit
3. Validate: follow the ["Validate"](#val) steps
4. Factory Provisioning: follow the ["Factory Provision"](#factory) steps

> _Note_: follow the [additional usage guides](./usage-guides/README.md) for post-installation system customizations.

## <a name="bi"></a> Build Instructions

Builds are created using the `./build.sh` script. For help execute `./build.sh -?`.

Building requires the NVidia L4T kernel tarball and (optionally) the NVidia L4T
sample root file system. These need to be downloaded ahead of time from the
NVidia developer website ([L4T download](https://developer.nvidia.com/embedded/linux-tegra-archive)).

> **Important**:
> The current build supports only version [32.4.3 of the L4T](https://developer.nvidia.com/embedded/linux-tegra-r32.4.3) **only**.

There are several key build options that can be interchangeably used.  We will
outline some key use-cases of complete build commands here to explain how these
different options are used.

> *Note*:
> if this is your first time building on this platform see the
> ["Platform Specific Notes"](#psn) section below first.

### Build Example Use-Cases

1. [NVidia Xavier NX Development Kit (Waggle OS) (common)](#uc-one)
2. [ConnectTech Photon Unit (Waggle OS) (common)](#uc-two)
3. [NVidia Xavier NX Development Kit (NVidia Stock OS) (rare)](#uc-three)

> *Note*: All builds require as input the [NVidia L4T BSP](https://developer.nvidia.com/embedded/linux-tegra-r32.4.3).
> ([32.4.3 L4T BSP direct download](https://developer.nvidia.com/embedded/L4T/r32_Release_v4.3/t186ref_release_aarch64/Tegra186_Linux_R32.4.3_aarch64.tbz2))

---

#### <a name="uc-one"></a> Use Case 1: NVidia Jetson Xavier NX Development Kit Build w/ Waggle OS

If you have a [NVidia Jetson Xavier NX Development Kit unit](https://developer.nvidia.com/embedded/jetson-xavier-nx-devkit)
this is the build that you should be creating.

```
./build.sh \
  -l <path to Tegra L4T tarball> \
  -o <desired output filename, minus extension> \
  -m
```

Example:

```
./build.sh \
  -l /path/to/Tegra186_Linux_R32.4.3_aarch64.tbz2 \
  -o my_devkit_build \
  -m
```

Outline of options:
- l: path to the downloaded NVidia L4T BSP tarball
- o: (optional) name of the output artifacts
- m: (optional) create a factory "mass flash" archive

**Build Artifacts**

This build will produce one file:

1. my_devkit_build_mfi_<version tag>.tbz2 (NVidia mass flash archive)
  - **Will only work on a NVidia Jetson NX Development Kit.**

Proceed to the ["Flashing Instructions"](#fi) for instructions on how to flash
your dev kit.

---

#### <a name="uc-two"></a> Use Case 2: Connect Tech Photon Build w/ Waggle OS

If you have a [Connect Tech Photon NX unit](https://connecttech.com/product/photon-jetson-nano-ai-camera-platform/)
this is the build that you should be creating.

In order to create this build you also need to have 2 more artifacts in addition
to the NVidia L4T BSP (as mentioned above):

1. Waggle customized L4T BSP extension. Available at the [wildnode-kernel release page](https://github.com/waggle-sensor/wildnode-kernel/releases). See https://github.com/waggle-sensor/wildnode-kernel
for details.
1. Waggle customized L4T bootloader (cboot). Available at the [wildnode-cboot releaes page](https://github.com/waggle-sensor/wildnode-cboot/releases). See https://github.com/waggle-sensor/wildnode-cboot for details.

```
./build.sh \
  -l <path to Tegra L4T tarball> \
  -c <path to Waggle customized L4T BSP extension tarball> \
  -b <path to Waggle customized L4T bootloader> \
  -o <desired output filename, minus extension> \
  -m
```

Example:

```
./build.sh \
  -l /path/to/Tegra186_Linux_R32.4.3_aarch64.tbz2 \
  -c /path/to/CTI-L4T-XAVIER-NX-32.4.3-V004-SAGE-32.4.3.2-2bef51a25.tgz \
  -b /path/to/cboot_t194_32.4.3.1-c25d6f0.bin \
  -o my_photon_build \
  -m
```

Outline of options:
- l: path to the downloaded NVidia L4T BSP tarball
- c: path to the downloaded/built Waggle customized L4T BSP extension tarball
- b: path to the downloaded/built Waggle customized L4T bootloader (cboot)
- o: (optional) name of the output artifacts
- m: (optional) create a factory "mass flash" archive

**Build Artifacts**

This build will produce one file:

1. my_photon_build_mfi_<version tag>.tbz2 (NVidia mass flash archive)
  - **Will only work on a Connect Tech Photon unit.**

Proceed to the ["Flashing Instructions"](#fi) for instructions on how to flash
your photon board.

---

#### <a name="uc-three"></a> Use Case 3: NVidia Development Kit Build w/ NVidia Stock OS

To build the reference (or stock) L4T image using the full NVidia Ubuntu
GUI root file system (instead of the Waggle customized server root file system)
for your [NVidia Jetson Xavier NX Development Kit unit](https://developer.nvidia.com/embedded/jetson-xavier-nx-devkit) this is the build that you should be creating.

In order to create this build you will need to download the [NVidia L4T Sample Root Filesystem](https://developer.nvidia.com/embedded/linux-tegra-r3244).
([32.4.4 L4T Sample Root Filesystem direct download](https://developer.nvidia.com/embedded/L4T/r32_Release_v4.4/r32_Release_v4.4-GMC3/T186/Tegra_Linux_Sample-Root-Filesystem_R32.4.4_aarch64.tbz2))

```
./build.sh \
  -l <path to Tegra L4T tarball> \
  -r <path to rootfs filesystem tarball> \
  -o <desired output filename, minus extension> \
  -m
```

Example:

```
./build.sh \
  -l /path/to/Tegra186_Linux_R32.4.3_aarch64.tbz2 \
  -r /path/to/Tegra_Linux_Sample-Root-Filesystem_R32.4.3_aarch64.tbz2 \
  -o my_stock_build \
  -m
```

Outline of options:
- l: path to the downloaded NVidia L4T BSP tarball
- r: path to the downloaded NVidia L4T Root Filesystem tarball
- o: (optional) name of the output artifacts
- m: (optional) create a factory "mass flash" archive

**Build Artifacts**

This build will produce one file:

1. my_stock_build_mfi_<version tag>.tbz2 (NVidia mass flash archive)
  - **Will only work on a NVidia Jetson NX Development Kit.**

Proceed to the ["Flashing Instructions"](#fi) for instructions on how to flash
your dev kit.

---

### Creating a Release Build

An official "release" build is created by executing the `./release.sh` script.
For help execute `./release.sh -?`.  However, this script does not need to
be executed manually as it is primarily used by the GitHub release workflow
(./.github/workflows/release.yml).  To create a release simple tag the
commit with a tag starting with the letter "v" and push to GitHub.

```
git checkout <sha1 to be tagged>
git tag v1.2.3
git push origin v1.2.3
```

The state of the release build can be monitored on the
[GitHub actions page](https://github.com/waggle-sensor/wildnode-image/actions) and
after the release is complete it will appear on the
[GitHub release page](https://github.com/waggle-sensor/wildnode-image/releases).

#### <a name="rba"></a> Release Build Assets

Due to a GitHub [2GiB max file size limitation](https://docs.github.com/en/github/administering-a-repository/about-releases#storage-and-bandwidth-quotas) the assets included in the GitHub
release are [split](https://linux.die.net/man/1/split) upon upload. This requires
that they be re-packaged together after download.  This can be done by simply
concatenating the files together or combined with the `tar` de-compression command.

Recreate the original large file:

```
cat <base file name>-* > <base file name>.tbz2
```

Example:

```
cat devkit-image_mfi_nx-1.4.1-0-aee27ec.tbz2-* > devkit-image_mfi_nx-1.4.1-0-aee27ec.tbz2
```

Concatenation combined with `tar` de-compression:

```
cat <base file name>-* | tar xjf -
```

Example:

```
cat photon-image_mfi_nx-1.4.1-0-aee27ec.tbz2-* | tar xjf -
```

Or for verbose multi-threaded (using pbzip2) de-compression:

```
cat <base file name>-* | tar -x -Ipbzip2 -vf -
```

Example:

```
cat photon-image_mfi_nx-1.4.1-0-aee27ec.tbz2-* | tar -x -Ipbzip2 -vf -
```

### <a name="psn"></a> Platform Specific Notes

#### Docker on Linux (x86)

Since this build is producing an ARM64 (aarch64) build we need to add cross
platform build support to an x86 based Linux environment.

To setup an Ubuntu system for working with images, this should be enough:

1. Install Docker CE for Linux from [Docker](https://docs.docker.com/install/).
2. Install emulation tools: `apt-get install qemu qemu-user-static binfmt-support`

#### Docker Desktop for Mac and Windows

As of 2020, [Docker Desktop](https://www.docker.com/products/docker-desktop) seems to include everything required to do cross platform builds. I've confirmed this works on macOS as of Docker 19.03.8.

> *Note*: The Docker Engine "experimental" feature may need to be enabled to allow
> for docker images of different architectures than the host system to be
> downloaded.  For help click [here](https://docs.docker.com/docker-for-mac/faqs/#what-is-an-experimental-feature).

#### Mac OSX core-utils `bash` tools

In order to enable basic `bash` tools (like `realpath`) in OSX you will need to
`brew` install `coreutils`.

```
brew install coreutils
```

## <a name="fi"></a> Standard Flashing Instructions

During the ["build process"](#bi) outlined above up-to 2 artifacts will have
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

1. Move the build artifact(s) to a Linux based machine (ex. Ubuntu)
2. [Put the NVidia device into "Recovery Mode"](#recovery)
3. [Extract the archive](#eta)
4. [Initiate the flash procedure](#flashing)

> **Important**
> at this time a Linux based machine is required to flash the
> NX hardware. It may be possible to use a virtualization system (i.e. VirtualBox)
> with Linux (ex. Ubuntu) installed, but this has not yet been verified.

> *Note*:
> For NVidia's general flashing instructions go to the NVidia L4T
> Developer Guide (see References section below) section "Flashing and Booting
> the Target Device".

---

### <a name="recovery"></a> Putting the NVidia board into "Recovery Mode"

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

Proceed to ["Extract the Archive"](#eta)

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

Proceed to ["Extract the Archive"](#eta)

---

### <a name="eta"></a> Extract the Archive

Extracting the "NVidia developer flashing archive" and the "mass flash" follow
similar procedures:

> *Note*: If you have release assets see the ["Release Build Assets"](#rba) for
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

Proceed to ["Flashing a NVidia developer flashing archive"](#flashing_dev)

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

Proceed to ["Flashing a NVidia mass flash archive](#flashing_mass)

---

### <a name="flashing"></a> Flashing the NVidia unit

Flashing the "developer archive" and the "mass flash archive" follow 2
slightly different procedures:

<a name="flashing_dev"></a> **Option 1: Flashing a "NVidia developer flashing archive"**

As this is a developer archive the flashing tools offer a flexibility that
requires additional context about the flash operation(s) to be performed.
The example given here flashes *most* of the partitions, but not some of the
rarely changed ones (like CBoot). If you want to flash a specific partition
you can see the [Flash a Single Partition](#flash_one) section below. If you
want to ensure to flash *all* the partitions then you should use the
[Flashing a NVidia mass flash archive](#flashing_mass) instructions below.

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

Proceed to [Validate](#val)

<a name="flashing_mass"></a> **Option 2: Flashing a "NVidia mass flash archive"**

The "mass flash" is intended as a "one-stop-shop" flashing solution as it
flashes *all* the partitions and is pre-baked for a particular NVidia
hardware unit type (i.e. a Photon archive will **not** flash on a NVidia NX Dev Kit and vice-versa). This flashing method should be used in factory flashing conditions.

```
sudo ./nvmflash.sh
```

The flashing procedure will take several minutes and the board should
automatically reboot to a standard Linux terminal upon completion.

Proceed to [Validate](#val)


## <a name="afi"></a> Advanced Flashing Instructions

The following sections outline the procedures that are rarely used but may
prove useful.

### <a name="flash_one"></a> Flash a Single Partition

It is possible to flash a specific partition with the NVidia L4T `./flash.sh` tool.
For details see the "Flashing and Booting the Target Device" ->
"Flashing a Specific Partition" section in the NVidia L4T Developer Guide
(see References section below).

To flash the rootfs partition the following command can be used.

```
sudo ./flash.sh -k APP jetson-xavier-nx-devkit mmcblk0p1
```

### Creating an SD Card image file

Follow the instructions for "Flashing to an SD Card" in the NVidia L4T
Developer Guide (see References section below).

```
./jetson-disk-image-creator.sh -o sd-blob.img -b jetson-xavier-nx-devkit
```

Then burn the image to the SD card (see: [Etcher](https://www.balena.io/etcher/))


## <a name="val"></a> Validate

### Validate OS Version

To validate that the ["flashing procedure"](#fi) was successful, the Waggle OS
version can be compared to the flashing archive file name.

1. Get the first part of the Waggle OS version on the NX unit
(`/etc/waggle_version_os`) (ex. nx-1.4.1-0-gf5fd9c1)
2. Compare to the flashing archive file name (ex. test_mass_03_releases_mfi_nx-1.4.1-0-gf5fd9c1.tbz2)

The 'nx-1.4.1-0-gf5fd9c1' should match.

Proceed to ["Factory Provision"](#factory)

#### Differences in Waggle OS Version Between NVidia Dev Kit and Photon

An example of the OS version for the NVidia Dev Kit:
```
nx-1.4.1-0-gf5fd9c1 [kernel: Tegra186_Linux_R32.4.3_aarch64 | rootfs: Waggle_Linux_Custom-Root-Filesystem_nx-1.4.1-0-gf5fd9c1_aarch64]
```

An example of the OS version for the Connect Tech Photon board:
```
nx-1.4.1-0-gf5fd9c1 [kernel: Tegra186_Linux_R32.4.3_aarch64 | rootfs: Waggle_Linux_Custom-Root-Filesystem_nx-1.4.1-0-gf5fd9c1_aarch64 | cti_kernel_extension: CTI-L4T-XAVIER-NX-32.4.3-V004-SAGE-32.4.3.2-2bef51a25
```

#### Waggle OS Version Breakdown

The version is broken down into the following sections:
- `nx-1.4.1-0-gf5fd9c1`: the first 4 values are derived from the most recent
`git` version tag (i.e. `v1.4.0`) applied (using the `git describe` command).
The string after the last dash (`-`) is the 7 digit git SHA1 of this project at the
time the build was created.
- `kernel: Tegra186_Linux_R32.4.3_aarch64`: This is the version of the NVidia kernel BSP
- `rootfs: Waggle_Linux_Custom-Root-Filesystem_nx-1.4.1-0-gf5fd9c1_aarch64`: This the version
of the rootfs.  Will differ for a Waggle custom rootfs compared to the NVidia
sample rootfs.
- `cti_kernel_extension: CTI-L4T-XAVIER-NX-32.4.3-V004-SAGE-32.4.3.2-2bef51a25`:
The version of the Waggle customized L4T BSP extension.

## <a name="factory"></a> Factory Provisioning

> **Important**:
> This step should only be followed in the factory environment for Photon NX
> hardware. This prepares the device for the "real-world" by formatting and
> preparing all attached media and "locking down" the device with very limited
> access.

The factory provisioning step is a one-time operating that needs to be executed
**soon** after flashing the device. When the device is flashed the file system
is left in a "read-write" state.  The provisioning process sets the core OS to
"read-only", protecting it from corruption.

To execute the provisioning process:

1. Ensure that 16GB (or larger) SD card is inserted into the SD card slot and
enumerates as `/dev/mmcblk1`
2. Ensure that 512GB (or larger) (1TB preferred) NVMe is installed and enumerates
as `/dev/nvme0n1`
3. Login to the device (preferably through SSH)
4. Execute the following command:

```
/etc/waggle/factory/factory_provision.sh -r -c /etc/waggle/factory/factory_provision.conf
```

This process will take several minutes as the following operations are executed.
**Once this process starts it should NOT be interrupted!** In fact, a
[provisioning state file](#psf) is created that will block future provisioning attempts.

1. Lockdown: disables serial console login, removes WAN SSH access, and switches
the system from the "development" config to "production".
2. Recreate the ramdisk (initrd): recreates the ramdisk (initrd) with support
for the overlay file system that is used by the core system and recovery SD card.
3. Create the recovery SD card: formats the SD card with 2 partitions
(recovery OS, scratch space), syncs the current system root (/) partition to the
SD card's recovery root partition, removes any already established
Beehive/Beekeeper registration keys, and configures recovery root OS as
read-only with a tempfs overlay file system.
4. Prepares the NVMe media: formats the NVMe drive with 4 partitions
(swap, root partition backup, system-data, plugin-data), adds the swap partition
to the core system's swap pool, formats the backup root partition
(leaves empty for now), sets the eMMC (current system) root (/) partition as
read-only and configures the system-data partition as the read-write layer
of overlay file system, adds the plugin-data partition as a mount point and
moves Docker data to this partition.

After the provisioning process completes the system **MUST be rebooted** to
complete provisioning.  This will be done automatically by the `-r` option.

### Monitoring the Factory Provisioning

All provisioning activity is logged to a `syslog` log file: `/var/log/waggle/factory-provision.log`.  To monitor simple execute:

```
/var/log/waggle/factory-provision.log
```

or

```
journalctl -f  | grep waggle-factory-provision
```

### <a name="psf"></a> Provision State File

The factory provisioning process is gated by the presence of a provision state
file (`/etc/waggle/factory/factory_provision`). Once the provisioning process **start**
the state file is created and future provisioning attempts will not be allowed
until the file is removed.  You should only remove the file if
**you know what you are doing**.  As performing provisioning more then once
**will** leave your system in an indetermined state.

The contents of the state file indicate when provisioning occurred and can be
referenced later as it is stored in the read-only root (/) file systems of both
the core system (eMMC) and recovery SD card.

## Testing

### Unit Testing

The unit testing tests the 3 core building use-cases

1. NVidia development kit with Waggle custom OS, stock CBoot (bootloader),
in developer mode (with "mass flash")
2. Connect Tech Photon board with Waggle custom OS, Waggle custom CBoot (bootloader),
in production mode (with "mass flash")
3. NVidia development kit with NVidia stock OS stock CBoot (bootloader)

The unit test can be executed with the following command:

```
./unit-tests/unit-test.sh
```

Any failures detected during unit testing will result in the `unit-test.sh`
script returning a non-zero error code.

### GPU Stress Test

To test that the NVidia GPU is accessible and the NVidia L4T kernel is
functioning correctly the [Waggle GPU Stress Test](https://hub.docker.com/r/waggle/gpu-stress-test)
docker container can be downloaded to the NX and run.

See the [gpu-stress-test GitHub project](https://github.com/waggle-sensor/gpu-stress-test)
for runtime instructions.

## References

### Waggle Customized Connect Tech BSP Extension

https://github.com/waggle-sensor/wildnode-kernel

Releases: https://github.com/waggle-sensor/wildnode-kernel/releases

### Waggle Customized NVidia CBoot (bootloader)

https://github.com/waggle-sensor/wildnode-cboot

Releases: https://github.com/waggle-sensor/wildnode-cboot/releases

### Connect Tech Photon NGX003

[http://connecttech.com/product/photon-jetson-nano-ai-camera-platform/](http://connecttech.com/product/photon-jetson-nano-ai-camera-platform/)

#### Photon L4T BSP Extension Instructions

The L4T BSP extension to support the Photon hardware can be found [here](http://connecttech.com/resource-center/l4t-board-support-packages/).
The `readme.txt` within the tarball states to execute `./install.sh` to add support
for the Photon to the NVidia L4T kernel.  This `./install.sh` script ends up
calling the NVidia L4T `./apply_binaries.sh` script (found in the NVidia L4T
instructions) after modifying the L4T environment.

### NVidia L4T Root File System Creation Instructions

The following URL is to the NVidia L4T Developer Guide: [https://docs.nvidia.com/jetson/archives/l4t-archived/l4t-3243/index.html](https://docs.nvidia.com/jetson/archives/l4t-archived/l4t-3243/index.html)

Here you can find instructions on how to create the the complete rootfs from
the NVidia L4T and NVidia sample rootfs in the "Setting Up Your File System"
section.
