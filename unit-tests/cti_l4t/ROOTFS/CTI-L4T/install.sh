#!/bin/bash -e

# Fake Connect Tech installation script
# installs fake files into the NVidia L4T

echo "CTI: copy test files into NVidia L4T"
cp -rf ./cti_test_files/* ../l4t_test_files/

echo "Call the NVidia L4T installation script"
pushd ..
./apply_binaries.sh
popd

echo "Test CTI-L4T Installed!"
