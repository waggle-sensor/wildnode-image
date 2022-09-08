#!/bin/bash -e

print_help() {
  echo """
usage: build.sh -l <Nvidia L4T tarball> [-c <CTI L4T tarball>] [-r <base rootfs tarball>]
    [-b <bootloader .bin file>] [-o <custom output name>] [-e <version string>] [-d] [-m] [-t] [-z] [-a]

Create the Waggle operating system for the Nvidia NX development kit or the
ConnectTech Photon NX (production) hardware ('-c' option). Produces an optional
Nvidia L4T flash support tarball (-t) and standard 'mass flash' tarball (-m).

The 'mass flash' tarball contains a portable, encrypted, and signed binary
complete firmware and flashing tools for use in flashing in a 'factory' environment.
While the Nvidia L4T system tarball includes the complete root file system
(rootfs) and all tools to flash to be used in a development environment.

Note: you *must* specific either (-m) or (-t) to produce a build artifact. Not
specifying either option will result in the build executing but not being
saved.

  -l : path to the Nvidia L4T tarball to build into the resulting rootfs.
  -c : (optional) path to the Connect Tech L4T extension tarball. Adds support
       for the Connect Tech hardware to the kernel.
  -r : (optional) path to a root file system to add the L4T kernel to.
       If not provided the rootfs will be constructed from 'Dockerfile.rootfs'.
  -b : (optional) path to the CBoot BIN file to replace in the L4T image.
  -m : (optional) create 'mass flash' tarball
  -t : (optional) create the development tarball
  -o : (optional) output filename (i.e. custom_name) (default: l4t)
  -a : (optional) when building the Photon image build the 'agent' image instead of 'core'
  -e : (optional) version extension string (default: <empty>)
  -d : don't build the image and enter debug mode within the Docker build environment.
  -z : do a full non-cached build.
  -? : print this help menu
"""
}

CMD="./create_image.sh"
OUTPUT_NAME="l4t"
NXNAME="nx"
TTY=
L4T_IMAGE=
PHOTON_IMAGE=
ROOTFS_TARBALL=
CBOOT_BIN=
CREATE_MASS_FLASH=
CREATE_DEV_TARBALL=
DOCKER_CACHE=
AGENT_MODE=
VERSION_EXTENSION=
while getopts "l:c:r:b:mto:e:dpza?" opt; do
  case $opt in
    l) L4T_IMAGE=$(realpath $OPTARG)
       L4T_IMAGE_FILE=$(basename $L4T_IMAGE)
       L4T_IMAGE_NAME="${L4T_IMAGE_FILE%.*}"
      ;;
    c) PHOTON_IMAGE=$(realpath $OPTARG)
       PHOTON_IMAGE_FILE=$(basename $PHOTON_IMAGE)
       PHOTON_IMAGE_NAME="${PHOTON_IMAGE_FILE%.*}"
      ;;
    r) ROOTFS_TARBALL=$(realpath $OPTARG)
       ROOTFS_TARBALL_FILE=$(basename $ROOTFS_TARBALL)
       ROOTFS_TARBALL_NAME="${ROOTFS_TARBALL_FILE%.*}"
      ;;
    b) CBOOT_BIN=$(realpath $OPTARG)
       CBOOT_BIN_FILE=$(basename $CBOOT_BIN)
      ;;
    m) echo "** Create Mass Flash Tarball **"
      CREATE_MASS_FLASH=1
      ;;
    t) echo "** Create Development Tarball **"
      CREATE_DEV_TARBALL=1
      ;;
    o) OUTPUT_NAME=$OPTARG
      ;;
    e) VERSION_EXTENSION=$OPTARG
      ;;
    d) # enable debug mode
      echo "** DEBUG MODE **"
      TTY="-it"
      CMD="/bin/bash"
      ;;
    z) # do a full non-cached build
      echo "** EXECUTING A FULL BUILD (no cache) **"
      DOCKER_CACHE="--no-cache"
      ;;
    a) # photon (agent) build
      echo "** Building Photon (agent) image **"
      AGENT_MODE="-agent"
      NXNAME="nxagent"
      ;;
    ?|*)
      print_help
      exit 1
      ;;
  esac
