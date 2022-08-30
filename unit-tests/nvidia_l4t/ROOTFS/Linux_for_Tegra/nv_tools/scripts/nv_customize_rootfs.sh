# Test script for the NetworkManager-wait-online.service test

# Disabling NetworkManager-wait-online.service for Bug 200290321
echo "Disabling NetworkManager-wait-online.service"
if [ -h "${LDK_ROOTFS_DIR}/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service" ]; then
  rm "${LDK_ROOTFS_DIR}/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service"
fi
