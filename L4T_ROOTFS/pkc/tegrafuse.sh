#!/bin/bash

# Copyright (c) 2015-2019, NVIDIA CORPORATION.  All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  * Neither the name of NVIDIA CORPORATION nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#
# tegrafuse.sh: Read fuse in the target board.
#    tegrafuse.sh runs in the target board.
#
# Usage: Boot the board in Linux shell and run:
#
#    sudo ./tegrafuse.sh [options] [fusename]
#
#    more detail enter './tegrafuse.sh -h'
#
# Examples:
#	sudo ./tegrafuse.sh 	           --> Display all Tegra fuses.
#

rd_fuse ()
{
	local i;
	local nm=$1;
	for (( i=0; i<${#fusetab[@]}; i++ )); do
		if [ "${nm}" != "" -a "${nm}" != "${fusetab[$i]}" ]; then
			continue;
		fi;
		if [ ! -f ${sdir}/${fusetab[$i]} ]; then
			echo "Unsupported fuse: ${fusetab[$i]}";
			continue;
		fi;
		local val=`cat ${sdir}/${fusetab[$i]}`;
		if [ "${nm}" != "" ]; then
			echo "${val}";
			return;
		fi;
		echo "${fusetab[$i]} : ${val}";
	done;
	if [ "${nm}" != "" ]; then
		echo "Unknown fuse name: ${nm}";
		exit 1;
	fi;
}

usage ()
{
	cat << EOF
usage: sudo ${progname} [options] [fusename]
    options:
        -d -- sysfs directory name. (default=/sys/devices/platform/tegra-fuse)
        -h -- help
EOF
	exit 1;
}

if [ -e "/sys/devices/soc0/family" ]; then
	CHIP="`cat /sys/devices/soc0/family`"
	if [[ "${CHIP}" =~ "Tegra21" ]]; then
		SOCFAMILY="tegra210"
	fi

	if [ -e "/sys/devices/soc0/machine" ]; then
		machine="`cat /sys/devices/soc0/machine`"
	fi
elif [ -e "/proc/device-tree/compatible" ]; then
	if [ -e "/proc/device-tree/model" ]; then
		machine="$(tr -d '\0' < /proc/device-tree/model)"
	fi
	CHIP="$(tr -d '\0' < /proc/device-tree/compatible)"
	if [[ "${CHIP}" =~ "tegra186" ]]; then
		SOCFAMILY="tegra186"
	elif [[ "${CHIP}" =~ "tegra210" ]]; then
		SOCFAMILY="tegra210"
	elif [[ "${CHIP}" =~ "tegra194" ]]; then
		SOCFAMILY="tegra194"
	fi
fi

if [ "${SOCFAMILY}" == "tegra210" ]; then
	declare -a fusetab=( \
		"arm_jtag_disable" \
		"odm_lock" \
		"odm_production_mode" \
		"pkc_disable" \
		"sec_boot_dev_cfg" \
		"sec_boot_dev_sel" \
	);
elif [ "${SOCFAMILY}" == "tegra186" ] || [ "${SOCFAMILY}" == "tegra194" ]; then
	declare -a fusetab=( \
		"odm_lock" \
		"arm_jtag_disable" \
		"odm_production_mode" \
		"boot_security_info" \
		"odm_info" \
	);
else
	echo "Error! unsupported SOC ${SOCFAMILY}"
	exit 1;
fi

sdir="/sys/devices/platform/tegra-fuse";	# T210 dir
progname=$0;
me=`whoami`;
if [ "${me}" != "root" ]; then
	echo "${progname} requires root privilege.";
	exit 1;
fi;

while getopts "d:h" OPTION
do
	case $OPTION in
	d) sdir=${OPTARG}; ;;
	*) usage; ;;
	esac
done
shift $((OPTIND - 1));
if [ $# -gt 0 ]; then
	fusename=$1;
fi;

if [ ! -d "${sdir}" ]; then
	sdir="/sys/devices/3820000.efuse";
fi;

rd_fuse ${fusename};
exit 0;
