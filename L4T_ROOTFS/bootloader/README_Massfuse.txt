************************************************************************
                               Linux for Tegra
                                  Massfuse
                                   README
************************************************************************

The NVIDIA Tegra Secureboot Package provides ``massfuse'' tools to fuse
multiple Jetson devices simultaneously. This document describes detailed
procedure of ``massfusing''. Refer to README_secureboot.txt for detailed
definition of fuse and security.

The massfusing tool generates ``massfuse blob'' in trusted environment.
The massfuse blob is portable binary fuse and tool files, which are used
to fuse one or more Jetson devices simultaneously in insecure place such
as factory floor without revealing any SBK or PKC key files in human
readable form.


========================================================================
Building the Massfuse Blob in Trusted Environment
========================================================================
There are 2 methods to build the massfuse blob: ONLINE and OFFLINE.
The ONLINE method requires the target Jetson device attached to the host
and the OFFLINE method requires knowledge of actual specification of
target device.

  Building the Massfuse Blob with ONLINE method
  ---------------------------------------------
   Building the massfuse blob with ONLINE method requires:
   - Set up a X86 Linux host as the ``key host'' in safe location.
     See ``Installing the L4T Secureboot Package'' in README_secureboot.txt
     for details.
   - Generate the RSA Key-pair
     See ``Generating the RSA Key Pair'' in README_secureboot.txt
     for details.
   - If necessary, prepare the DK(KEK)/SBK/ODM fuses
     See ``Preparing the DK(KEK)/SBK/ODM Fuses'' in README_secureboot.txt
     for details.

   To generate the massfuse blob with ONLINE method:

   - Enter the command `cd Linux_for_Tegra`.
   - connect one target Jetson device, and put it into RCM mode.
   - ./nvmassfusegen.sh <odm fuse options> <device_name>
     See ``Burning PKC[DK(KEK),SBK] fuses'' in README_secureboot.txt
     for details of <odm fuse options>

   Examples for ONLINE massfuse blob generation method:
     To fuse PKC HASH from .pem file with JTAG enabled:
       sudo ./nvmassfusegen.sh -j -i <chip_id> -c PKC -p -k <key.pem> \
       <device_name>

     To fuse PKC HASH from .pem file with JTAG disabled:
       sudo ./nvmassfusegen.sh -i <chip_id> -c PKC -p -k <key.pem> \
       <device_name>

     To fuse SBK key and PKC HASH with JTAG enabled:
       sudo ./nvmassfusegen.sh -j -i <chip_id> -c SBKPKC -p -k <key.pem> \
       [-D <DK file> | --KEK{0-2} <KEK file>] -S <SBK file> \
       <device_name>

     To fuse SBK key and PKC HASH with JTAG disabled:
       sudo ./nvmassfusegen.sh -i <chip_id> -c PKC -p -k <key.pem> \
       [-D <DK file> | --KEK{0-2} <KEK file>] -S <SBK file> \
       <device_name>

     To protect odm production fuse with JTAG enabled:
       sudo ./nvmassfusegen.sh -j -i <chip_id> -c NS -p <device_name>

     To protect odm production fuse with JTAG disabled:
       sudo ./nvmassfusegen.sh -i <chip_id> -c NS -p <device_name>

     Where `<device_name>` is one of supported jetson devices:
     jetson-tx1, jetson-tx2, jetson-xavier, jetson-nano-emmc, and
     jetson-xavier-nx-devkit-emmc.

     NOTE: The portable massfuse blob is named as:
           mfuse_<device_name>.tbz2 for non-secureboot,
           mfuse_<device_name>_signed.tbz2 for PKC secureboot,
           mfuse_<device_name>_encrypt_signed.tbz2 for SBKPKC secureboot.

     NOTE: SBKPKC mode is only supported by jetson-tx2, jetson-xavier, and
           jetson-xavier-nx-devkit-emmc.

     NOTE: For detailed information about <key.pem>, <SBK file>, and
           <KEK file>, see README_secureboot.txt

  Building the Massfuse Blob with OFFLINE method
  ----------------------------------------------
   Building the massfuse blob with OFFLINE method requires:
   Same as ONLINE method. See ``Building the Massfuse Blob with ONLINE
   method'' above.

   To generate the massfuse blob with OFFLINE method:

   - Enter the command `cd Linux_for_Tegra`.
   - No actual jetson device attachment is necessary.
   - Just add ``BOARDID=<boardid> BOARDSKU=<sku> FAB=<fab>'' in front of
     ``./nvmassfusegen.sh'' as in ONLINE method:
     BOARDID=<boardid> BOARDSKU=<sku> FAB=<fab> \
     FUSELEVEL=fuselevel_production ./nvmassfusegen.sh \
     <odm fuse options> <device_name>
   Where actual values are:
                                       BOARDID    BOARDSKU    FAB
     --------------------------------+----------+-----------+------------
      jetson-tx1                       2180       0000        400
      jetson-tx2                       3310       1000        B02
      jetson-xavier                    2888       0001        400
      jetson-nano-emmc                 3448       0002        200
      jetson-xavier-nx-devkit-emmc     3668       0001        100
     --------------------------------+----------+-----------+------------

   NOTE: All input and output are exactly same as ONLINE method.

   Examples for OFFLINE massfuse blob generation method:
     To fuse PKC HASH from .pem file with JTAG enabled:
       sudo BOARDID=3448 BOARDSKU=0002 FAB=200 FUSELEVEL=fuselevel_production \
       ./nvmassfusegen.sh -j -i 0x21 -c PKC -p -k <key.pem> \
       jetson-nano-emmc

     To fuse PKC HASH from .pem file with JTAG disabled:
       sudo BOARDID=3310 BOARDSKU=1000 FAB=B02 FUSELEVEL=fuselevel_production \
       ./nvmassfusegen.sh -i 0x18 -c PKC -p -k <key.pem> \
       jetson-tx2

     To fuse SBK key and PKC HASH with JTAG enabled:
       sudo BOARDID=2888 BOARDSKU=0001 FAB=400 FUSELEVEL=fuselevel_production \
       ./nvmassfusegen.sh -j -i 0x19 -c SBKPKC -p -k <key.pem> \
       [-D <DK file> | --KEK{0-2} <KEK file>] -S <SBK file> \
       jetson-xavier

     To fuse SBK key and PKC HASH with JTAG disabled:
       sudo BOARDID=3668 BOARDSKU=0001 FAB=100 FUSELEVEL=fuselevel_production \
       ./nvmassfusegen.sh -i 0x19 -c PKC -p -k <key.pem> \
       [-D <DK file> | --KEK{0-2} <KEK file>] -S <SBK file> \
       jetson-xavier-nx-devkit-emmc

     To protect odm production fuse with JTAG enabled:
       sudo BOARDID=2180 BOARDSKU=0 FAB=400 FUSELEVEL=fuselevel_production \
       ./nvmassfusegen.sh -j -i 0x21 -c NS -p jetson-tx1

     To protect odm production fuse with JTAG disabled:
       sudo BOARDID=2180 BOARDSKU=0 FAB=400 FUSELEVEL=fuselevel_production \
       ./nvmassfusegen.sh -i 0x21 -c NS -p jetson-tx1


