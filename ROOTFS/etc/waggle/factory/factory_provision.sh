#!/bin/bash -e

# The main script that should be executed to perform factory provisioning

# Print the script usage help
print_help() {
  echo """
usage: factory_provision.sh -c <config file> [-r]

Performs factory provisioning to the system based on the input config and reboots the system.

  -c : first boot config file
  -r : reboot upon script completion
  -? : print this help menu
"""
}

# Add state change to the provision state file
#  1: state file to update
#  2: message to log
log_state() {
    local file=$1
    echo "$(date): $2" >> $file
}

# Process script input arguments
REBOOT=
while getopts "c:r?" opt; do
  case $opt in
    c) CONFIG_FILE=$(realpath $OPTARG)
      ;;
    r) REBOOT=1
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

# source the helper functions
. /etc/waggle/factory/factory_utils.sh
log_init

echo "Waggle Factory Provisioning Start"
TS=$(date '+%Y%m%d-%H%M%S')

# source the configuration
echo "Factory provision configuration file [$CONFIG_FILE]"
cat $CONFIG_FILE
. "$CONFIG_FILE"

# ONLY proceed with provisioning if provisioning hasn't been started once before
if [ -f "$PROVISION_STATE_FILE" ]; then
    log_error "Error: provisioning has already been performed. See $PROVISION_STATE_FILE"
    exit 1
fi

echo "(1/6) Checking system is ready to be provisioned"
/etc/waggle/factory/system_check.sh -c $CONFIG_FILE -t $TS

log_state $PROVISION_STATE_FILE "Waggle Factory Provisioning Start"

log_state $PROVISION_STATE_FILE "$(cat $CONFIG_FILE)"

echo "(2/6) Performing system lockdown"
log_state $PROVISION_STATE_FILE "(2/6) Performing system lockdown"
/etc/waggle/factory/lockdown.sh -c $CONFIG_FILE -t $TS

echo "(3/6) Updating ramdisk (initrd)"
log_state $PROVISION_STATE_FILE "(3/6) Updating ramdisk (initrd)"
/etc/waggle/factory/create_initrd.sh -c $CONFIG_FILE -t $TS

echo "(4/6) Performing recovery sd card preparation"
log_state $PROVISION_STATE_FILE "(4/6) Performing recovery sd card preparation"
/etc/waggle/factory/sdcard_prep.sh -c $CONFIG_FILE -t $TS

echo "(5/6) Performing nvme preparation"
log_state $PROVISION_STATE_FILE "(5/6) Performing nvme preparation"
/etc/waggle/factory/nvme_overlay.sh -c $CONFIG_FILE -t $TS

# execute reboot when done
if [ -n "$REBOOT" ]; then
    echo "WARNING: rebooting system in 1 minute to complete setup"
    shutdown -r +1
fi

echo "(6/6) Waggle Factory Provisioning Finish"
log_state $PROVISION_STATE_FILE "(6/6) Waggle Factory Provisioning Finish"
