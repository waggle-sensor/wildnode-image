#!/bin/bash -e

function cleanup()
{
    echo "Caught SIGINT, exiting."
    exit 2
}
trap cleanup SIGINT

L4T_DIR="Linux_for_Tegra"
CTI_DIR="CTI-L4T"
WAGGLE_RPI_IMG="waggle-rpi.img"
RPI_DIR="/media/rpi"

# uses a mount point in an effort to prevent files changing during tar creation
mkdir -p /mnt/l4t
mount --bind /build/l4t/ /mnt/l4t

echo "Extracting NVidia L4T [$L4T_IMAGE]..."
pushd /mnt/l4t/
tar -x -Ipbzip2 -f $L4T_IMAGE
popd

# replace the empty extracted rootfs with the real rootfs
echo "Moving the rootfs into the L4T build directory..."
mount --bind /build/rootfs /mnt/l4t/${L4T_DIR}/rootfs

if [[ $ROOTFS == custom* ]]; then
    if [[ -z $AGENT_MODE ]]; then
        # create the RPI PXE boot image
        echo "Create the RPI PXE boot image [$WAGGLE_RPI_IMG]..."
        echo -n " - populating $WAGGLE_RPI_IMG from $RPI_DIR..."
        RPI_MNT="/mnt/rpi"
        truncate -s 4GiB $WAGGLE_RPI_IMG
        mkfs.ext4 $WAGGLE_RPI_IMG  > /dev/null 2>&1;
        mkdir -p $RPI_MNT
        mount -o loop $WAGGLE_RPI_IMG $RPI_MNT
        # ensure hidden files are included
        shopt -s dotglob
        mv /mnt/l4t/${L4T_DIR}/rootfs/$RPI_DIR/* $RPI_MNT/
        echo "done"

        echo -n " - syncing & checking file system..."
        sync
        umount $RPI_MNT
        e2fsck -fp $WAGGLE_RPI_IMG  > /dev/null 2>&1;
        echo "done"

        echo -n " - converting raw image to sparse image..."
        mv $WAGGLE_RPI_IMG $WAGGLE_RPI_IMG.raw
        # execute NVidia sparse disk maker
        /mnt/l4t/${L4T_DIR}/bootloader/mksparse --fillpattern=0 $WAGGLE_RPI_IMG.raw $WAGGLE_RPI_IMG
        mv $WAGGLE_RPI_IMG /mnt/l4t/${L4T_DIR}/bootloader/
        echo "done"
        rm -rf $RPI_MNT
    fi

    # NVidia `apply_binaries.sh` script disabled NetworkManager-wait-online.service
    # We want the NetworkManager-wait-online.service to run, so comment out NVidia's
    # disabling of the service
    echo "Allow the NetworkManager-wait-online Service to be enabled"
    pushd /mnt/l4t/${L4T_DIR}/nv_tools/scripts/
    # test the below replacement will work
    grep -q "# Disabling NetworkManager-wait-online.service for Bug 200290321" nv_customize_rootfs.sh
    cp nv_customize_rootfs.sh nv_customize_rootfs.sh.bck
    ab_match="# Disabling NetworkManager-wait-online.service for Bug 200290321.*?fi"
    ab_replace="# WAGGLE: allow NetworkManager-wait-online service\n"
    ab_commnt="<< '###WAGGLE-BLOCK-COMMENT'\n\1\n###WAGGLE-BLOCK-COMMENT"
    perl -i -pe "BEGIN{undef $/;} s/(${ab_match})/${ab_replace}${ab_commnt}/smg" nv_customize_rootfs.sh
    popd
fi

echo "Creating L4T rootfs..."
if [ -n "$PHOTON_IMAGE" ]; then
    echo "Extracting Photon [$PHOTON_IMAGE]..."
    pushd /mnt/l4t/${L4T_DIR}/
    tar -x -Ipigz -f $PHOTON_IMAGE
    popd

    # execute CTI Photon script which includes calling Nvidia script
    echo "Running CTI Photon installation script"
    pushd /mnt/l4t/${L4T_DIR}/${CTI_DIR}
    ./install.sh
    popd

    # install is complete, clean-up temporary files
    echo "Removing temporary Photon files"
    rm -rf /mnt/l4t/${L4T_DIR}/${CTI_DIR}
else
    # execute Nvidia script
    echo "Running Nvidia L4T installation script"
    pushd /mnt/l4t/${L4T_DIR}
    ./apply_binaries.sh
    popd
fi

if [ -n "$CBOOT_BIN" ]; then
  echo "Replace the stock CBoot ($CBOOT_BIN -> /mnt/l4t/${L4T_DIR}/bootloader/cboot_t194.bin)"
  cp /mnt/l4t/${L4T_DIR}/bootloader/cboot_t194.bin /mnt/l4t/${L4T_DIR}/bootloader/cboot_t194.bin.bck
  cp $CBOOT_BIN /mnt/l4t/${L4T_DIR}/bootloader/cboot_t194.bin
fi

if [[ $ROOTFS == custom* ]]; then
    # Work-around: use Waggle specific /etc/hosts and /etc/hostname (as it's overriden during L4T install)
    echo "Copy custom hosts and hostname files"
    cp -rp /output/ROOTFS/etc/hosts /mnt/l4t/${L4T_DIR}/rootfs/etc/hosts
    if [[ -z $AGENT_MODE ]]; then
        cp -rp /output/ROOTFS/etc/hostname /mnt/l4t/${L4T_DIR}/rootfs/etc/hostname
    else
        cp -rp /output/ROOTFS/etc/hostname-agent /mnt/l4t/${L4T_DIR}/rootfs/etc/hostname
    fi

    # Add docker.io registry mirror to Docker deamon (original file )
    jq '. += {"registry-mirrors": [ "http://10.31.81.1:5001" ]}' /mnt/l4t/${L4T_DIR}/rootfs/etc/docker/daemon.json > /tmp/daemon.json; \
        mv /tmp/daemon.json /mnt/l4t/${L4T_DIR}/rootfs/etc/docker/daemon.json

    # use existing block device (/dev/mmcblk0p1) in the fstab instead of virtual (/dev/root)
    # this resolves an issue where a created ramdisk (update-initramfs) can't detect
    # the file system type of (/) and is unable to load correct fsck (ext4) tools
    echo "Update /etc/fstab to use physical block device"
    cp /mnt/l4t/${L4T_DIR}/rootfs/etc/fstab /mnt/l4t/${L4T_DIR}/rootfs/etc/fstab.bck
    old_root_device=$(awk '$2 == "/" { print $1 }' /mnt/l4t/${L4T_DIR}/rootfs/etc/fstab)
    sed -i "s|$old_root_device\([[:space:]]\)|/dev/mmcblk0p1\1|" /mnt/l4t/${L4T_DIR}/rootfs/etc/fstab

    if [[ -z $AGENT_MODE ]]; then
        # add the RPI mount to the fstab (tied to local-fs.target)
        echo "Add RPI mount to /etc/fstab"
        echo "# Raspberry Pi PXE boot mount" >> /mnt/l4t/${L4T_DIR}/rootfs/etc/fstab
        echo "/dev/mmcblk0p11 $RPI_DIR ext4 defaults,nofail,ro,x-systemd.after=local-fs-pre.target,x-systemd.before=local-fs.target 0 2" >> /mnt/l4t/${L4T_DIR}/rootfs/etc/fstab
    fi

    if [[ -z $AGENT_MODE ]]; then
        # Disable the nv_update_verifier service
        pushd /mnt/l4t/${L4T_DIR}/rootfs
        if [ -h "etc/systemd/system/multi-user.target.wants/nv_update_verifier.service" ]; then
          echo "Disable nv_update_verifier service from auto-starting"
          rm "etc/systemd/system/multi-user.target.wants/nv_update_verifier.service"
        fi
        popd
    fi

    # Enable color in bash prompt
    pushd /mnt/l4t/${L4T_DIR}/rootfs
    cp root/.bashrc root/.bashrc.bck
    echo "Configure bash prompt with color"
    sed -i 's|^#force_color_prompt=\(.*\)|force_color_prompt=yes|' root/.bashrc
    popd
fi

# Bring in all L4T flashing and configuration customizations
cp -rp /output/L4T_ROOTFS/* /mnt/l4t/${L4T_DIR}/

# Use Agent Waggle Photon board config
if [[ -n $AGENT_MODE ]]; then
  echo "Use Waggle Photon (Agent) board config"
  pushd /mnt/l4t/${L4T_DIR}/
  mv waggle_photon.conf-agent waggle_photon.conf
  popd
fi

if [ -n "$PHOTON_IMAGE" ]; then
    # Build the boot order config
    echo "Create custom boot order DTB file & enable A/B redundancy"
    pushd /mnt/l4t/${L4T_DIR}
    ./kernel/dtc -I dts -O dtb -o bootloader/t186ref/cbo.dtb bootloader/cbo.dts.waggle
    ./bootloader/nv_smd_generator bootloader/smd_info.cfg bootloader/slot_metadata.bin
    popd

    # Add waggle specific target to NVidia flash script
    pushd /mnt/l4t/${L4T_DIR}
    echo "Add waggle_photon support target to NVidia flash script"
    sed -i '/"${ext_target_board_canonical}" == "p3448-0000-sd"/a \\t\t\t\t"${ext_target_board_canonical}" == "waggle_photon" ||' flash.sh
    popd
fi

# Add version information to rootfs
pushd /mnt/l4t/${L4T_DIR}/rootfs
COMPLETE_VERSION="${PROJ_VERSION} [${IMG_VERSION}]"
echo "Save image version: ${COMPLETE_VERSION}"
mkdir -p etc
echo "${COMPLETE_VERSION}" > etc/waggle_version_os
popd

# Clear the system machine-id so that on boot a unique one is created
echo "Clear machine-id"
pushd /mnt/l4t/${L4T_DIR}/rootfs
rm -rf var/lib/dbus/machine-id
echo "" > etc/machine-id
popd

if [ -n "${CREATE_DEV_TARBALL}" ]; then
    OUT_FULL_FILE=${OUTPUT_NAME}_${PROJ_VERSION}.tbz2
    echo "Create Development L4T tarball ($OUT_FULL_FILE)"
    # sync all writes to the mount
    sync -f /mnt/l4t/${L4T_DIR}
    # compress preserving permissions (multi-core)
    tar -c -Ipbzip2 -pf  /output/${OUT_FULL_FILE} -C /mnt/l4t/${L4T_DIR} .
fi

# Create the mass flash output
if [ -n "${CREATE_MASS_FLASH}" ]; then
    OUT_MF_FILE=/output/${OUTPUT_NAME}_mfi_${PROJ_VERSION}.tbz2
    echo "Create Mass Flash ($OUT_MF_FILE)"

    pushd /mnt/l4t/${L4T_DIR}
    # update the flash tool to use multi-core compression
    sed -i "s|tar cvjf|tar -c -Ipbzip2 -vf|" nvmassflashgen.sh

    BOARDID="${FLASH_BOARDID}" BOARDSKU=${FLASH_BOARDSKU} FAB=${FLASH_FAB} \
        BOARDREV=${FLASH_BOARDREV} FUSELEVEL=${FLASH_FUSELEVEL} \
        ./nvmassflashgen.sh ${FLASH_DEVICE_NAME} ${FLASH_PART}
    mv mfi_${FLASH_DEVICE_NAME}.tbz2 ${OUT_MF_FILE}
    popd
fi
