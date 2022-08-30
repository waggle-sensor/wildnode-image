************************************************************************
                               Linux for Tegra
                                 Secureboot
                                   README
************************************************************************

The NVIDIA Tegra Linux Driver Package provides boot security using the
Secureboot package. Secureboot prevents execution of unauthorized boot
codes through chain of trust. The root-of-trust is on-die bootROM code
that authenticates boot codes such as BCT, bootloader, and warmboot
vector using Public Key Cryptography (PKC) stored in write-once-read-
multiple fuse devices.

The contents of this README include:
- Fuses and Security
- Overall Fusing and Signing Binaries
- Installing the L4T Package
- Generating the RSA Key Pair
- Preparing the DK(KEK)/SBK/ODM Fuses
- Burning PKC [DK(KEK)/SBK] Fuses using a Private Key
- Signing Boot Files
- Preparing Uboot
- Flashing with Signed Boot File Binaries
- Accessing the Fuse from the Target
- Burning Jetson Device Fuses in a Factory Environment
- Flashing Jetson Device firmware in a Factory Environment

========================================================================
Fuses and Security
========================================================================
Tegra devices contain multiple fuses that control different items for
security and boot. Programming a fuse, such as changing a value of a
fuse bit from 0 to 1, is non-reversible. Once a fuse bit is programmed
by setting to 1, you cannot change the fuse value from 1 to 0.
For example, a value of 1(0x01) can be changed to 3(0x03) or 5(0x5),
but not to 4(0x4) because the bit 0 is already programmed to 1.

Once odm_production_mode is fused with value of 0x1, all further
fuse write requests are blocked and the fused values are available
through the provided Tegra API. However, the odm_reserved and
odm_lock fields still are writable until the corresponding odm_lock bit
is programmed by changing the value of the bit from 0 to 1.

Although Tegra fuses are writable, you must use the odmfuse.sh script to
perform the fuse for the following:
- public_key_hash
- pkc_disable (T210 only)
- secure_boot_key
- odm_production_mode

Example fuses handled by L4T secureboot are as follows:

  For T210,
    +-------+---------------------+-----------------------------------+
    |bitsize| name                | default value set by odmfuse.sh   |
    +-------+---------------------+-----------------------------------+
    |      1| odm_production_mode | 0x1                               |
    |       |                     |                                   |
    |    256| public_key_hash     | RSA Public Key Hash               |
    |       |                     |                                   |
    |      1| pkc_disable         | PKC - 0x0, NS - 0x1               |
    |       |                     |                                   |
    |    128| secure_boot_key     | Secure Boot Key (SBK)             |
    |       |                     | AES encryption key for other      |
    |       |                     | security applications. If no      |
    |       |                     | other security application is     |
    |       |                     | used, leave it untouched.         |
    |     32| device_key          | Device key for other security     |
    |       |                     | applications. If no other         |
    |       |                     | security applications are         |
    |       |                     | used, leave it untouched.         |
    +-------+---------------------+-----------------------------------+

  For T186 and T194,
    +-------+---------------------+-----------------------------------+
    |bitsize| name                | default value set by odmfuse.sh   |
    +-------+---------------------+-----------------------------------+
    |      1| odm_production_mode | 0x1                               |
    |       |                     |                                   |
    |    256| public_key_hash     | RSA Public Key Hash               |
    |       |                     |                                   |
    |    128| secure_boot_key     | Secure Boot Key (SBK)             |
    |       |                     | AES encryption key for encrypting |
    |       |                     | bootloader.                       |
    |    128| Key Encryption Key 0| KEK0                              |
    |    128| Key Encryption Key 1| KEK1                              |
    |    256| KEK256 = KEK0 + KEK1| KEK256                            |
    |    128| Key Encryption Key 2| KEK2                              |
    |       |                     | These 12 consecture regitsters    |
    |       |                     | can be used to encode some Key    |
    |       |                     | Encryption Key and/or Key Seed,   |
    |       |                     | with different combinations of    |
    |       |                     | width. For example, KEK2 is used  |
    |       |                     | to encrypt/decrypt Encrypted Key  |
    |       |                     | Blob (EKB) when TOS is enabled.   |
    +-------+---------------------+-----------------------------------+

