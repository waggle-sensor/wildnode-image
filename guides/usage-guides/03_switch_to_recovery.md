# Switching To and From Recovery Mode

**Table of Contents**
- [Switching To and From Recovery Mode](#switching-to-and-from-recovery-mode)
- [Identify current operating mode](#identify-current-operating-mode)
- [Nvidia's "bootloader scoreboard" control via `nvbootctrl`](#nvidias-bootloader-scoreboard-control-via-nvbootctrl)
- [Switching from Recovery mode to Normal mode](#switching-from-recovery-mode-to-normal-mode)
- [Switching from Normal mode to Recovery mode](#switching-from-normal-mode-to-recovery-mode)

The Waggle node can boot in 2 modes:
1. Normal (eMMC): the primary boot mode that enables all functionality
2. Recovery (SD card): a recovery boot mode, only intended to provide remote access to the node

The following are the steps to identify what mode the node is currently operating in and how to switch modes.

# Identify current operating mode

During system boot the Message of The Day (MOTD) will print the current running mode of the system. But you can also identify the current running mode by running the following command.

```bash
$ /etc/update-motd.d/05-waggle | grep "Boot mode"
```

Normal mode:
```bash
VSN:         	W030	Boot mode: 	Normal
```

Recovery mode:
```bash
VSN:         	W030	Boot mode: 	Recovery
```

> You can reference the source code of `/etc/update-motd.d/05-waggle` for details on how the boot mode is determined.

# Nvidia's "bootloader scoreboard" control via `nvbootctrl`

The `nvbootctrl` command can be used to read the `SMD` partition to read the current Nvidia "bootloader scoreboard" and to change the desired boot mode in future boots.

The following command will show the "bootloader scoreboard":

```bash
$ nvbootctrl dump-slots-info
magic:0x43424e00,             version: 3             features: 3             num_slots: 2
slot: 0,             priority: 15,             suffix: _a,             retry_count: 7,             boot_successful: 1
slot: 1,             priority: 14,             suffix: _b,             retry_count: 7,             boot_successful: 1
```

The above example outlines the following
- slot 0 (Boot option 'A' or 'Normal' mode) is the first option in future boots (highest priority: `15`) and has booted on the first try (max `retry_count` of `7`)
- slot 1 (Boot option 'B' or 'Recovery' mode) is the alternate option in future boots (lower priority: `14`) and the last time it booted on first try (max `retry_count` of `7`)

# Switching from Recovery mode to Normal mode

Ensure the device is currently running in recovery mode and that the normal eMMC drive is available.

1. Using the above steps ensure the system is running in "Recovery" mode

2. Ensure the eMMC drive is available

    ```bash
    $ lsblk /dev/mmcblk0p1
    NAME      MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
    mmcblk0p1 179:33   0  10G  0 part /media/root-ro
    ```

3. Identify the current "bootloader scoreboard", ensure it is currently set to boot slot 1 ("recovery")

    ```bash
    $ nvbootctrl dump-slots-info
    magic:0x43424e00,             version: 3             features: 3             num_slots: 2
    slot: 0,             priority: 14,             suffix: _a,             retry_count: 7,             boot_successful: 1
    slot: 1,             priority: 15,             suffix: _b,             retry_count: 7,             boot_successful: 1
    ```

    > **Caution**: "slot 1" should have the highest priority. If this is not true, then the system should already be booted in "Normal" mode.

4. Program the NVidia bootloader to boot from "slot 0" ("normal") on the next boot

    ```bash
    $ nvbootctrl set-active-boot-slot 0
    ```

5. Verify the "bootloader scoreboard" has changed and has "slot 0" as the highest priority

    ```bash
    $ nvbootctrl dump-slots-info
    magic:0x43424e00,             version: 3             features: 3             num_slots: 2
    slot: 0,             priority: 15,             suffix: _a,             retry_count: 7,             boot_successful: 1
    slot: 1,             priority: 14,             suffix: _b,             retry_count: 7,             boot_successful: 1
    ```

6. Reboot the system to switch boot modes

    ```bash
    $ reboot
    ```

7. Validate the system is booted in the desired operating mode

# Switching from Normal mode to Recovery mode

Ensure that the device is currently running in normal mode and that the recovery SD card drive is available.

1. Using the above steps ensure the system is running in "Normal" mode

2. Ensure the SD Card drive is available

    ```bash
    $  lsblk /dev/mmcblk1p1
    NAME      MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
    mmcblk1p1 179:1    0  10G  0 part
    ```

3. Identify the current "bootloader scoreboard", ensure it is currently set to boot slot 0 ("normal")

    ```bash
    $ nvbootctrl dump-slots-info
    magic:0x43424e00,             version: 3             features: 3             num_slots: 2
    slot: 0,             priority: 15,             suffix: _a,             retry_count: 7,             boot_successful: 1
    slot: 1,             priority: 14,             suffix: _b,             retry_count: 7,             boot_successful: 1
    ```

    > **Caution**: "slot 0" should have the highest priority. If this is not true, then the system should already be booted in "Recovery" mode.

4. Program the NVidia bootloader to boot from "slot 1" ("recovery") on the next boot

    ```bash
    $ nvbootctrl set-active-boot-slot 1
    ```

5. Verify the "bootloader scoreboard" has changed and has "slot 1" as the highest priority

    ```bash
    $ nvbootctrl dump-slots-info
    magic:0x43424e00,             version: 3             features: 3             num_slots: 2
    slot: 0,             priority: 14,             suffix: _a,             retry_count: 7,             boot_successful: 1
    slot: 1,             priority: 15,             suffix: _b,             retry_count: 7,             boot_successful: 1
    ```

6. Reboot the system to switch boot modes

    ```bash
    $ reboot
    ```

7. Validate the system is booted in the desired operating mode
