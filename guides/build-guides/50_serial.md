# Serial Console Access

**Table of Contents**
- [Serial Console Access](#serial-console-access)
- [Connecting to the Serial Console](#connecting-to-the-serial-console)
  - [Example Serial Output On First Boot](#example-serial-output-on-first-boot)

The Connect Tech Photon board has micro usb FTDI debug port that can be used to gain serial console access.  This is especially helpful see debug the bootloader, see flashing progress and for accessing the device when it doesn't have Internet access.

# Connecting to the Serial Console

To connect to the serial console, plug a USB cable between your Linux-based computer and the micro usb FTDI debug port (P6) (see 
[Photon Manual](https://connecttech.com/pdf/CTIM_NGX002_Manual.pdf) for details). Then execute the following command:

```
sudo screen /dev/ttyUSB0 115200
```

> Note: the `/dev/ttyUSB0` path may vary on your machine.

> Note: this serial console will work even when the Photon board is **not** powered.

## Example Serial Output On First Boot

```
[0000.024] W> RATCHET: MB1 binary ratchet value 4 is too large than ratchet level 2 from HW fuses.
[0000.033] I> MB1 (prd-version: 1.5.1.3-t194-41334769-d2a21c57)
[0000.038] I> Boot-mode: Coldboot
[0000.041] I> Chip revision : A02
[0000.044] I> Bootrom patch version : 15 (correctly patched)
[0000.049] I> ATE fuse revision : 0x200
[0000.053] I> Ram repair fuse : 0x0
[0000.056] I> Ram Code : 0x0
[0000.058] I> rst_source : 0x0
[0000.061] I> rst_level : 0x0
[0000.065] I> Boot-device: QSPI
[0000.067] I> Qspi flash params source = brbct
...
```