done

# create version string
PROJ_VERSION="${NXNAME}-$(git describe --tags --long --dirty | cut -c2-)"
if [ -n "$VERSION_EXTENSION" ]; then
  PROJ_VERSION=$PROJ_VERSION-$VERSION_EXTENSION
fi

echo "Build Parameters:"
echo -e " Nvidia L4T:\t${L4T_IMAGE}"
echo -e " CTI L4T BSP:\t${PHOTON_IMAGE}"
echo -e " Rootfs:\t${ROOTFS_TARBALL}"
echo -e " Nvidia CBoot:\t${CBOOT_BIN}"
echo -e " Output name:\t${OUTPUT_NAME}"
echo -e " Agent Build:\t${AGENT_MODE}"
echo -e " Version:\t${PROJ_VERSION}"

if [ -z "$L4T_IMAGE" ]; then
    echo "Error: L4T Image is required. Exiting."
    exit 1
elif [ ! -f "$L4T_IMAGE" ]; then
    echo "Error: L4T Image [$L4T_IMAGE] is NOT a valid file. Exiting."
    exit 1
fi

if [ -n "$PHOTON_IMAGE" ] && [ ! -f "$PHOTON_IMAGE" ]; then
    echo "Error: Connect Tech L4T extension [$PHOTON_IMAGE] is NOT a valid file. Exiting."
    exit 1
fi

if [ -n "$ROOTFS_TARBALL" ] && [ ! -f "$ROOTFS_TARBALL" ]; then
    echo "Error: Root file system [$ROOTFS_TARBALL] is NOT a valid file. Exiting."
    exit 1
fi

if [ -n "$CBOOT_BIN" ] && [ ! -f "$CBOOT_BIN" ]; then
    echo "Error: CBOOT BIN [$CBOOT_BIN] is NOT a valid file. Exiting."
    exit 1
fi

# gather version of L4T kernel (example input: Tegra186_Linux_R32.4.2_aarch64.tbz2)
IMG_VERSION="kernel: ${L4T_IMAGE_NAME}"

export DOCKER_BUILDKIT=0

# if a rootfs is supplied then don't build our own
if [ -n "$ROOTFS_TARBALL" ]; then
    echo "Rootfs tarball supplied [$ROOTFS_TARBALL_FILE]"
    echo " <> creating rootfs file system from tarball"
    IMG_VERSION+=" | rootfs: ${ROOTFS_TARBALL_NAME}"
    ROOTFS_TAG=import
    docker import $ROOTFS_TARBALL nx_build_rootfs:${ROOTFS_TAG}
else
    echo "Rootfs tarball NOT supplied, building custom rootfs"
    echo " <> creating custom rootfs file system"
    # get list of L4T deb package dependencies
    L4T_DEBS=$(sed -e '/^#/d' build/l4t_deb_depends.txt | tr '\n' ' ')
    IMG_VERSION+=" | rootfs: Waggle_Linux_Custom-Root-Filesystem_${PROJ_VERSION}_aarch64"
    ROOTFS_TAG=custom${AGENT_MODE}
    # create the base custom rootfs image
    docker build --pull ${DOCKER_CACHE} -f Dockerfile.rootfs \
        -t nx_build_rootfs:${ROOTFS_TAG}_base \
        --build-arg AGENT_MODE="${AGENT_MODE}" \
        --build-arg L4T_DEPENDS="${L4T_DEBS}" .
    # create the custom rootfs image with GPU (Cuda, PyTorch, etc.) support
    docker build ${DOCKER_CACHE} -f Dockerfile.rootfs_gpu \
        -t nx_build_rootfs:${ROOTFS_TAG} \
        --build-arg CUSTOM_BASE="nx_build_rootfs:${ROOTFS_TAG}_base" .
