# Wild Waggle Node Image Build

**Table of Contents**
- [Wild Waggle Node Image Build](#wild-waggle-node-image-build)
- [The Build Chain Overview](#the-build-chain-overview)
  - [Build Procedure Summary](#build-procedure-summary)
  - [Build Chain Repositories](#build-chain-repositories)
- [Open Credentials and Expected Customizations](#open-credentials-and-expected-customizations)
- [Unit Testing](#unit-testing)
- [References](#references)
  - [Waggle Customized Connect Tech BSP Extension](#waggle-customized-connect-tech-bsp-extension)
  - [Waggle Customized NVidia CBoot (bootloader)](#waggle-customized-nvidia-cboot-bootloader)
  - [Connect Tech Photon NGX003](#connect-tech-photon-ngx003)
    - [Photon L4T BSP Extension Instructions](#photon-l4t-bsp-extension-instructions)
  - [NVidia L4T Root File System Creation Instructions](#nvidia-l4t-root-file-system-creation-instructions)
  - [Surya Factory Flashing Tools](#surya-factory-flashing-tools)

Creates artifact(s) containing images for all bootloader, kernel and file system partitions including all necessary tools to flash the NVidia NX hardware of a [Wild Waggle Node](https://github.com/waggle-sensor/wild-waggle-node).

Build options allow suppling an external base rootfs (i.e. NVidia sample rootfs) or building a custom Waggle rootfs from the `Dockerfile.rootfs`. Supports creating artifacts for the [NVidia Jetson NX Developer Kit](https://developer.nvidia.com/embedded/jetson-xavier-nx-devkit) and the [Connect Tech Photon production unit](https://connecttech.com/jetson/nvidia-jetson-support/jetson-xavier-nx-support/).

For guides on building, flashing and usage:
- [Build Guides](./guides/build-guides/README.md) (building, flashing, & serial console access)
- [Usage Guides](./guides/usage-guides/README.md) (post-installation system customizations)

# The Build Chain Overview

The `public image` (i.e. this repository) combines an NVidia compatible bootloader and kernel with a Linux operating system (ex. `Ubuntu`) into a flash-able artifact. The artifact produced by this repository is "open" (or public) and does not contain any secrets (i.e. registration keys, secure passwords, etc.). A custom (and potentially private) artifact can be produced that builds "on-top" of the `public image`.

```
Image Build Chain

     L4T BSP                 OS file system           OS customizations
    ---------               ----------------         -------------------

 (1: bootloader ) ----
 (wildnode-cboot)    |
                     |----> (3: public image) ----> (4: customized image)
 (2:   kernel    ) ---      (wildnode-image )       (wildnode-customize )
 (wildnode-kernel)                 |                         |
                                   |                         |
                            [public artifact]       [private artifact]
```

Builds that are launched from this repository will generate a "public artifact" with the default (and open) configurations.
- The L4T BSP (1) bootloader and (2) kernel are combined with the (3) operating system files from this repository.

To produced a "private artifact" (containing secrets) a customized repository will "overlay" its files on top of the operating system files defined by this repository before initiating the build steps.
- The (4) customizations are "overlayed" on top of the (3) public operating system files and then combined with the L4T BSP (1) bootloader and (2) kernel.

> The above build-chain outlines the specifics to build the Connect Tech Photon Build w/ Waggle OS. When building without the Waggle bootloader and kernel the L4T BSP is provided by NVidia as a L4T tarball (see below for details).

## Build Procedure Summary

The building procedure consists of many steps and the summary of those steps is outlined here:

> Note: for the purpose of this summary a standard Waggle file system "open" public build will be demonstrated.

1. The build procedure is triggered via the `./build.sh` script (see: [Build Guides](./guides/build-guides/README.md) for usage instructions).

2. The `./build.sh` script kicks off the `docker` build (`Dockerfile.rootfs`) of the base custom Waggle OS filesystem.

    Starting with an `Ubuntu` based operating system, various Debian packages, K3S, Waggle specific packages, and the custom files (`./ROOTFS`) are added. The resulting image (`nx_build_rootfs:custom_base`) is a Waggle customized `Ubuntu` based file system.

3. The build script then kicks off a 2nd `docker` build (`Dockerfile.rootfs_gpu`) to add GPU support to the previously built base Waggle OS filesystem.

    Starting with the previously build file system (`nx_build_rootfs:custom_base`) GPU (i.e. `cuda`) support is added to the file system (`nx_build_rootfs:custom`).

4. The build script then kicks off a 3rd `docker` build (`Dockerfile`) to create the build environment to run the NVidia specific tools to produce the final "mass flash" artifact.

    During this step the entire file system (`nx_build_rootfs:custom`) is copied into the build environment as `rootfs`.

5. The build script then executes the `./create_image.sh` script within the build environment.

6. The `./create_images.sh` script performs various steps to produce the resulting "mass flash" artifact.

    The image creation process performs various steps:
     - The RPI PXE boot image is created (for the `/media/rpi` partition)
     - The "Photon" specific scripts are executed to install NVidia L4T specific binaries, kernel and bootloader
     - Other last minute `ROOTFS` file system changes are made
     - Custom L4T build system changes are made (ex. adds `/media/rpi` partition & custom Waggle bootloader)
     - Final version file is created on the resulting `ROOTFS` file system
     - NVidia "mass flash" tool is executed, creating the "mass flash" artifact

## Build Chain Repositories

This is a guide to the repositories that contain the artifacts used in the build chain.

- (1) Bootloader / cboot: https://github.com/waggle-sensor/wildnode-cboot
- (2) Kernel: https://github.com/waggle-sensor/wildnode-kernel-releases
- (3) Public OS: this repository (`./ROOTFS` and `./L4T_ROOTFS`)
- (4) Customization example: https://github.com/waggle-sensor/wildnode-customize-example
  - The Wild Waggle Node production customization can be found here: https://github.com/waggle-sensor/wildnode-waggle-secure (private)

# Open Credentials and Expected Customizations

Building this image will result in some open credentials and missing secrets that are expected to be overlayed by a [customized (and private) repo](https://github.com/waggle-sensor/wildnode-customize-example).

Here is an outline of the "open credentials" items:

1. `root` user credentials are set to `root` / `waggle` and needs to be changed to something more secure. (`./ROOTFS/root/credentials`)
2. `wifi-waggle` SSID password is set to `waggle` and needs to be changed to something more secure. (`./ROOTFS/etc/NetworkManager/system-connections/wifi-waggle`)

Here is a list of items that may need to be added depending on the use case:

1. `root` user `.ssh` private keys to enable `ssh` access to any agent compute units (i.e. nx-agent and/or RPi) (used here: `./ROOTFS/root/.ssh/config`)
2. Registration keys (`./ROOTFS/etc/waggle/sage_registration*`) to enable reverse `ssh` tunnel access. (see [waggle-bk-registration](https://github.com/waggle-sensor/waggle-bk-registration) for more details)
3. Network switch login credentials within the `./ROOTFS/etc/waggle/config-prod.ini` allowing automated testing (see [waggle-sanity-check](https://github.com/waggle-sensor/waggle-sanity-check) for more details)

> The above list outlines the most common items that will need to be overlayed by a [customized (and private) repo](https://github.com/waggle-sensor/wildnode-customize-example) but there may be others depending on the implementation.

# Unit Testing

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

# References

## Waggle Customized Connect Tech BSP Extension

https://github.com/waggle-sensor/wildnode-kernel (private)

Releases: https://github.com/waggle-sensor/wildnode-kernel-releases/releases

## Waggle Customized NVidia CBoot (bootloader)

https://github.com/waggle-sensor/wildnode-cboot

Releases: https://github.com/waggle-sensor/wildnode-cboot/releases

## Connect Tech Photon NGX003

[http://connecttech.com/product/photon-jetson-nano-ai-camera-platform/](http://connecttech.com/product/photon-jetson-nano-ai-camera-platform/)

### Photon L4T BSP Extension Instructions

The L4T BSP extension to support the Photon hardware can be found [here](http://connecttech.com/resource-center/l4t-board-support-packages/).
The `readme.txt` within the tarball states to execute `./install.sh` to add support
for the Photon to the NVidia L4T kernel.  This `./install.sh` script ends up
calling the NVidia L4T `./apply_binaries.sh` script (found in the NVidia L4T
instructions) after modifying the L4T environment.

## NVidia L4T Root File System Creation Instructions

The following URL is to the NVidia L4T Developer Guide: [https://docs.nvidia.com/jetson/archives/l4t-archived/l4t-3243/index.html](https://docs.nvidia.com/jetson/archives/l4t-archived/l4t-3243/index.html)

Here you can find instructions on how to create the the complete rootfs from
the NVidia L4T and NVidia sample rootfs in the "Setting Up Your File System"
section.

## Surya Factory Flashing Tools

The images produced by this repo and downstream [customized repos](https://github.com/waggle-sensor/wildnode-customize-example) can be flashed and provisioned using the factory tools found at [surya-tools](https://github.com/waggle-sensor/surya-tools).
