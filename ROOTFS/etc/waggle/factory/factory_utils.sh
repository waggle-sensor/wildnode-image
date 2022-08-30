#!/bin/bash -e

# Helper functions for the factory provisioning scripts

# Helper logging functions to log to rsyslog
# 1: message to log
SYSLOGTAG="waggle-factory-provision"
log_init() {
    # forward all stdout/stderr output to our rsyslog
    #exec 1> >(logger -s -t "$SYSLOGTAG") 2>&1
    exec > >(exec logger -s -t "$SYSLOGTAG") 2> >(logger -p "warning" -t "$SYSLOGTAG")
}
log () {
    echo "$1" | logger -t ${SYSLOGTAG}
}
log_error() {
    echo "$1" | logger -t ${SYSLOGTAG} -p "err"
    echo "ERROR: $1"
}
log_warn() {
    echo "$1" | logger -t ${SYSLOGTAG} -p "warning"
    echo "WARNING: $1"
}

# Backup a file (if it hasn't already been backed up)
#  1: file to backup
#  2: backup string to append to backed up file
backup_file() {
    local file=$1
    local bext=$2
    bfile=$file.$bext.bck

    if [ ! -e "${bfile}" ]; then
        log "- backing up file [$file] -> [$bfile]"
        cp -p $file $bfile
    fi
}

# Wait for a partition to be ready, fail if not found within 10s
wait_for_partition() {
    local part=$1

    log "- waiting for partition [$part] to be available"
    try=0
    while [[ ! -e $part ]]; do
      try=$(( try + 1 ))
      if [ $try -gt 10 ]; then
          log_error "Error: could not locate partition [$part] after formatting [attempts: $try]. Exiting."
          exit 1
      fi
      sleep 1s
    done
}

# Add a partition to the provided device and format
#  1: device to add partition to (i.e. /dev/nvme0n1)
#  2: partition number to add
#  3: size of partition (i.e. 20G), ("ALL": the remainder of the device)
#  4: file system type to format partition as (i.e. ext4)
#  5: label to apply to partition
partition_and_format() {
    local device=$1
    local partno=$2
    local partsize=""
    if [ "$3" != "ALL" ]; then
        local partsize="+${3}"
    fi
    local fs=$4
    local label=$5

    # create new partition (number $partno, default starting (first sector), size $partsize)
    (echo "n";
     echo "${partno}";
     echo "";
     echo "${partsize}";
     sleep 5s;
     echo "w"
    ) | fdisk --wipe always --wipe-partitions always $device

    partprobe $device

    # format the the partition
    part=${device}p${partno}
    wait_for_partition $part
    log "- formatting [$part] as $fs [$partsize]"
    mkfs.${fs} $part
    if [ -n "$label" ]; then
      log "- labeling [$part] as '$label'"
      e2label $part $label
    fi
}

# Create a new GPT partition table on the provided device
#  1: device to create the new partition table on (i.e. /dev/nvme0n1)
create_new_partition_table() {
    local device=$1

    # create a new GPT partition table
    (echo "g";
     sleep 5s;
     echo "w"
    ) | fdisk --wipe always --wipe-partitions always $device
    log "- successfully created new partition table for [$device]"
}