Fuses that are handled by the user are as follows:
    +-------+-----------------------+---------------------------------+
    |bitsize| name                  | function                        |
    +-------+-----------------------+---------------------------------+
    |      1| jtag_disable          | 0x1 - disable JTAG.             |
    |       |                       |                                 |
    |    256| odm_reserved          | Progammable fuses at the users  |
    |       |                       | discretion. However, 32 MSB     |
    |       |                       | are reserved for NVIDIA use.    |
    |       |                       | T210 only option.               |
    |     32| odm_reserved[0-7]     | Progammable fuses at the users  |
    |       |                       | discretion. T186 and T194 only. |
    |     32| odm_reserved[8-11]    | Progammable fuses at the users  |
    |       |                       | discretion. T194 only.          |
    |      4| odm_lock              | Each bit set disables write for |
    |       |                       | corresponding 32bit odm fuses.  |
    |       |                       | i.e. 0x2 locks b32-b63 of       |
    |       |                       | odm_reserved. 4bit for T210,    |
    |       |                       | 8bit for T186, 12bit for T194   |
    |     14| sec_boot_dev_cfg      | Depending on sec_boot_dev_sel,  |
    |       |                       | each bit has different meaning. |
    |      8| sw_reserved           | [2-0] sec_boot_dev_sel          |
    |       |                       |       Valid if and only if the  |
    |       |                       |       ignore_dev_sel_straps is  |
    |       |                       |       enabled: 0-eMMC 2-SPI     |
    |       |                       | [3  ] ignore_dev_sel_straps     |
    |       |                       |       Ignore "boot strap"       |
    |       |                       | [4  ] enable_charger_detect     |
    |       |                       | [5  ] enable_watchdog           |
    |       |                       | [7-6] reserved                  |
    +-------+-----------------------+---------------------------------+
For details on hardware fuses and fuse names, consult the following documents:
- NVIDIA Jetson TX1 Fuse Specification Application Note DA-08191-001_v04
- NVIDIA Jetson TX2 Fuse Specification Application Note DA-08415-001_v1.1
- NVIDIA Jetson AGX Xavier Fuse Specification Application Note DA-09342-001_v1.0

NOTE: For Jetson Nano Production Module, consult Jetson TX1 documents.
      For Jetson Xavier NX production module, consult Jetson AGX Xavier documents.

The fuse name aliases recognized by tegraflash are as follows:
  For T210,
    +-----------------------------+-----------------------------------+
    |Name                         | Tegraflash Alias                  |
    +-----------------------------+-----------------------------------+
    | odm_production_mode         | SecurityMode                      |
    | public_key_hash             | PublicKeyHash                     |
    | pkc_disable                 | PkcDisable                        |
    | secure_boot_key             | SecureBootKey                     |
    | device_key                  | DeviceKey                         |
    | jtag_disable                | JtagDisable                       |
    | odm_reserved                | ReservedOdm                       |
    | odm_lock                    | OdmLock                           |
    | sec_boot_dev_cfg            | SecBootDeviceSelect               |
    | sw_reserved                 | SwReserved                        |
    +-----------------------------+-----------------------------------+

  For T186 and T194,
    +-----------------------------+-----------------------------------+
    |Name                         | Tegraflash Alias                  |
    +-----------------------------+-----------------------------------+
    | odm_production_mode         | SecurityMode                      |
    | public_key_hash             | PublicKeyHash                     |
    | secure_boot_key             | SecureBootKey                     |
    | Security_Info               | BootSecurityInfo                  |
    | Key_Encryption_Key_0        | Kek0                              |
    | Key_Encryption_Key_1        | Kek1                              |
    | Key_Encryption_Key_2        | Kek2                              |
    | Key_Encryption_Key_256      | Kek256                            |
    | jtag_disable                | JtagDisable                       |
    | odm_reserve0/1/2/3/4/5/6/7  | ReservedOdm0/1/2/3/4/5/6/7        |
    | odm_reserve8/9/10/11        | ReservedOdm8/9/10/11 (T194)       |
    | odm_lock                    | OdmLock                           |
    | sec_boot_dev_cfg            | SecBootDeviceSelect               |
    | sw_reserved                 | SwReserved                        |
    +-----------------------------+-----------------------------------+

