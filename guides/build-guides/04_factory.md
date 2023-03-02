# Factory Provisioning

**Table of Contents**
- [Factory Provisioning](#factory-provisioning)
- [Monitoring the Factory Provisioning](#monitoring-the-factory-provisioning)
- [Provision State File](#provision-state-file)

The factory provisioning step is a one-time operating that needs to be executed
**soon** after flashing the device. When the device is flashed the file system
is left in a "read-write" state.  The provisioning process sets the core OS to
"read-only", protecting it from corruption.

> **Important**: This step should only be followed in the factory environment for Photon NX hardware. This prepares the device for the "real-world" by formatting and preparing all attached media and "locking down" the device with very limited access.

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
[provisioning state file](#provision-state-file) is created that will block future provisioning attempts.

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

# Monitoring the Factory Provisioning

All provisioning activity is logged to the basic journal logging system.

```
journalctl -f  | grep waggle-factory-provision
```

# Provision State File

The factory provisioning process is gated by the presence of a provision state
file (`/etc/waggle/factory/factory_provision`). Once the provisioning process **start**
the state file is created and future provisioning attempts will not be allowed
until the file is removed.  You should only remove the file if
**you know what you are doing**.  As performing provisioning more then once
**will** leave your system in an indetermined state.

The contents of the state file indicate when provisioning occurred and can be
referenced later as it is stored in the read-only root (/) file systems of both
the core system (eMMC) and recovery SD card.
