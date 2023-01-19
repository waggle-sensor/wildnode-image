#!/bin/bash -e
#
# Performs first boot configuration of the system based on input configuration file
#  - sets up the system partition
#  - sets up the plugin partition

# Print the script usage help
print_help() {
  echo """
usage: nvme_overlay.sh.sh -c <config file> [-t <timestamp> ]

NOTE: this script is NOT intended to be called directly.

Performs all steps to prepare the NVMe media. THIS IS A DESTRUCTIVE ACTION
THAT COMPLETELY ERASES AND RE-CREATES THE NVMe partition layout.
 - Partition the NVMe
 - Create overlay file system (emmc: read-only lower layer, nvme: r/w upper layer)
 - Move Docker files from emmc to NVMe partition
 - Setup K3s files on NVMe partition & enable K3s service

  -c : first boot config file
  -t : (optional) timestamp to use when backing up files
  -? : print this help menu
"""
}

function cleanup_nvme_overlay()
{
    log "- ensure NVMe is unmounted [$NVMEMOUNT]"
    sync
    umount $NVMEMOUNT || true
    rm -rf $NVMEMOUNT
}

# Process script input arguments
while getopts "c:t:?" opt; do
  case $opt in
    c) CONFIG_FILE=$(realpath $OPTARG)
      ;;
    t) TS=$OPTARG
      ;;
    ?|*)
      print_help
      exit 1
      ;;
  esac
done

if [ -z "$CONFIG_FILE" ]; then
    echo "Error: config file is required. Exiting."
    print_help
    exit 1
fi

if [ -z "$TS" ]; then
    TS=$(date '+%Y%m%d-%H%M%S')
fi

# source the helper functions
. /etc/waggle/factory/factory_utils.sh
log_init

log "Prepare External NVMe Start"
trap cleanup_nvme_overlay EXIT

# source the configuration
log "- config file [$CONFIG_FILE]"
. "$CONFIG_FILE"

# temporary mount point
NVMEMOUNT=/mnt/nvme

# only proceed if the block device is online
if lsblk $NVME_DEVICE; then
    log "[$NVME_DEVICE] found, proceeding with partitioning and formatting drive"
else
    log_error "Error: [$NVME_DEVICE] not found. Exiting."
    exit 1
fi

# sanity check configuration
if ! which mkfs.${NVME_FILE_SYSTEM}; then
    log_error "Error: File system [$NVME_FILE_SYSTEM] not supported. Exiting."
    exit 1
fi

# wipe the drive and create partition table
log "- create new partition table [$NVME_DEVICE]"
create_new_partition_table $NVME_DEVICE

PART_COUNT=1

# prepare the SWAP partition
if [ -n "$NVME_PART_SIZE_SWAP" ]; then
    log "- create SWAP partition [$NVME_PART_SIZE_SWAP]"
    # create new swap partition (number $PART_COUNT, default starting (first sector),
    #  sezie $NVME_PART_SIZE_SWAP, of type swap (19))
    (echo "n";
     echo "${PART_COUNT}";
     echo "";
     echo "+${NVME_PART_SIZE_SWAP}";
     echo "t";
     echo "19";
     sleep 5s;
     echo "w"
    ) | fdisk --wipe always --wipe-partitions always $NVME_DEVICE

    partprobe $NVME_DEVICE

    SWAP_DEVICE=${NVME_DEVICE}p${PART_COUNT}
    PART_COUNT=$((PART_COUNT+1))

    wait_for_partition $SWAP_DEVICE
    mkswap $SWAP_DEVICE -L $NVME_PART_LABEL_SWAP

    # update the fstab with the new swap space
    backup_file /etc/fstab $TS
    echo "# nvme swap" >> /etc/fstab
    echo "$SWAP_DEVICE swap swap defaults,nofail,pri=100 0 0" >> /etc/fstab
fi


# prepare the Root Backup partition
# Note: this is unmounted in fstab on purpose and only necessary in recovery mode
if [ -n "$NVME_PART_SIZE_BACKUP" ]; then
    log "- create the root backup storage partition [$NVME_PART_SIZE_BACKUP]"
    partition_and_format $NVME_DEVICE $PART_COUNT $NVME_PART_SIZE_BACKUP $NVME_FILE_SYSTEM $NVME_PART_LABEL_BACKUP
    PART_COUNT=$((PART_COUNT+1))
fi

# prepare the SYSTEM partition
# Note: this assumes the initrd already supports overlayroot
if [ -n "$NVME_PART_SIZE_SYSTEM" ]; then
    log "- create the overlayed system data partition [$NVME_PART_SIZE_SYSTEM]"
    partition_and_format $NVME_DEVICE $PART_COUNT $NVME_PART_SIZE_SYSTEM $NVME_FILE_SYSTEM $NVME_PART_LABEL_SYSTEM
    SYSTEM_DEVICE=${NVME_DEVICE}p${PART_COUNT}
    PART_COUNT=$((PART_COUNT+1))

    # configure the overlayroot to use the system partition
    log "- enabling overlayroot to use the system partition [$SYSTEM_DEVICE]"
    backup_file /etc/overlayroot.conf ${TS}
    sed -i 's|overlayroot=""|overlayroot="device:dev='${SYSTEM_DEVICE}',timeout=180,recurse=0,swap=1"|' /etc/overlayroot.conf
