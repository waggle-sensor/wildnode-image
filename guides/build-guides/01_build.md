# Build Instructions

**Table of Contents**
- [Build Instructions](#build-instructions)
- [Build Example Use-Cases](#build-example-use-cases)
  - [Use Case 1: NVidia Jetson Xavier NX Development Kit Build w/ Waggle OS](#use-case-1-nvidia-jetson-xavier-nx-development-kit-build-w-waggle-os)
  - [Use Case 2: Connect Tech Photon Build w/ Waggle OS](#use-case-2-connect-tech-photon-build-w-waggle-os)
  - [Use Case 3: NVidia Development Kit Build w/ NVidia Stock OS](#use-case-3-nvidia-development-kit-build-w-nvidia-stock-os)
- [Creating a Release Build](#creating-a-release-build)
  - [Release Build Assets](#release-build-assets)
- [Platform Specific Notes](#platform-specific-notes)
  - [Docker on Linux (x86)](#docker-on-linux-x86)
  - [Docker Desktop for Mac and Windows](#docker-desktop-for-mac-and-windows)
  - [Mac OSX core-utils `bash` tools](#mac-osx-core-utils-bash-tools)


Builds are created using the `./build.sh` script. For help execute `./build.sh -?`.

Building requires the NVidia L4T kernel tarball and (optionally) the NVidia L4T
sample root file system. These need to be downloaded ahead of time from the
NVidia developer website ([L4T download](https://developer.nvidia.com/embedded/linux-tegra-archive)).

> **Important**:
> The current build supports only version [32.4.4 of the L4T](https://developer.nvidia.com/embedded/linux-tegra-r3244) **only**.

There are several key build options that can be interchangeably used.  We will
outline some key use-cases of complete build commands here to explain how these
different options are used.

> *Note*:
> if this is your first time building on this platform see the
> ["Platform Specific Notes"](#platform-specific-notes) section below first.

# Build Example Use-Cases

<!-- no toc -->
1. [NVidia Xavier NX Development Kit (Waggle OS) (common)](#use-case-1-nvidia-jetson-xavier-nx-development-kit-build-w-waggle-os)
2. [ConnectTech Photon Unit (Waggle OS) (common)](#use-case-2-connect-tech-photon-build-w-waggle-os)
3. [NVidia Xavier NX Development Kit (NVidia Stock OS) (rare)](#use-case-3-nvidia-development-kit-build-w-nvidia-stock-os)

> *Note*: All builds require as input the [NVidia L4T BSP](https://developer.nvidia.com/embedded/linux-tegra-r3244). ([32.4.4 L4T BSP direct download](https://developer.nvidia.com/embedded/L4T/r32_Release_v4.4/r32_Release_v4.4-GMC3/T186/Tegra186_Linux_R32.4.4_aarch64.tbz2))

## Use Case 1: NVidia Jetson Xavier NX Development Kit Build w/ Waggle OS

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

Proceed to the ["Flashing Instructions"](./02_flash.md) for instructions on how to flash
your dev kit.

---

## Use Case 2: Connect Tech Photon Build w/ Waggle OS

If you have a [Connect Tech Photon NX unit](https://connecttech.com/product/photon-jetson-nano-ai-camera-platform/)
this is the build that you should be creating.

In order to create this build you also need to have 2 more artifacts in addition
to the NVidia L4T BSP (as mentioned above):

1. Waggle customized L4T BSP extension. Available at the [wildnode-kernel-releases page](https://github.com/waggle-sensor/wildnode-kernel-releases/releases). See https://github.com/waggle-sensor/wildnode-kernel-releases
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

Proceed to the ["Flashing Instructions"](./02_flash.md) for instructions on how to flash
your photon board.

---

## Use Case 3: NVidia Development Kit Build w/ NVidia Stock OS

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

Proceed to the ["Flashing Instructions"](./02_flash.md) for instructions on how to flash
your dev kit.

---

# Creating a Release Build

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

The state of the release build can be monitored on the [GitHub actions page](https://github.com/waggle-sensor/wildnode-image/actions) and after the release is complete it will appear on the [GitHub release page](https://github.com/waggle-sensor/wildnode-image/releases).

> Tagging and building releases is currently limited to [downstream customized repos](https://github.com/waggle-sensor/wildnode-customize-example) as it requires building in a [GitHub self-hosted runner](https://docs.github.com/en/actions/hosting-your-own-runners/about-self-hosted-runners) which is currently **NOT** enabled for this repo due to security concerns.

## Release Build Assets

Due to a GitHub [2GiB max file size limitation](https://docs.github.com/en/github/administering-a-repository/about-releases#storage-and-bandwidth-quotas) the assets included in the GitHub release are [split](https://linux.die.net/man/1/split) upon upload. This requires that they be re-packaged together after download.  This can be done by simply concatenating the files together or combined with the `tar` de-compression command.

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

# Platform Specific Notes

## Docker on Linux (x86)

Since this build is producing an ARM64 (aarch64) build we need to add cross
platform build support to an x86 based Linux environment.

To setup an Ubuntu system for working with images, this should be enough:

1. Install Docker CE for Linux from [Docker](https://docs.docker.com/install/).
2. Install emulation tools: `apt-get install qemu qemu-user-static binfmt-support`

## Docker Desktop for Mac and Windows

As of 2020, [Docker Desktop](https://www.docker.com/products/docker-desktop) seems to include everything required to do cross platform builds. I've confirmed this works on macOS as of Docker 19.03.8.

> The Docker Engine "experimental" feature may need to be enabled to allow for docker images of different architectures than the host system to be downloaded.  For help click [here](https://docs.docker.com/docker-for-mac/faqs/#what-is-an-experimental-feature).

## Mac OSX core-utils `bash` tools

In order to enable basic `bash` tools (like `realpath`) in OSX you will need to
`brew` install `coreutils`.

```
brew install coreutils
```
