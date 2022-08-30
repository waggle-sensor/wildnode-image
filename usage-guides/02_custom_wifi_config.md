# How to Configure Wifi as the Primary Internet Uplink

The following are instructions on how to add the customizations to the node operating system to use a custom Wifi access-point as the primary uplink for the node. These are the instructions that you should follow if you have an existing Wifi network and you want to connect the node to that network.

> These instructions require Admin access to the node

> See [Connecting to a Waggle Wifi Hotspot](./01_waggle_hotspot.md) for instructions on how to connect the node to the pre-configured hotspot.

## 1: Create the `NetworkManager` configuration using `nmtui` or `nmcli`

These are instructions to create the configuration file that will be copied to the backup partitions. The goals of this step are to create and test the connection configuration.

1. Verify the NVMe overlay read/write partition is mounted. If t
    ```bash
    $ lsblk /dev/nvme0n1p3
    NAME      MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
    nvme0n1p3 259:3    0  256G  0 part /media/root-rw
    ```

    > If the above command fails, the system is not in the correct state to proceed.

2. Using `nmcli` or `nmtui` create the connection.

> These changes are written to the node's NVMe drive, specifically, the `/media/root-rw` partition, within the `/media/root-rw/overlay/etc/NetworkManager/system-connections` directory. For example:
> ```bash
> root@ws-nxcore-000048B02D0766BE:/media/root-rw/overlay/etc/NetworkManager/system-connections# ls -la wifi-custom
> -rw------- 1 root root 466 May 18 22:45 wifi-custom
> ```


## 2: Copy the `NetworkManager` configuration to the read-only eMMC

In step 1, the `NetworkManager` configuration was saved to the NVMe drive. In the event that the NVMe drive experiences a problem (i.e. failed boot or thermal shutdown) the configuration will **not** be present. Therefore, in this step we will copy the configuration created in step 1 to the backing (read-only) eMMC drive.

For these steps we will use the following example configuration:

```bash
root@ws-nxcore-000048B02D0766BE:/media/root-rw/overlay/etc/NetworkManager/system-connections# ls -la wifi-custom
-rw------- 1 root root 466 May 18 22:45 wifi-custom
```

1. Re-mount the eMMC `/media/root-ro` partition as read/write
    ```bash
    $ mount -o remount,rw /dev/mmcblk0p1
    ```

    This will result in the mount being mounted `rw`

    ```bash
    $ mount | grep 'on /media/root-ro'
    /dev/mmcblk0p1 on /media/root-ro type ext4 (rw,relatime,data=ordered)
    ```

2. Copy the configuration to the eMMC `/media/root-ro` partition
    ```bash
    $ cp /etc/NetworkManager/system-connections/wifi-custom /media/root-ro/etc/NetworkManager/system-connections/
    ```

3. Sync and re-store read-only `/media/root-ro` partition
   ```bash
    $ sync
    $ mount -o remount,ro /dev/mmcblk0p1
   ```

    This will result in the mount being mounted `ro`

    ```bash
    $ mount | grep 'on /media/root-ro'
    /dev/mmcblk0p1 on /media/root-ro type ext4 (ro,relatime,data=ordered)
    ```

> This change will not be effective until after the system reboots, but a reboot is **not** necessary at this time. In the event that the backup eMMC copy is needed (due to an NVMe failure) the system will have already rebooted itself.

## 3: Copy the `NetworkManager` configuration to the recovery SD Card

Now we will copy the configuration that was created in step 1 to the "recovery" SD card drive, that is used in the event that booting from the eMMC is not possible. This will ensure that the custom Wifi connection will be used when the system is in "recovery" mode.

For these steps we will use the following example configuration:

```bash
root@ws-nxcore-000048B02D0766BE:/media/root-rw/overlay/etc/NetworkManager/system-connections# ls -la wifi-custom
-rw------- 1 root root 466 May 18 22:45 wifi-custom
```

1. Ensure the system is currently booted in normal mode

    See ["Switching to Recovery Mode" guide](./03_switch_to_recovery.md) for details.

    > The "Boot mode" should be listed as "Normal". If it is not, then the system is not in the correct state to proceed.

2. Ensure the SD card drive is available
    ```bash
    $  lsblk /dev/mmcblk1p1
    NAME      MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
    mmcblk1p1 179:1    0  10G  0 part
    ```

    > If the above command fails, the system is not in the correct state to proceed.

3. Mount the recovery operating system partition
    ```bash
    $ mkdir /tmp/sdcard
    $ mount /dev/mmcblk1p1 /tmp/sdcard
    ```

4. Copy the configuration to the SD card `/tmp/sdcard` partition
    ```bash
    $ cp /etc/NetworkManager/system-connections/wifi-custom /tmp/sdcard/etc/NetworkManager/system-connections/
    ```

5. Sync and unmount the `/tmp/sdcard` partition
   ```bash
    $ cd
    $ sync
    $ umount /tmp/sdcard
   ```

> This change will be effective the next time the system boots in "recovery" mode.