else
    # when no SYSTEM partition is specified, setup for tmpfs overlay
    log "- enabling overlayroot to use tmpfs partition"
    backup_file /etc/overlayroot.conf ${TS}
    sed -i 's|overlayroot=""|overlayroot="tmpfs:recurse=0,swap=1"|' /etc/overlayroot.conf
fi

# use waggle custom entry into boot file (mount root partition read-only)
log "- update boot configuration with custom Waggle boot"
backup_file /boot/extlinux/extlinux.conf $TS
appendline=$(grep -Eo -m 1 '^[[:blank:]]+APPEND.*' /boot/extlinux/extlinux.conf | sed 's|\(.*\)rw\(.*\)|\1ro\2|' | sed 's|^[ \t]*||')
linuxline=$(grep -Eo -m 1 '^[[:blank:]]+LINUX.*' /boot/extlinux/extlinux.conf | sed 's|^[ \t]*||')
initrdline=$(grep -Eo -m 1 '^[[:blank:]]+INITRD.*' /boot/extlinux/extlinux.conf | sed 's|^[ \t]*||')
echo """
LABEL waggle
      MENU LABEL waggle kernel
      ${linuxline}
      FDT ${KERNEL_DTB}
      ${initrdline}
      ${appendline}
""" >> /boot/extlinux/extlinux.conf
sed -i 's|^DEFAULT.*|DEFAULT waggle|' /boot/extlinux/extlinux.conf

# prepare the PLUGIN partition
if [ -n "$NVME_PART_SIZE_PLUGIN" ]; then
    log "- create the plugin partition [$NVME_PART_SIZE_PLUGIN]"
    partition_and_format $NVME_DEVICE $PART_COUNT $NVME_PART_SIZE_PLUGIN $NVME_FILE_SYSTEM $NVME_PART_LABEL_PLUGIN
    PLUGIN_DEVICE=${NVME_DEVICE}p${PART_COUNT}
    PART_COUNT=$((PART_COUNT+1))

    # setup mount and use of plugin partition
    log "- enabling the plugin partition [$PLUGIN_DEVICE]"
    # prepare the mount point
    mkdir -p $NVMEMOUNT
    rm -rf ${NVMEMOUNT}/*

    # update the fstab file with the new partition
    if ! grep -q 'plugin-data' /etc/fstab; then
        backup_file /etc/fstab $TS
        echo "# plugin-data" >> /etc/fstab
        echo "${PLUGIN_DEVICE} ${NVME_PART_MOUNT_PLUGIN} ext4 defaults,nofail,x-systemd.after=local-fs-pre.target,x-systemd.before=local-fs.target 0 2" >> /etc/fstab
    fi

    log "- mount plugin partition and move docker & k3s contents"
    mount ${PLUGIN_DEVICE} ${NVMEMOUNT}

    # map the current docker data directory to the temp mount
    # ensure docker is stopped to prevent data corruption
    service docker stop
    if [ -d "/var/lib/docker" ]; then
        mv /var/lib/docker ${NVMEMOUNT}/
    else
        mkdir ${NVMEMOUNT}/docker
    fi
    # link docker to look at the new partition
    ln -s  ${NVME_PART_MOUNT_PLUGIN}/docker /var/lib/docker
    # enable the Docker service
    systemctl enable docker.service

    # start docker registry services
    if [ -n "$NXCORE" ]; then
        log "- enabling Docker mirror registries"
        mkdir -p ${NVMEMOUNT}/docker_registry/mirrors/docker
        systemctl enable waggle-registry-mirror-docker.service
        mkdir -p ${NVMEMOUNT}/docker_registry/mirrors/sage
        systemctl enable waggle-registry-mirror-sage.service

        log "- enabling Docker local registry"
        mkdir -p ${NVMEMOUNT}/docker_registry/local
        systemctl enable waggle-registry-local.service
    fi

    # configure k3s to use the NVME plugin-data partition
    service ${NVME_K3S_SERVICE} stop
    mkdir -p ${NVMEMOUNT}/k3s/etc
    if [ -d "/etc/rancher" ]; then
        mv /etc/rancher ${NVMEMOUNT}/k3s/etc
    else
        mkdir -p ${NVMEMOUNT}/k3s/etc/rancher
    fi
    if [ -d "/var/lib/kubelet" ]; then
        mv /var/lib/kubelet ${NVMEMOUNT}/k3s/
    else
        mkdir -p ${NVMEMOUNT}/k3s/kubelet
    fi
    if [ -d "/var/lib/rancher" ]; then
        mv /var/lib/rancher ${NVMEMOUNT}/k3s/
    else
        mkdir -p ${NVMEMOUNT}/k3s/rancher
    fi
    ln -s ${NVME_PART_MOUNT_PLUGIN}/k3s/etc/rancher /etc/rancher
    ln -s ${NVME_PART_MOUNT_PLUGIN}/k3s/kubelet /var/lib/kubelet
    ln -s ${NVME_PART_MOUNT_PLUGIN}/k3s/rancher /var/lib/rancher
    # enable the K3S service
    systemctl enable ${NVME_K3S_SERVICE}.service
fi

# print the partition table
log "$(fdisk ${NVME_DEVICE} -l)"

trap - EXIT
cleanup_nvme_overlay
log "Prepare External NVMe Finish"