fi

# create the Docker build environment and construct the combined rootfs
docker build ${DOCKER_CACHE} -f Dockerfile \
    -t nx_build${AGENT_MODE} \
    --build-arg ROOTFS_IMAGE="nx_build_rootfs:${ROOTFS_TAG}" .

# construct the docker run command and run it
PWD=`pwd`
DOCKER_VOLUMES=""
DOCKER_ENV=""

# default (nx dev kit) board information
FLASH_BOARDID=3668
FLASH_BOARDSKU=0000
FLASH_FAB=200
FLASH_BOARDREV=G.0
FLASH_FUSELEVEL=fuselevel_production
FLASH_DEVICE_NAME=waggle_nx-devkit-sd
FLASH_PART=mmcblk0p1

# identify if the photon L4T amendments should be included
if [ -n "$PHOTON_IMAGE" ]; then
    echo "Photon L4T found, will create system for CTI Photon board"

    # 0001 = NX production SoC
    FLASH_BOARDSKU=0001
    FLASH_DEVICE_NAME=waggle_photon

    IMG_VERSION+=" | cti_kernel_extension: ${PHOTON_IMAGE_NAME}"
    DOCKER_VOLUMES+=" -v $PHOTON_IMAGE:/$PHOTON_IMAGE_FILE"
    DOCKER_ENV+=" --env PHOTON_IMAGE=/$PHOTON_IMAGE_FILE"
fi

# identify if the custom cboot should be used
if [ -n "$CBOOT_BIN" ]; then
    echo "CBoot BIN found, will override bootloader"
    DOCKER_VOLUMES+=" -v $CBOOT_BIN:/$CBOOT_BIN_FILE"
    DOCKER_ENV+=" --env CBOOT_BIN=/$CBOOT_BIN_FILE"
fi

DOCKER_VOLUMES+=" -v $PWD:/output -v $L4T_IMAGE:/$L4T_IMAGE_FILE"
DOCKER_ENV+=" --env L4T_IMAGE=/$L4T_IMAGE_FILE"
DOCKER_ENV+=" --env ROOTFS=$ROOTFS_TAG"
DOCKER_ENV+=" --env PROJ_VERSION=${PROJ_VERSION}"
DOCKER_ENV+=" --env IMG_VERSION='${IMG_VERSION}'"
DOCKER_ENV+=" --env OUTPUT_NAME=$OUTPUT_NAME"
DOCKER_ENV+=" --env CREATE_MASS_FLASH=$CREATE_MASS_FLASH"
DOCKER_ENV+=" --env CREATE_DEV_TARBALL=$CREATE_DEV_TARBALL"
DOCKER_ENV+=" --env FLASH_BOARDID=$FLASH_BOARDID"
DOCKER_ENV+=" --env FLASH_BOARDSKU=$FLASH_BOARDSKU"
DOCKER_ENV+=" --env FLASH_FAB=$FLASH_FAB"
DOCKER_ENV+=" --env FLASH_BOARDREV=$FLASH_BOARDREV"
DOCKER_ENV+=" --env FLASH_FUSELEVEL=$FLASH_FUSELEVEL"
DOCKER_ENV+=" --env FLASH_DEVICE_NAME=$FLASH_DEVICE_NAME"
DOCKER_ENV+=" --env FLASH_PART=$FLASH_PART"
DOCKER_ENV+=" --env AGENT_MODE=$AGENT_MODE"

echo "VERSION: [${PROJ_VERSION} ${IMG_VERSION}]"
DOCKER_RUN="docker run $TTY --rm --privileged"
DOCKER_RUN+=" ${DOCKER_VOLUMES}"
DOCKER_RUN+=" ${DOCKER_ENV}"
DOCKER_RUN+=" nx_build${AGENT_MODE} $CMD"

echo "Executing docker run: $DOCKER_RUN"
eval $DOCKER_RUN