========================================================================
Overall Fusing and Signing binaries Process
========================================================================
The secure boot process with PKC (and SBK) requires:

- Install L4T secureboot package.
- If necessary, prepare DK(KEK), SBK, ODM fuse values.
- Generate RSA key-pair.
- Burn DK(KEK), ODM fuses, the PKC/SBK, Security Info and set odm_production_mode.
- Sign boot image files with PKC (and SBK).
- Flash signed boot image files.

The process of protecting the ODM production fuses without securing boot
is as follows (for T210):

- Install the L4T secureboot package
- If necessary, burn ODM fuses.
- Set ODM_PRODUCTION_MODE.
- Flash the clear boot files.

   NOTE: This process blocks ODM production fuse burning
         and protects the Tegra device from errorneous ODM
         production fuse burning.
         ODM_RESERVED and ODM_LOCK fuses are still writable
         until the ODM_LOCK bit is burned.

========================================================================
Installing the L4T Secureboot Package
========================================================================
Prerequisites
- X86 host running Ubuntu 16.04 or 18.04 LTS
- libftdi-dev for USB debug port support
- openssh-server package for OpenSSL
- Full installation of the latest L4T release on the host
  Download the latest L4T release at:
  https://developer.nvidia.com/embedded/linux-tegra-archive
- Tegra device connected to the host with Type-B micro USB cable
- Debug serial port connected to the host, if necessary

To install secureboot:
1. Download the secureboot_<release_version>.tbz2 tarball from:
   https://developer.nvidia.com/embedded/downloads

   Where <release_version> is identified in the Release Notes.

2. Untar the file by executing the command:
   tar xvjf secureboot_<release_version>.tbz2

   The tarball includes:
   - secureboot.tbz2
   - README_secureboot.txt
     This is also provided as a PDF on the L4T downloads site.

3. Untar the secureboot.tbz2 by overlaying on the L4T Board Support Package (BSP).

   Extract the file "secureboot.tbz2" onto the directory that is one level up
   from the Linux_for_Tegra/ directory on your Linux host.

   - The Linux_for_Tegra/ directory is present from installing the L4T
     Board Support Package (BSP) as a prerequisite.
   - You must be in the same directory where the Linux_for_Tegra/ directory is
     located before executing the command:

     tar xvjf secureboot.tbz2

========================================================================
Generating RSA Key Pair
========================================================================
If you want to lock fuse without PKC encryption for T210, skip this topic.
L4T secureboot requires 2048-bit RSA key-pair.

To generate a key-pair:
1. Execute the command:
   openssl genrsa -out rsa_priv.pem 2048

   Upon the successful execution, openssl generates the key file named
   rsa_priv.pem file.

2. Rename and save the key file securely and safely.

   The key file is used to burn fuse and sign boot files for Tegra devices.
   The security of your Tegra device depends on how securely you keep the
   key file.

   To ensure the security of the key file, restrict access permission to a
   minimum number of personnel.

   NOTE: To generate a truly random number key, use the Hardware
         Security Module (HSM).
         Consult the Hardware Security Module User Guide for output
         format and private key conversion to PEM format.

========================================================================
Preparing SBK key
========================================================================
If you wish to encrypt bootloader (and TOS), you must prepare SBK fuse
bits.

SBK ------------ Four 32-bit words stored in a file in big-endian HEX format.
                 For example,
                    use following sbk key file sbk.key for signing
                       0x12345678 0x9abcdef0 0xfedcba98 0x76543210

                    The representaton in fusing xml file is
                       0x123456789abcdef0fedcba9876543210

========================================================================
Preparing DK(KEKs)/ODM Fuses
========================================================================
If you wish to use another security application, you must prepare
DK(KEKs) and other ODM fuse bits as described in the user guide
for the other security application.

DK ------------- A 32-bit number stored in a file in big-endian HEX format.
                 For example: 0xddccbbaa
Applies to: Jetson TX1 device and Jetson Nano Production Module

KEK0
KEK1
KEK2 ----------- A 128-bit number stored in a file in big-endian HEX format.
                 For example: 0x112233445566778899aabbccddeeff00
Applies to: Jetson TX2, Jetson AGX Xavier, and Jetson Xavier NX devices

