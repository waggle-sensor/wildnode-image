#!/bin/bash -e

print_help() {
  echo """
usage: release.sh -r <release manifest> -c <cache directory> [-e <version string>] [-p] [-a]

Download all assets outlined in the <release manifest> and create 2 builds:
- Photon production (core)
- Photon production (agent)

  -r : path to the release manifest file
  -c : cache directory to store downloaded artifacts
  -p : (optional) create the Photon (core) release
  -a : (optional) create the Photon (agent) release
  -e : (optional) version extension string (default: <empty>)
"""
}

# calculates the checksum of the provided file and compares against desired value
#  returns on a successful match, else exits
#  1: file to peform checksum on
#  2: the checksum to compare against
validate_checksum() {
    local file=$1
    local desired=$2

    DMD5=$(md5sum $file | cut -d' ' -f1)
    if [ "${DMD5}" != "${desired}" ]; then
        echo "Error: Unable to process release. Download [${file}]" \
              "checksum [md5: ${DMD5}] does not match expected value [md5: ${desired}]." \
              "Exiting."
        exit 1
    fi
}

# checks if the file already exists and matches the desired checksum
#  returns 0 on success, 1 otherwise
#  1: file to check for existance and maching checksum
#  2: desired checkum of the file
file_already_exist() {
    local file=$1
    local desired=$2

    if [ ! -f "${file}" ]; then
        echo "${file} not found or not of type 'file'."
        return 1
    fi

    DMD5=$(md5sum $file | cut -d' ' -f1)
    if [ "${DMD5}" != "${desired}" ]; then
        echo "${file} checksum [$DMD5] does not match desired value [$desired]."
        return 2
    fi
}

BUILD_CMD="./build.sh"
ARG_MANIFEST=
ARG_CACHE=
ARG_AGENT=
ARG_CORE=
VERSION_EXTENSION=
while getopts "r:c:e:ap?" opt; do
  case $opt in
    r) ARG_MANIFEST=$OPTARG
      ;;
    c) ARG_CACHE=$(realpath $OPTARG)
      ;;
    a) echo "** Create Photon (agent) Release **"
      ARG_AGENT=1
      ;;
    p) echo "** Create Photon (core) Release **"
      ARG_CORE=1
      ;;
    e) VERSION_EXTENSION="-e $OPTARG"
      ;;
    ?|*)
      print_help
      exit 1
      ;;
  esac
done

if [ -z "${ARG_MANIFEST}" ]; then
    echo "Error: Build manifest is required. Exiting."
    exit 1
fi

if [ -z "${ARG_CACHE}" ] || [ ! -d "${ARG_CACHE}" ] ; then
    echo "Error: Artifact cache directory is required and must exist. Exiting."
    exit 1
fi

source "${ARG_MANIFEST}"

# move to cache folder to download the assets
pushd $ARG_CACHE

echo "Download NVidia L4T base package (${R_TEGRA_L4T_BASE} [${R_TEGRA_L4T_BASE_MD5}])"
if ! file_already_exist $(basename $R_TEGRA_L4T_BASE) ${R_TEGRA_L4T_BASE_MD5}; then
    # remove in the event file exists but has mismatched checksum
    rm -rf $(basename $R_TEGRA_L4T_BASE)
    wget -c ${R_TEGRA_L4T_BASE}
    validate_checksum $(basename $R_TEGRA_L4T_BASE) ${R_TEGRA_L4T_BASE_MD5}
fi
NVIDIA_BASE=$ARG_CACHE/$(basename $R_TEGRA_L4T_BASE)

echo "Download CTI Tegra L4T BSP (${R_CTI_TEGRA_L4T} [${R_CTI_TEGRA_L4T_MD5}])"
if ! file_already_exist $(basename $R_CTI_TEGRA_L4T) ${R_CTI_TEGRA_L4T_MD5}; then
    # remove in the event file exists but has mismatched checksum
    rm -rf $(basename $R_CTI_TEGRA_L4T)
    wget -c ${R_CTI_TEGRA_L4T}
    validate_checksum $(basename $R_CTI_TEGRA_L4T) ${R_CTI_TEGRA_L4T_MD5}
fi
CTI_BSP=$ARG_CACHE/$(basename $R_CTI_TEGRA_L4T)

echo "Download CTI Tegra L4T BSP (${R_CBOOT} [${R_CBOOT_MD5}])"
if ! file_already_exist $(basename $R_CBOOT) ${R_CBOOT_MD5}; then
    # remove in the event file exists but has mismatched checksum
    rm -rf $(basename $R_CBOOT)
    wget -c ${R_CBOOT}
    validate_checksum $(basename $R_CBOOT) ${R_CBOOT_MD5}
    # remove unzipped file if already exists
    rm -rf $ARG_CACHE/$(basename $R_CBOOT .gz)
    gunzip $ARG_CACHE/$(basename $R_CBOOT)
fi
CBOOT=$ARG_CACHE/$(basename $R_CBOOT .gz)

popd # cache folder

if [ -n "${ARG_CORE}" ]; then
    echo "Execute build - Photon (Core) Image (production)"
    ${BUILD_CMD} -l ${NVIDIA_BASE} -c ${CTI_BSP} -b ${CBOOT} ${VERSION_EXTENSION} -o photon-core -m
fi

if [ -n "${ARG_AGENT}" ]; then
    echo "Execute build - Photon (Agent) Image (production)"
    ${BUILD_CMD} -l ${NVIDIA_BASE} -c ${CTI_BSP} -b ${CBOOT} ${VERSION_EXTENSION} -o photon-agent -m -a
fi
