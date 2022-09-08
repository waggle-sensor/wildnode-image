# Validate OS Version

**Table of Contents**
- [Validate OS Version](#validate-os-version)
- [Differences in Waggle OS Version Between NVidia Dev Kit and Photon](#differences-in-waggle-os-version-between-nvidia-dev-kit-and-photon)
- [Waggle OS Version Breakdown](#waggle-os-version-breakdown)


To validate that the ["flashing procedure"](./02_flash.md) was successful, the Waggle OS
version can be compared to the flashing archive file name.

1. Get the first part of the Waggle OS version on the NX unit
(`/etc/waggle_version_os`) (ex. nx-1.4.1-0-gf5fd9c1)
2. Compare to the flashing archive file name (ex. test_mass_03_releases_mfi_nx-1.4.1-0-gf5fd9c1.tbz2)

The 'nx-1.4.1-0-gf5fd9c1' should match.

> If a version extension is provided by a [downstream customized repos](https://github.com/waggle-sensor/wildnode-customize-example) then the version string will resemble the following: `nx-1.9.1-0-gfe06d2d-custom-1.0.0-1-gfe06d2d` where the `custom-1.0.0-1-gfe06d2d` part is the version extension provided by the downstream build steps.

Proceed to ["Factory Provision"](./04_factory.md)

# Differences in Waggle OS Version Between NVidia Dev Kit and Photon

An example of the OS version for the NVidia Dev Kit:
```
nx-1.4.1-0-gf5fd9c1 [kernel: Tegra186_Linux_R32.4.3_aarch64 | rootfs: Waggle_Linux_Custom-Root-Filesystem_nx-1.4.1-0-gf5fd9c1_aarch64]
```

An example of the OS version for the Connect Tech Photon board:
```
nx-1.4.1-0-gf5fd9c1 [kernel: Tegra186_Linux_R32.4.3_aarch64 | rootfs: Waggle_Linux_Custom-Root-Filesystem_nx-1.4.1-0-gf5fd9c1_aarch64 | cti_kernel_extension: CTI-L4T-XAVIER-NX-32.4.3-V004-SAGE-32.4.3.2-2bef51a25
```

# Waggle OS Version Breakdown

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