KEK256 --------- A 256-bit number stored in a file in big-endian HEX format.
                 KEK256 is the result of KEK1 concatenated after KEK0.
Applies to: Jetson TX2, Jetson AGX Xavier, and Jetson Xavier NX devices

ODM fuse bits -- To use applictions other than Secureboot, additional ODM fuse
                 bits may be required. The specific fuse information differs
                 depending on the application being used.
                 Consult the user guide for the application being used.

NOTE: HEX numbers must be presented in BigEndian format. The leading 0x
      or 0X can be omitted. The L4T SecureBoot software converts the
      BigEndian HEX formt to the format that the Tegra device expects.
      All standard OpenSSL utilities output in BigEndian format.

========================================================================
Burning PKC[DK(KEK),SBK] fuses
========================================================================
The steps for burning fuses using a private key file
PEM format are as follows:

1. Navigate to the directory where you installed L4T.
2. Put the Tegra device into Forced Recovery Mode.
3. Burn the fuse using odmfuse.sh script.

For example:
- To fuse PKC HASH from .pem file with JTAG enabled:
  sudo ./odmfuse.sh -j -i <chip_id> -c PKC -p -k <key.pem> \
  [-D <DK file> | --KEK{0-2} <KEK file>] [-S <SBK file>] <device_name>

- To fuse PKC HASH from .pem file with JTAG disabled:
  sudo ./odmfuse.sh -i <chip_id> -c PKC -p -k <key.pem> \
  [-D <DK file> | --KEK{0-2} <KEK file>] [-S <SBK file>] <device_name>

- To protect odm production fuse with JTAG enabled (for T210):
  sudo ./odmfuse.sh -j -i <chip_id> -c NS -p <device_name>

- To protect odm production fuse with JTAG disabled (for T210):
  sudo ./odmfuse.sh -i <chip_id> -c NS -p <device_name>

  Where <chip_id> is:
            - Jetson TX1: 0x21
            - Jetson Nano Production Module: 0x21
            - Jetson TX2: 0x18
            - Jetson AGX Xavier: 0x19
            - Jetson Xavier NX: 0x19
        <device_name> is:
            - Jetson TX1: jetson-tx1
            - Jetson Nano Production Module: jetson-nano-emmc
            - Jetson TX2: jetson-tx2
            - Jetson AGX Xavier: jetson-xavier
            - Jetson Xavier NX: jetson-xavier-nx-devkit-emmc


  Odmfuse.sh Extra Options
  ------------------------
  For odmfuse.sh, other than PKC key and ODM_PRODUCTION_MODE fuses, odmfuse.sh
  allows you to program ODM fuses that are completely under your discretion.
  Skip this topic if you do not plan to modify these fuses.

  The odmfuse.sh options that blow some ODM fuses are as follows:

  -d 0xXXXX     Sets sec_boot_dev_cfg=<value>&0x3fff. For detail, refer to TRM.

  -j            Sets JTAG enabled. Unless this option is specified, the usage
                of the JTAG debugger is blocked by default.

  -l 0xXXX      Sets odm_lock=0xXXX. Setting each bit locks the corresponding
                32-bits odm_reserved.
                For T210 example, setting odmlock=0x1 locks the first 32-bit
                of the odm_reserved read only and Setting odmlock=0x5 locks
                the first and third 32-bits of the odm_reserved field read
                only and so on.
                For T186 and T194 example, setting odmlock=0x1 locks the
                odm_reserved0 read only and Setting odmlock=0x5 locks the
                odm_reserved0 and odm_reserved2 read only and so on.

  -o <value>    Sets odm_reserved=<value>. The value must be a quoted series of
                1 256-bit Big Endian HEX numbers such as:
                "0xXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX00000000"
                The last 32-bit HEX number must be 0x00000000 because these
                fuses are reserved for NVIDIA use. T210 only.

  -p            Sets ODM production mode.

  -r 0xXX       Sets sw_reserved=0xXX. The name of this fuse field is confusing,
                but the meaning is as follows:

                bit[7-6] reserved
                bit[5  ] enable_watchdog
                bit[4  ] enable_charger_detect
                bit[3  ] ignore_dev_sel_straps - Ignore "boot strap"
                bit[2-0] sec_boot_dev_sel - 0:eMMC 2:SPI

 -D <DK file>   Sets the Device Key that will be used by the high level security
 Applies to:    application to encrypt the application keys.  The content of the
 Jetson TX1     <DK file> must be single 32-bit big-endian HASH in HEX format.

 -S <SBK file>  Sets the Secure Boot Key that will encrypt bootloader and TOS.
                The content of <SBK file> must be four 32-bit words in
                big-endian HEX format.

 --noburn       Prepares the fuse blob to be used repeatedly in factory floor
                where the private PKC key is not available.
                This option generates:
                <top>.../Linux_for_Tegra/fuseblob.tbz2 which is downloaded
                and untarred in:
                <top>.../Linux_for_Tegra directory of a factory host.
                Once the fuseblob.tbz2 is untarred in the Linux_for_Tegra
                directory, the fusecmd.sh in Linux_for_Tegra/booloader
                directory is used to burn fuses repeatedly instead of the
                standard odmfuse.sh.

