#!/bin/bash -e

# Print the script usage help
print_help() {
  echo """
usage: system_check.sh -c <config file> [-t <timestamp>]

NOTE: this script is NOT intended to be called directly.

Performs a check of the system to determine if it's ready for factory provisioning.
Returns success (0) if the system is ready, else an error code (non-0).

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

log "Waggle System Check Start"

# source the configuration
log "- config file [$CONFIG_FILE]"
. "$CONFIG_FILE"

# check that the external storage devices exist
for dev in "${CHECK_DEVICES[@]}"; do
    log "- check device [$dev]"
    if [ ! -b ${dev} ]; then
        log_error "- FAIL: required device [$dev] not found"
        exit 1
    fi
done

# check the unique node ID exists
for file in "${CHECK_NODEID_FILES[@]}"; do
    log "- check node ID file [$file]"
    if [ ! -f ${file} ]; then
        log_error "- FAIL: required node ID file [$file] not found"
        exit 1
    fi
done

# check that the registration credentials do exist
for file in "${CHECK_REG_FILES[@]}"; do
    log "- check registration file [$file]"
    if [ ! -f ${file} ]; then
        log_error "- FAIL: registration file [$file] not found."
        exit 1
    fi
done

# check the secret private keys do NOT exist
for file in "${CHECK_KEY_FILES[@]}"; do
    log "- check private key file [$file]"
    if [ -f ${file} ]; then
        log_error "- FAIL: private key file [$file] must NOT exist"
        exit 1
    fi
done

log "Waggle System Check Finish"
