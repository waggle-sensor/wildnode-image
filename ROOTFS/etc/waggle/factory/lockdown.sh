#!/bin/bash -e

# Print the script usage help
print_help() {
  echo """
usage: lockdown.sh -c <config file> [-t <timestamp>]

NOTE: this script is NOT intended to be called directly.

Performs all steps to lockdown the system from a 'development' environment to 'production'.
 - disable serial console login
 - disable SSH access from the WAN port
 - set the production Waggle config as the default

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

log "Waggle Lockdown Start"

# source the configuration
log "- config file [$CONFIG_FILE]"
. "$CONFIG_FILE"

backup_file /etc/securetty $TS
for tty in "${LOGIN_TTY_DISABLE[@]}"; do
    log "- disable the login [$tty]"
    sed -i "s|^${tty}$|# Disabled ${tty}|" /etc/securetty
done

backup_file /etc/ssh/sshd_config $TS
for addr in "${SSH_ADDRESSES[@]}"; do
    log "- allow SSH access to [$addr]"
    echo "ListenAddress $addr" >> /etc/ssh/sshd_config
done

for user in "${LOGIN_USER_DISABLE[@]}"; do
    log "- disable the user [$user]"
    passwd -l $user
done

log "- set production firewall configuration [$FIREWALL_SYMLINK -> $FIREWALL_PROD]"
rm -f $FIREWALL_SYMLINK
ln -s $FIREWALL_PROD $FIREWALL_SYMLINK

log "- set system production configuration [$CONFIG_SYMLINK -> $CONFIG_PROD]"
rm -f $CONFIG_SYMLINK
ln -s $CONFIG_PROD $CONFIG_SYMLINK

log "- removed factory dev authorized keys [$KEYS_SYMLINK -> $KEYS_PROD]"
rm -f $KEYS_SYMLINK
ln -s $KEYS_PROD $KEYS_SYMLINK

log "Waggle Lockdown Finish"