--KEK0/1/2      Sets the Key Encryption Key that will be used by other security
<KEK0/1/2 file> application to encrypt/decrypt keys. The content of <KEK0/1/2
Applies to:     file> must be a single 128-bit big-endian HEX format.
Jetson TX2
Jetson AGX Xavier
Jetson Xavier NX

--KEK256        Sets the 256-bit Key Encryption Key in a single 256-bit
<KEK256 file>   big-endian HEX format.
Applies to:
Jetson TX2
Jetson AGX Xavier
Jetson Xavier NX

  --odm_reserved[0-7] <value>    Sets odm_reserved[0-7]=<value>.
                The value must be a 32-bit HEX numbers such as 0xXXXXXXXX.
                T186 and T194 only.
  --odm_reserved[8-11] <value>    Sets odm_reserved[8-11]=<value>.
                The value must be a 32-bit HEX numbers such as 0xXXXXXXXX.
                T194 only.


========================================================================
Signing and Flashing Boot Files in one step
========================================================================
  Use only PKC key or zero key
  ======================================================================
  1. Navigate to the directory where you installed L4T.
  2. Place the Tegra device into force recovery mode.
  3. Run command below:

   - To flash the Tegra device with PKC signed binaries:
      $ sudo ./flash.sh -u <keyfile> <device name> mmcblk0p1

   - To flash the Tegra device with zero key signed binaries:
     sudo ./flash.sh <device name> mmcblk0p1

     Where <keyfile> is rsa 2k key file
           <device name> is:
            - Jetson TX1: jetson-tx1
            - Jetson Nano Production Module: jetson-nano-emmc
            - Jetson TX2: jetson-tx2
            - Jetson AGX Xavier: jetson-xavier
            - Jetson Xavier NX: jetson-xavier-nx-devkit-emmc

  ======================================================================
  Use both PKC and SBK keys for encryption and signing (For TX2/AGX Xavier/Xavier NX)
  ======================================================================
  1. Navigate to the directory where you installed L4T.
  2. Place the Tegra device into force recovery mode.
  3. Run command below:
     For TX2:
     $ sudo BOARDID=3310 FAB=C04 ./flash.sh \
           -u <pkc_keyfile> -v <sbk_keyfile> jetson-tx2 mmcblk0p1

     For AGX Xavier:
     $ sudo BOARDID=2888 FAB=400 BOARDSKU=0001 BOARDREV=H.0 ./flash.sh \
           -u <pkc_keyfile> -v <sbk_keyfile> \
           jetson-xavier mmcblk0p1

     Where:
        <pkc_keyfile> is rsa 2k key file;
        <sbk_keyfile> is sbk key file;

     Note: both rsa key file and sbk key file must NOT be placed under
           bootloader directory.

