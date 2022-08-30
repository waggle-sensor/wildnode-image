#!/bin/bash -e

# Print the script usage help
print_help() {
  echo """
usage: create_initrd.sh -c <config file> [-t <timestamp>]

NOTE: this script is NOT intended to be called directly.

Performs all steps to re-create the ramdisk (initrd) enabling Waggle features (i.e.overlayroot)
 - backup existing initrd and replace with re-built one

  -c : first boot config file
  -t : (optional) timestamp to use when backing up files
  -? : print this help menu
"""
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

log "Update Ramdisk (initrd) Start"

# source the configuration
log "- config file [$CONFIG_FILE]"
. "$CONFIG_FILE"

log "- create new ramdisk"
backup_file /boot/initrd $TS
update-initramfs -c -k $(uname -r)
rm -f /boot/initrd
ln -s /boot/initrd.img-$(uname -r) /boot/initrd

log "Update Ramdisk (initrd) Finish"