========================================================================
Burning the Massfuse Blob
========================================================================
Burning the massfuse blob in untrusted environment requires:
- Set up one or more X86 Linux hosts as ``fusing hosts''.
  The fusing hosts do not require any L4T BSP installation.
- Use the following procedure to burn the fuses of one or more jetson
  devices simultaneously.
- Following procedure must be performed on each fusing hosts.

1. Download mfuse_<device_name>[[_encrypt]_signed].tbz2 to each fusing host.

   Example:
   ubuntu@ahost:~$ scp loginname@<key host ipaddr>:Linux_for_Tegra/mfuse_jetson_tx1_signed.tbz2
   loginname@<master host ipaddr?'s password:
   mfuse_jetson_tx1_signed.tbz2        100% 1024KB   1.0MB/s   00:00

2. Untar mfuse_<device_name>[[_encrypt]_signed].tbz2 image:

   Example:
   - tar xvjf mfuse_jetson_tx1_signed.tbz2

3. Change directory to the massfuse blob directory.

   Example:
   - cd mfuse_jetson_tx1_signed

4. Fuse multiple Jetson devices simultaneously:

   - Connect the Jetson devices to fusing hosts.
     (Make sure all devices are in exactly the same hardware revision as
     prepared in ``Building Massfuse Blob'' section above: Especially
     SKU, FAB, BOARDREV, etc... )
   - Put all of connected Jetsons into RCM mode.
   - Enter: `sudo ./nvmfuse.sh [--showlogs]`

     NOTE: nvmfuse.sh saves all massfusing logs in mfuselogs
           directory in mfuse_<device_name>[[_encrypt]_signed].
           Each log name has following format:
           ``<hostname>_<timestamp>_<pid>_fuse_<USB_path>.log''

     NOTE: This procedure can be repeated and all the boards burned
           with same massfuse blob have exactly same fuse configurations.