========================================================================
Signing and Flashing Boot Files in two steps:
========================================================================
 =======================================================================
 Step 1: Sign
 =======================================================================
  Use only PKC key or zero key:
  ======================================================================
  1. Navigate to the directory where you installed L4T.
  2. Place the Tegra device into force recovery mode.

     For TX1/Nano Production Module:
     ===================================================================
     $ sudo ./flash.sh --no-flash -x 0x21 -y PKC -u <keyfile> \
         <device name> mmcblk0p1

     Where:
        <keyfile> is rsa 2k key file
        <device name> is:
        - Jetson TX1:    jetson-tx1
        - Jetson Nano Production Module: jetson-nano-emmc

     For TX2/AGX Xavier/Xavier NX:
     ===================================================================
     $ sudo ./flash.sh --no-flash -u <keyfile> <device name> mmcblk0p1

     Where:
        <keyfile> is rsa 2k key file
        <device name> is:
        - Jetson TX2:    jetson-tx2
        - Jetson AGX Xavier: jetson-xavier
        - Jetson Xavier NX: jetson-xavier-nx-devkit-emmc

  ======================================================================
  Use both PKC and SBK keys (For TX2/AGX Xavier/Xavier NX)
  ======================================================================
  1. Navigate to the directory where you installed L4T.
  2. Run following command to encrypt and sign bootloader images, and
     generate flashcmd.txt under bootloader directory:

     For TX2:
     $ sudo BOARDID=3310 FAB=C04 ./flash.sh --no-flash \
           -u <pkc_keyfile> -v <sbk_keyfile> jetson-tx2 mmcblk0p1

     For AGX Xavier:
     $ sudo BOARDID=2888 FAB=400 BOARDSKU=0001 BOARDREV=H.0 ./flash.sh \
           --no-flash -u <pkc_keyfile> -v <sbk_keyfile> \
           jetson-xavier mmcblk0p1

     Where:
        <pkc_keyfile> is rsa 2k key file;
        <sbk_keyfile> is sbk key file;

     Note: both rsa key file and sbk key file must NOT be placed under
           bootloader directory.

 =======================================================================
 Step 2: Flash
 =======================================================================
  Flash with PKC or zero key Signed Boot File Binaries:
  ======================================================================
  1. Navigate to the directory where you installed L4T.
  2. Place the Tegra device into force recovery mode.
  3. Run following commands:
      $ cd bootloader
      $ sudo bash ./flashcmd.txt

   - To flash the Tegra device with zero key signed binaries:
     sudo ./flash.sh <device name> mmcblk0p1

     Where <device name> is:
        - Jetson TX1: jetson-tx1
        - Jetson Nano Production Module: jetson-nano-emmc
        - Jetson TX2: jetson-tx2
        - Jetson AGX Xavier: jetson-xavier
        - Jetson Xavier NX: jetson-xavier-nx-devkit-emmc

  ======================================================================
  Flash with SBK and PKC encrypted and signed Boot File Binaries:
  ======================================================================
  1. Navigate to the directory where you installed L4T.
  2. Place the Tegra device into force recovery mode.
  3. Run following commands:
     $ cd bootloader
     $ sudo bash ./flashcmd.txt

========================================================================
Accessing the Fuse from the Target Board
========================================================================
The L4T secureboot package provide a means to access fuses from the target
board after it boots up.
NOTE: This script is only for debug use.

To access the fuse from the target board:
1. Copy <top>.../Linux_for_Tegra/pkc/tegrafuse.sh script to
   the ubuntu@<target IP address>.
2. To access target's fuses from the target board, login to the target board.

   - To display all the fuses:
     $ sudo ./tegrafuse.sh

========================================================================
Burning Jetson Device Fuses in a Factory Environment
========================================================================
This topic provides an example reference implementation for
burning fuses in a factory environment.

  Building the Factory Fuse Blob in Trusted Environment
  -----------------------------------------------------
  See ``Building the Massfuse Blob in Trusted Environment'' in
  README_Massfuse.txt.

  Burning the Fuse Blob in a Factory Environment
  ----------------------------------------------
  See ``Burning the Massfuse Blob'' in
  README_Massfuse.txt.

========================================================================
Flashing Jetson Device firmware in a Factory Environment
========================================================================
This topic provides an example reference implementation for
flashing signed firmware in a factory environment.

  Building the Factory Signed Firmware Blob in Trusted Environment
  ----------------------------------------------------------------
  See ``Building the Massflash Blob in Trusted Environment'' in
  README_Massflash.txt.

  Flashing the Signed Firmware Blob in a Factory Environment
  ----------------------------------------------------------
  See ``Flashing the Massflash Blob in Untrusted Environment'' in
  README_Massflash.txt.
