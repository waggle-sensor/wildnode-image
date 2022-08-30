#!/bin/bash -e

# Print the script usage help
print_help() {
  echo """
usage: sdcard_prep.sh -c <config file> [-t <timestamp> ]

NOTE: this script is NOT intended to be called directly.

Performs all steps to prepare the recovery SD Card. THIS IS A DESTRUCTIVE ACTION
THAT COMPLETELY ERASES AND RE-CREATES THE RECOVERY SD CARD.
 - Partition the SD card
 - rsync the current '/' (root) to the SD card
 - copy the proper kernel and kernel dtb
 - update the SD card extlinux to boot from the SD card device

  -c : first boot config file
  -t : (optional) timestamp to use when backing up files
  -? : print this help menu
"""
}

function cleanup_sdcard_prep()
{
    log "- ensure SD card is unmounted [$SDMOUNT]"
    sync
    umount $SDMOUNT || true
    rm -rf $SDMOUNT
    log "- restore kernel hung task timeout [$HUNG_TASK_SAVE]"
    echo $HUNG_TASK_SAVE > /proc/sys/kernel/hung_task_timeout_secs
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

# save the current hung task timeout for restoration in the trap
HUNG_TASK_SAVE=$(cat /proc/sys/kernel/hung_task_timeout_secs)

log "Create Recovery SD Card Start"
trap cleanup_sdcard_prep EXIT

# source the configuration
log "- config file [$CONFIG_FILE]"
. "$CONFIG_FILE"

# temporary mount point
SDMOUNT=/mnt/sdcard

# test for SD card and fail if not present
if lsblk $SD_DEVICE; then
    log "[$SD_DEVICE] found, proceeding with partitioning and formatting drive"
else
    log_error "Error: [$SD_DEVICE] not found. Exiting."
    exit 1
fi

# sanity check configuration
if ! which mkfs.${SD_FILE_SYSTEM}; then
    log_error "Error: File system [$SD_FILE_SYSTEM] not supported. Exiting."
    exit 1
fi

# sanity check the root partition size is defined
if [ -z "$SD_PART_SIZE_ROOT" ]; then
    log_error "Error: Required root partition size not specified (varible SD_PART_SIZE_ROOT')."
    exit 1
fi

# the rsync operation can take a long time and result in a kernel panic
#  increase the timeout for this operation to reduce chance of panic
log "- increase kernel hung task timeout [$SD_HUNG_TASK_TIMEOUT]"
echo $SD_HUNG_TASK_TIMEOUT > /proc/sys/kernel/hung_task_timeout_secs

log "- partition SD card [$SD_DEVICE]"
create_new_partition_table $SD_DEVICE

PART_COUNT=1
partition_and_format $SD_DEVICE $PART_COUNT $SD_PART_SIZE_ROOT $SD_FILE_SYSTEM $SD_PART_LABEL_ROOT
SD_ROOT_PART=${SD_DEVICE}p${PART_COUNT}
PART_COUNT=$((PART_COUNT+1))

if [ -n "$SD_PART_SIZE_SCRATCH" ]; then
    partition_and_format $SD_DEVICE $PART_COUNT $SD_PART_SIZE_SCRATCH $SD_FILE_SYSTEM $SD_PART_LABEL_SCRATCH
    SD_SCRATCH_PART=${SD_DEVICE}p${PART_COUNT}
fi

log "$(fdisk ${SD_DEVICE} -l)"

log "- mount the SD card root partition [$SD_ROOT_PART]"
mkdir -p $SDMOUNT
mount $SD_ROOT_PART $SDMOUNT

log "- sync the current (/) to SD card root partition [$SD_ROOT_PART]"
rsync -axHAWX --numeric-ids --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} / $SDMOUNT
log "- cleansing SD card image"
for item in "${SD_FILES_CLEAN[@]}"; do
    log "- delete: ${SDMOUNT}/${item}"
    rm -rf ${SDMOUNT}/${item}
done

log "- ensure dnsmasq (dhcp server) service will start"
# dnsmasq service will fail if the tftp directory does not exist
DNSPATH=$(cat /etc/dnsmasq.d/*.conf | grep "^tftp-root=" | cut -d"=" -f2)
mkdir -p ${SDMOUNT}/${DNSPATH}

log "- update SD card fstab file with SD card root partition [$SD_ROOT_PART]"
# the current fstab shows a mounting of the emmc, need to use the sd card partition
backup_file /${SDMOUNT}/etc/fstab $TS
old_root_device=$(awk '$2 == "/" { print $1 }' /${SDMOUNT}/etc/fstab)
sed -i "s|$old_root_device\([[:space:]]\)|${SD_ROOT_PART}\1|" /${SDMOUNT}/etc/fstab

if [ -n "$SD_PART_SIZE_SCRATCH" ]; then
    log "- add SD card scratch partition [$SD_SCRATCH_PART] to auto-mount"
    echo "# SD card scratch space" >> /${SDMOUNT}/etc/fstab
    echo "${SD_SCRATCH_PART} /media/${SD_PART_LABEL_SCRATCH} ${SD_FILE_SYSTEM} \
      defaults,nofail,x-systemd.after=local-fs-pre.target,x-systemd.before=local-fs.target 0 2" \
      >> /${SDMOUNT}/etc/fstab
fi

log "- modify the SD card extlinux to use the local kernel DTB [$KERNEL_DTB] and mount root partition read-only"
# copy a majority of the already existing extlinux.conf, adjusting the / mount (read-only) and using a local FDT file
appendline=$(grep -Eo -m 1 '^[[:blank:]]+APPEND.*' /${SDMOUNT}/boot/extlinux/extlinux.conf \
  | sed 's|\(.*\)rw\(.*\)|\1ro\2|' \
  | sed 's|\(.*\)root=/dev/mmcblk0p1\(.*\)|\1root=/dev/mmcblk1p1\2|' \
  | sed 's|^[ \t]*||')
linuxline=$(grep -Eo -m 1 '^[[:blank:]]+LINUX.*' /${SDMOUNT}/boot/extlinux/extlinux.conf | sed 's|^[ \t]*||')
initrdline=$(grep -Eo -m 1 '^[[:blank:]]+INITRD.*' /${SDMOUNT}/boot/extlinux/extlinux.conf | sed 's|^[ \t]*||')
echo """
LABEL wagglerecovery
  MENU LABEL waggle recovery kernel
  ${linuxline}
  FDT ${KERNEL_DTB}
  ${initrdline}
  ${appendline}
""" >> /${SDMOUNT}/boot/extlinux/extlinux.conf
backup_file /${SDMOUNT}/boot/extlinux/extlinux.conf $TS
sed -i 's|^DEFAULT.*|DEFAULT wagglerecovery|' /${SDMOUNT}/boot/extlinux/extlinux.conf

log "- enable overlay file system (backed by tmpfs)"
backup_file /${SDMOUNT}/etc/overlayroot.conf ${TS}
sed -i 's|overlayroot=""|overlayroot="tmpfs:recurse=0"|' /${SDMOUNT}/etc/overlayroot.conf

trap - EXIT
cleanup_sdcard_prep
log "Create Recovery SD Card Finish"
