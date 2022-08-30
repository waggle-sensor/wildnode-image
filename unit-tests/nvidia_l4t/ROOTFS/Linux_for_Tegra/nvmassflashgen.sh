#!/bin/bash -e

# Fake Nvidia L4T Mass Flash script
# creates a fake mass flash tarball with minimal contents

FLASH_DEVICE_NAME=$1

mkdir mfi_test
pushd mfi_test

# create dummy
echo """
NV3
# R32 , REVISION: 4.3
BOARDID=${BOARDID} BOARDSKU=${BOARDSKU} FAB=${FAB}
20201104192202
BYTES:78 CRC32:1808559342
""" >> qspi_bootblob_ver.txt

popd
tar cvjf mfi_${FLASH_DEVICE_NAME}.tbz2 mfi_test
