#!/bin/bash -e

# Fake NVidia L4T installation script
# installs fake files into the root file system in folder `rootfs`

echo "L4T: copy L4T test files into rootfs"
cp -rf ./l4t_test_files/* ./rootfs/

echo "Test NVidia L4T Installed!"
