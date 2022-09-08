#!/bin/bash -ex

# Perform unit testing of the L4T image building.

TEST_ROOT=`pwd`
RESULTS_DIR=./unit-tests/results
TEST_KEY="test"

print_help() {
  echo """
usage: $0 [-e <version string>]

  Runs image building unit testing.

  -e : (optional) version extension string (default: <empty>)
  -? : print this help menu
"""
}

function test_setup()
{
  echo "Test Setup"
  pushd ./unit-tests/cti_l4t/ROOTFS/
  tar czf ../test_cti_l4t.tgz CTI-L4T/
  popd

  pushd ./unit-tests/nvidia_l4t/ROOTFS/
  tar cjf ../test_nvidia_l4t.tbz2 Linux_for_Tegra/
  popd

  pushd ./unit-tests/sample_rootfs/ROOTFS/
  tar cjf ../test_sample_rootfs.tbz2 *
  popd

  mkdir -p $RESULTS_DIR
}

function cleanup()
{
    echo "Test Cleanup"
    cd "${TEST_ROOT}"
    rm -rf ${TEST_KEY}*.tgz
    rm -rf ${TEST_KEY}*.tgz.list
    rm -rf ${TEST_KEY}*.tbz2
    rm -rf ${TEST_KEY}*.tbz2.list
    rm -rf ${RESULTS_DIR}
    rm -rf ./unit-tests/*/*.tgz
}

trap cleanup EXIT

test_setup

VERSION_EXTENSION=
while getopts "e:" opt; do
  case $opt in
    e) VERSION_EXTENSION="-e ${OPTARG}"
      ;;
    ?|*)
      print_help
      exit 1
      ;;
  esac
done

## The build can be given many options. Not all option combinations are tested
#  but instead a sub-set that gives the most coverage
#  Options:
#  - L4T only or L4T with Connect Tech L4T extension (-c option)
#  - Custom rootfs or sample rootfs (-r option)
#  - L4T provided CBoot or Custom CBoot (-b option)
#  - Create Full L4T flash support tarball (-t option) and / or 'mass flash' (-m option)
#  - Create a Photon "agent" image (-a option)
#
# The following tests will be executed to cover the above options:
# Test 01 (CTI Photon (core), shipping configuration):
#   L4T with extension, custom rootfs, custom CBoot, Mass flash
# Test 02 (CTI Photon (agent), shipping configuration):
#   L4T with extension, custom rootfs, custom CBoot, Mass flash, agent mode
# Test 03 (Nvidia stock):
#   L4T only, sample rootfs, L4T provided CBoot, Full L4T flash only

##
## Unit Test 01 (CTI Photon (core), shipping configuration):
TEST_NO="01"
echo "${TEST_NO}: L4T with extension, custom rootfs, Custom CBoot, Mass flash, Full tarball"
TEST_NAME=${TEST_KEY}${TEST_NO}
./build.sh -l ${TEST_ROOT}/unit-tests/nvidia_l4t/test_nvidia_l4t.tbz2 \
           -c ${TEST_ROOT}/unit-tests/cti_l4t/test_cti_l4t.tgz \
           -b ${TEST_ROOT}/unit-tests/cboot/cboot_test.bin \
           -o $TEST_NAME $VERSION_EXTENSION \
           -m \
           -t \
           -z

TEST_PATH=$(find ${TEST_ROOT}/${TEST_NAME}_nx*.tbz2 -type f)
TEST_MFI_PATH=$(find ${TEST_ROOT}/${TEST_NAME}_mfi*.tbz2 -type f)

echo "${TEST_NO}: Sanity Check the Resulting Image"
mkdir -p ${RESULTS_DIR}/${TEST_NAME}
pushd ${RESULTS_DIR}/${TEST_NAME}
# only extract the files we need for testing
tar -x -Ipbzip2 -f $TEST_PATH \
  ./rootfs/etc/waggle_version_os \
  ./bootloader/cboot_t194.bin \
  ./bootloader/slot_metadata.bin \
  ./rootfs/etc/hostname
tar -x -Ipbzip2 -f $TEST_MFI_PATH mfi_test/qspi_bootblob_ver.txt

# get list of files in each tarball for future tests
tar tf $TEST_PATH > $TEST_PATH.list

echo "${TEST_NO}.01: sanity the version file"
cat rootfs/etc/waggle_version_os | grep "nx-"
cat rootfs/etc/waggle_version_os | grep "kernel: test_nvidia_l4t"
cat rootfs/etc/waggle_version_os | grep "cti_kernel_extension: test_cti_l4t"
cat rootfs/etc/waggle_version_os | grep "rootfs: Waggle_Linux_Custom-Root-Filesystem"

echo "${TEST_NO}.02: sanity the rootfs (w/ CTI)"
# custom file system
grep -q ./rootfs/etc/os-release $TEST_PATH.list
# sample file system
! grep -q ./rootfs/test_sample_rootfs_file $TEST_PATH.list
# l4t base
grep -q ./rootfs/test_nvidia_l4t_file $TEST_PATH.list
# cti extension
grep -q ./rootfs/test_cti_l4t_file $TEST_PATH.list

echo "${TEST_NO}.03: sanity the test cboot"
grep -q ./bootloader/cboot_t194.bin $TEST_PATH.list
grep -q ./bootloader/cboot_t194.bin.bck $TEST_PATH.list
md5sum -c ${TEST_ROOT}/unit-tests/cboot_test.md5

echo "${TEST_NO}.04: sanity custom cboot"
grep -q ./bootloader/t186ref/cbo.dtb $TEST_PATH.list

echo "${TEST_NO}.05: sanity contents of mass flash script (photon production unit)"
grep "BOARDID=3668 BOARDSKU=0001 FAB=200" mfi_test/qspi_bootblob_ver.txt

echo "${TEST_NO}.06: sanity the RPI PXE boot image does exist"
grep -q ./bootloader/waggle-rpi.img $TEST_PATH.list

echo "${TEST_NO}.07: sanity the SMD binary is custom"
grep "CUSTOM SMD BIN FILE" ./bootloader/slot_metadata.bin

echo "${TEST_NO}.08: sanity the registration keys exist"
grep -q ./rootfs/etc/waggle/sage_registration $TEST_PATH.list
grep -q ./rootfs/etc/waggle/sage_registration-cert.pub $TEST_PATH.list
grep -q ./rootfs/etc/waggle/sage_registration.pub $TEST_PATH.list

echo "${TEST_NO}.09: sanity the hostname"
grep "ws-nxcore-prereg" ./rootfs/etc/hostname

echo "${TEST_NO}.10: sanity the 'waggle' user"
grep -q ./rootfs/etc/sudoers.d/waggle $TEST_PATH.list
grep -q ./rootfs/home/waggle/.ssh/authorized_keys $TEST_PATH.list

popd
rm -rf ${TEST_PATH}
rm -rf ${TEST_PATH}.list
rm -rf ${TEST_MFI_PATH}
rm -rf ${TEST_MFI_PATH}.list
rm -rf ${RESULTS_DIR}/${TEST_NAME}*


##
## Unit Test 02 (CTI Photon (agent), shipping configuration):
TEST_NO="02"
echo "${TEST_NO}: L4T with extension, custom rootfs, Custom CBoot, Mass flash, Full tarball, Agent mode"
TEST_NAME=${TEST_KEY}${TEST_NO}
./build.sh -l ${TEST_ROOT}/unit-tests/nvidia_l4t/test_nvidia_l4t.tbz2 \
           -c ${TEST_ROOT}/unit-tests/cti_l4t/test_cti_l4t.tgz \
           -b ${TEST_ROOT}/unit-tests/cboot/cboot_test.bin \
           -o $TEST_NAME $VERSION_EXTENSION \
           -m \
           -t \
           -a

TEST_PATH=$(find ${TEST_ROOT}/${TEST_NAME}_nx*.tbz2 -type f)
TEST_MFI_PATH=$(find ${TEST_ROOT}/${TEST_NAME}_mfi*.tbz2 -type f)

echo "${TEST_NO}: Sanity Check the Resulting Image"
mkdir -p ${RESULTS_DIR}/${TEST_NAME}
pushd ${RESULTS_DIR}/${TEST_NAME}
# only extract the files we need for testing
tar -x -Ipbzip2 -f $TEST_PATH \
  ./rootfs/etc/waggle_version_os \
  ./bootloader/cboot_t194.bin \
  ./bootloader/slot_metadata.bin \
  ./rootfs/etc/hostname
tar -x -Ipbzip2 -f $TEST_MFI_PATH mfi_test/qspi_bootblob_ver.txt

# get list of files in each tarball for future tests
tar tf $TEST_PATH > $TEST_PATH.list

echo "${TEST_NO}.01: sanity the version file"
cat rootfs/etc/waggle_version_os | grep "nxagent-"
cat rootfs/etc/waggle_version_os | grep "kernel: test_nvidia_l4t"
cat rootfs/etc/waggle_version_os | grep "cti_kernel_extension: test_cti_l4t"
cat rootfs/etc/waggle_version_os | grep "rootfs: Waggle_Linux_Custom-Root-Filesystem"

echo "${TEST_NO}.02: sanity the rootfs (w/ CTI)"
# custom file system
grep -q ./rootfs/etc/os-release $TEST_PATH.list
# sample file system
! grep -q ./rootfs/test_sample_rootfs_file $TEST_PATH.list
# l4t base
grep -q ./rootfs/test_nvidia_l4t_file $TEST_PATH.list
# cti extension
grep -q ./rootfs/test_cti_l4t_file $TEST_PATH.list

echo "${TEST_NO}.03: sanity the test cboot"
grep -q ./bootloader/cboot_t194.bin $TEST_PATH.list
grep -q ./bootloader/cboot_t194.bin.bck $TEST_PATH.list
md5sum -c ${TEST_ROOT}/unit-tests/cboot_test.md5

echo "${TEST_NO}.04: sanity custom cboot"
grep -q ./bootloader/t186ref/cbo.dtb $TEST_PATH.list

echo "${TEST_NO}.05: sanity contents of mass flash script (photon production unit)"
grep "BOARDID=3668 BOARDSKU=0001 FAB=200" mfi_test/qspi_bootblob_ver.txt

echo "${TEST_NO}.06: sanity the RPI PXE boot image does NOT exist"
! grep -q ./bootloader/waggle-rpi.img $TEST_PATH.list

echo "${TEST_NO}.07: sanity the SMD binary is custom"
grep "CUSTOM SMD BIN FILE" ./bootloader/slot_metadata.bin

echo "${TEST_NO}.08: sanity the registration keys do NOT exist"
! grep -q ./rootfs/etc/waggle/sage_registration $TEST_PATH.list
! grep -q ./rootfs/etc/waggle/sage_registration-cert.pub $TEST_PATH.list
! grep -q ./rootfs/etc/waggle/sage_registration.pub $TEST_PATH.list

echo "${TEST_NO}.09: sanity the hostname"
grep "ws-nxagent" ./rootfs/etc/hostname

echo "${TEST_NO}.10: sanity the 'waggle' user"
! grep -q ./rootfs/etc/sudoers.d/waggle $TEST_PATH.list
! grep -q ./rootfs/home/waggle/.ssh/authorized_keys $TEST_PATH.list

popd
rm -rf ${TEST_PATH}
rm -rf ${TEST_PATH}.list
rm -rf ${TEST_MFI_PATH}
rm -rf ${TEST_MFI_PATH}.list
rm -rf ${RESULTS_DIR}/${TEST_NAME}*


##
## Unit Test 03 (Nvidia stock):
TEST_NO="03"
echo "${TEST_NO}: L4T only, sample rootfs, L4T provided CBoot, Full tarball only"
TEST_NAME=${TEST_KEY}${TEST_NO}
./build.sh -l ${TEST_ROOT}/unit-tests/nvidia_l4t/test_nvidia_l4t.tbz2 \
           -r ${TEST_ROOT}/unit-tests/sample_rootfs/test_sample_rootfs.tbz2 \
           -o $TEST_NAME $VERSION_EXTENSION \
           -t

TEST_PATH=$(find ${TEST_ROOT}/${TEST_NAME}_nx*.tbz2 -type f)

echo "${TEST_NO}: Sanity Check the Resulting Image"
mkdir -p ${RESULTS_DIR}/${TEST_NAME}
pushd ${RESULTS_DIR}/${TEST_NAME}
# only extract the files we need for testing
tar -x -Ipbzip2 -f $TEST_PATH ./rootfs/etc/waggle_version_os ./bootloader/cboot_t194.bin ./bootloader/slot_metadata.bin
# ensure mass flash tarball does not exist (only 1 artifact created)
FOUND_ARTIFACTS=$(ls -1 ${TEST_ROOT}/${TEST_NAME}* | wc -l | xargs)
[[ $FOUND_ARTIFACTS -eq 1 ]]

# get list of files in each tarball for future tests
tar tf $TEST_PATH > $TEST_PATH.list

echo "${TEST_NO}.01: sanity the version file"
cat rootfs/etc/waggle_version_os | grep "kernel: test_nvidia_l4t"
cat rootfs/etc/waggle_version_os | grep "rootfs: test_sample_rootfs"

echo "${TEST_NO}.02: sanity the rootfs (based L4T w/ sample file system)"
# custom file system
! grep -q ./rootfs/etc/os-release $TEST_PATH.list
# sample file system
grep -q ./rootfs/test_sample_rootfs_file $TEST_PATH.list
# l4t base
grep -q ./rootfs/test_nvidia_l4t_file $TEST_PATH.list
# cti extension
! grep -q ./rootfs/test_cti_l4t_file $TEST_PATH.list

echo "${TEST_NO}.03: sanity the original cboot"
grep -q ./bootloader/cboot_t194.bin $TEST_PATH.list
! grep -q ./bootloader/cboot_t194.bin.bck $TEST_PATH.list
md5sum -c ${TEST_ROOT}/unit-tests/cboot_orig.md5

echo "${TEST_NO}.04: sanity no custom cboot options"
! grep -q ./bootloader/t186ref/cbo.dtb $TEST_PATH.list

echo "${TEST_NO}.05: SKIPPED (mass flash script not created)"

echo "${TEST_NO}.06: sanity the RPI PXE boot image does NOT exist"
! grep -q ./bootloader/waggle-rpi.img $TEST_PATH.list

echo "${TEST_NO}.07: sanity the SMD binary is original"
grep "ORIGINAL SMD BIN FILE" ./bootloader/slot_metadata.bin

popd
rm -rf ${TEST_PATH}
rm -rf ${TEST_PATH}.list
rm -rf ${RESULTS_DIR}/${TEST_NAME}*


echo "Test Successful!"
