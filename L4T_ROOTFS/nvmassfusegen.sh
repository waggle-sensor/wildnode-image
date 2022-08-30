#!/bin/bash

# Copyright (c) 2020, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.

hdrsize=$((LINENO - 2));
hdrtxt=`head -n ${hdrsize} $0`;
set -o pipefail;
set -o errtrace;
shopt -s extglob;
curdir=$(cd `dirname $0` && pwd);
nargs=$#;
ext_target_board=${!nargs};
if [ ! -r ${ext_target_board}.conf ]; then
	echo "Error: Invalid target board - ${ext_target_board}.";
	exit 1;
fi
LDK_DIR=`readlink -f "${curdir}"`;
source ${ext_target_board}.conf;

BLDIR="bootloader";
FUSECMD="fusecmd.sh";
MFGENCMD="mfgencmd.txt";
mfusedir="mfuse_${ext_target_board}";
mfusetmpdir="mfusetmp_${ext_target_board}";

gen_afuse_sh_v1()
{
	local afuse_txt=`cat << EOF

usbarg="--instance \\\$1";
cidarg="--chip AFARG_CHIPID";
rcmarg="--rcm AFARG_RCMARG";
bctarg="--bct AFARG_BCTARG";
dlbctarg="--download bct AFARG_DLBCTARG";
wrbctarg="--write BCT AFARG_WRBCTARG";
ebtarg="--download ebt AFARG_EBTARG 0 0";	# type file [loadaddr entry]
rp1arg="--download rp1 AFARG_RP1ARG 0 0";	# type file [loadaddr entry]
pttarg="--pt AFARG_PTTARG.bin";
bfsarg="--updatebfsinfo AFARG_PTTARG.bin";
storagefile="\\\$\\\$_storage_info.bin";
fusecfgbin="AFARG_FUSECFGARG";

chkerr()
{
	if [ \\\$? -ne 0 ]; then
		echo "*** Error: \\\$1 failed.";
		rm -f \\\${storagefile};
		exit 1;
	fi;
	echo "*** \\\$1 succeeded.";
}

execmd ()
{
	local banner="\\\$1";
	local cmd="\\\$2";
	local nochk="\\\$3";

	echo; echo "*** \\\${banner}";
	echo "\\\${cmd}";
	if [ "\\\${nochk}" != "" ]; then
		\\\${cmd};
		return;
	fi;
	\\\${cmd};
	chkerr "\\\${banner}";
}

curdir=\\\$(cd \\\`dirname \\\$0\\\` && pwd);
pushd \\\${curdir} > /dev/null 2>&1;

banner="Boot Rom communication";
cmd="\\\${curdir}/tegrarcm \\\${usbarg} \\\${cidarg} \\\${rcmarg}";
execmd "\\\${banner}" "\\\${cmd}";

banner="Blowing fuses";
cmd="\\\${curdir}/tegrarcm \\\${usbarg} --oem blowfuses \\\${fusecfgbin}";
execmd "\\\${banner}" "\\\${cmd}";

popd > /dev/null 2>&1;
exit 0;
EOF`;
	echo "${hdrtxt}" > nvafuse.sh;
	echo "${afuse_txt}" >> nvafuse.sh;
	chmod +x nvafuse.sh;

	local conv="";
	conv+="-e s/AFARG_RCMARG/${rcmarg}/g ";
	conv+="-e s/AFARG_BCTARG/${bctarg}/g ";
	conv+="-e s/AFARG_DLBCTARG/${dlbctarg}/g ";
	conv+="-e s/AFARG_WRBCTARG/${wrbctarg}/g ";
	conv+="-e s/AFARG_EBTARG/${ebtarg}/g ";
	conv+="-e s/AFARG_RP1ARG/${rp1arg}/g ";
	conv+="-e s/AFARG_PTTARG/${pttarg}/g ";
	conv+="-e s/AFARG_FUSECFGARG/${fusecfgbin}/g ";
	sed -i ${conv} nvafuse.sh;
	if [ $? -ne 0 ]; then
		echo "Error: Setting up nvafuse.sh";
		exit 1;
	fi;
	fc=`cat nvafuse.sh | sed -e s/AFARG_CHIPID/"${cidarg}"/g`;
	echo "${fc}" > nvafuse.sh;
}

gen_afuse_sh_v2()
{
	local afuse_txt=`cat << EOF

usbarg="--instance \\\$1";
cidarg="--chip AFARG_CHIPID";
rcmarg="--rcm AFARG_RCMARG";
rcmsfarg="AFARG_RCMSFARG";
pttarg="--pt AFARG_PTTARG.bin";
storagefile="storage_info.bin";

dlbrbctarg="--download bct_bootrom AFARG_DLBRBCTARG";
wrbrbctarg="--write BCT AFARG_WRBRBCTARG";

mb1bctarg="AFARG_DLMB1BCTARG";
dlmb1bctarg="--download bct_mb1 AFARG_DLMB1BCTARG";
wrmb1bctarg="--write MB1_BCT AFARG_WRMB1BCTARG";
wrmb1bctbarg="--write MB1_BCT_b AFARG_WRMB1BCTARG";

membctarg="AFARG_MEMBCTARG";
dlmembctarg="--download bct_mem AFARG_DLMEMBCTARG";
wrmembctarg="--write MEM_BCT AFARG_WRMEMBCTARG";
wrmembctbarg="--write MEM_BCT_b AFARG_WRMEMBCTARG";

memcbctarg="AFARG_MEMCBCTARG";
fusecfgbin="AFARG_FUSECFGARG";

chkerr()
{
	if [ \\\$? -ne 0 ]; then
		echo "*** Error: \\\$1 failed.";
		exit 1;
	fi;
	echo "*** \\\$1 succeeded.";
}

execmd ()
{
	local banner="\\\$1";
	local cmd="\\\$2";
	local nochk="\\\$3";

	echo; echo "*** \\\${banner}";
	echo "\\\${cmd}";
	if [ "\\\${nochk}" != "" ]; then
		\\\${cmd};
		return;
	fi;
	\\\${cmd};
	chkerr "\\\${banner}";
}

curdir=\\\$(cd \\\`dirname \\\$0\\\` && pwd);
pushd \\\${curdir} > /dev/null 2>&1;

banner="Boot Rom communication";
cmd="\\\${curdir}/tegrarcm_v2 \\\${usbarg} \\\${cidarg} ";
if [ "\\\${rcmsfarg}" != "" ]; then
	cmd+="--rcm \\\${rcmsfarg} ";
fi;
cmd+="\\\${rcmarg} ";
execmd "\\\${banner}" "\\\${cmd}";

banner="Checking applet";
cmd="\\\${curdir}/tegrarcm_v2 \\\${usbarg} --isapplet";
execmd "\\\${banner}" "\\\${cmd}";

banner="Sending BCTs";
cmd="\\\${curdir}/tegrarcm_v2 \\\${usbarg} \\\${dlbrbctarg} ";
if [ "\\\${mb1bctarg}" != "" ]; then
	cmd+="\\\${dlmb1bctarg} ";
fi;
if [ "\\\${membctarg}" != "" ]; then
	cmd+="\\\${dlmembctarg}";
fi;
execmd "\\\${banner}" "\\\${cmd}";

banner="Sending bootloader and pre-requisite binaries";
cmd="\\\${curdir}/tegrarcm_v2 \\\${usbarg} --download blob blob.bin";
execmd "\\\${banner}" "\\\${cmd}";

banner="Booting Recovery";
cmd="\\\${curdir}/tegrarcm_v2 \\\${usbarg} --boot recovery";
execmd "\\\${banner}" "\\\${cmd}";

banner="Checking applet";
cmd="\\\${curdir}/tegrarcm_v2 \\\${usbarg} --isapplet";
execmd "\\\${banner}" "\\\${cmd}" "1";

sleep 3;
banner="Checking CPU bootloader";
cmd="\\\${curdir}/tegradevflash_v2 \\\${usbarg} --iscpubl";
execmd "\\\${banner}" "\\\${cmd}";

banner="Fusing the device";
cmd="\\\${curdir}/tegradevflash_v2 \\\${usbarg} --oem burnfuses \\\${fusecfgbin}";
execmd "\\\${banner}" "\\\${cmd}";

banner="Rebooting the device";
cmd="\\\${curdir}/tegradevflash_v2 \\\${usbarg} --reboot recovery";
execmd "\\\${banner}" "\\\${cmd}";

popd > /dev/null 2>&1;
exit 0;
EOF`;
	echo "${hdrtxt}" > nvafuse.sh;
	echo "${afuse_txt}" >> nvafuse.sh;
	chmod +x nvafuse.sh;

	local conv="";
	conv+="-e s/AFARG_RCMSFARG/${rcmsfarg}/g ";
	conv+="-e s/AFARG_RCMARG/${rcmarg}/g ";
	conv+="-e s/AFARG_PTTARG/${pttarg}/g ";

	conv+="-e s/AFARG_DLBRBCTARG/${dlbrbctarg}/g ";
	conv+="-e s/AFARG_WRBRBCTARG/${dlbrbctarg}/g ";

	conv+="-e s/AFARG_DLMB1BCTARG/${dlmb1bctarg}/g ";
	conv+="-e s/AFARG_WRMB1BCTARG/${wrmb1bctarg}/g ";

	conv+="-e s/AFARG_MEMBCTARG/${membctarg}/g ";
	conv+="-e s/AFARG_DLMEMBCTARG/${dlmembctarg}/g ";
	conv+="-e s/AFARG_WRMEMBCTARG/${wrmembctarg}/g ";
	conv+="-e s/AFARG_MEMCBCTARG/${memcbctarg}/g ";
	conv+="-e s/AFARG_FUSECFGARG/${fusecfgbin}/g ";

	sed -i ${conv} nvafuse.sh;
	if [ $? -ne 0 ]; then
		echo "Error: Setting up nvafuse.sh";
		exit 1;
	fi;
	fc=`cat nvafuse.sh | sed -e s/AFARG_CHIPID/"${cidarg}"/g`;
	echo "${fc}" > nvafuse.sh;
}

gen_afuse_sh()
{
	local tfv=$1;
	case ${tfv} in
	1) gen_afuse_sh_v1; ;;
	2) gen_afuse_sh_v2; ;;
	*) echo "Error: Unknown tegraflash version"; exit 1; ;;
	esac;
}

gen_mfuse_sh()
{
	local mfuse_txt=`cat << EOF

curdir=\\\$(cd \\\`dirname \\\$0\\\` && pwd);
showlogs=0;
if [ "\\\$1" = "--showlogs" ]; then
	showlogs=1;
fi;

# Find devices to fuse
devpaths=(\\\$(find /sys/bus/usb/devices/usb*/ \\\\
		-name devnum -print0 | {
	found=()
	while read -r -d "" fn_devnum; do
		dir="\\\$(dirname "\\\${fn_devnum}")"
		vendor="\\\$(cat "\\\${dir}/idVendor")"
		if [ "\\\${vendor}" != "0955" ]; then
			continue
		fi
		product="\\\$(cat "\\\${dir}/idProduct")"
		case "\\\${product}" in
		"7721") ;;
		"7f21") ;;
		"7018") ;;
		"7c18") ;;
		"7121") ;;
		"7019") ;;
		"7e19") ;;
		*)
			continue
			;;
		esac
		fn_busnum="\\\${dir}/busnum"
		if [ ! -f "\\\${fn_busnum}" ]; then
			continue
		fi
		fn_devpath="\\\${dir}/devpath"
		if [ ! -f "\\\${fn_devpath}" ]; then
			continue
		fi
		busnum="\\\$(cat "\\\${fn_busnum}")"
		devpath="\\\$(cat "\\\${fn_devpath}")"
		found+=("\\\${busnum}-\\\${devpath}")
	done
	echo "\\\${found[@]}"
}))

# Exit if no devices to fuse
if [ \\\${#devpaths[@]} -eq 0 ]; then
	echo "No devices to fuse"
	exit 1
fi

# Create a folder for saving log
mkdir -p mfuselogs;
pid="\\\$\\\$"
ts=\\\`date +%Y%m%d-%H%M%S\\\`;

# Fuse burning all devices in background
fuse_pids=()
for devpath in "\\\${devpaths[@]}"; do
	fn_log="mfuselogs/\\\${ts}_\\\${pid}_fuse_\\\${devpath}.log"
	cmd="\\\${curdir}/nvafuse.sh \\\${devpath}";
	\\\${cmd} > "\\\${fn_log}" 2>&1 &
	fuse_pid="\\\$!";
	fuse_pids+=("\\\${fuse_pid}")
	echo "Start fusing device: \\\${devpath}, PID: \\\${fuse_pid}";
	if [ \\\${showlogs} -eq 1 ]; then
		gnome-terminal -e "tail -f \\\${fn_log}" -t \\\${fn_log} > /dev/null 2>&1 &
	fi;
done

# Wait until all fuse processes done
failure=0
while true; do
	running=0
	if [ \\\${showlogs} -ne 1 ]; then
		echo -n "Ongoing processes:"
	fi;
	new_fuse_pids=()
	for fuse_pid in "\\\${fuse_pids[@]}"; do
		if [ -e "/proc/\\\${fuse_pid}" ]; then
			if [ \\\${showlogs} -ne 1 ]; then
				echo -n " \\\${fuse_pid}"
			fi;
			running=\\\$((\\\${running} + 1))
			new_fuse_pids+=("\\\${fuse_pid}")
		else
			wait "\\\${fuse_pid}" || failure=1
		fi
	done
	if [ \\\${showlogs} -ne 1 ]; then
		echo
	fi;
	if [ \\\${running} -eq 0 ]; then
		break
	fi
	fuse_pids=("\\\${new_fuse_pids[@]}")
	sleep 5
done

if [ \\\${failure} -ne 0 ]; then
	echo "Fuse burn complete (WITH FAILURES)";
	exit 1
fi

echo "Fuse burn complete (SUCCESS)"
EOF`;
	echo "${hdrtxt}" > nvmfuse.sh;
	echo "${mfuse_txt}" >> nvmfuse.sh;
	chmod +x nvmfuse.sh;
}

getidx()
{
	local i;
	local f="$1";
	local s="$2";
	shift; shift;
	local a=($@);

	for (( i=0; i<${#a[@]}; i++ )); do
		if [ "$f" != "${a[$i]}" ]; then
			continue;
		fi;
		i=$(( i+1 ));
		if [ "${s}" != "" ]; then
			if [ "$s" != ${a[$i]} ]; then
				continue;
			fi;
			i=$(( i+1 ));
		fi;
		return $i;
	done;
	echo "Error: $f $s not found";
	exit 1;
}

chkidx()
{
	local i;
	local f="$1";
	shift;
	local a=($@);

	for (( i=0; i<${#a[@]}; i++ )); do
		if [ "$f" != "${a[$i]}" ]; then
			continue;
		fi;
		return 0;
	done;
	return 1;
}

chext ()
{
	local i;
	local var="$1";
	local fname=`basename "$2"`;
	local OIFS=${IFS};
	IFS='.';
	na=($fname);
	IFS=${OIFS};
	local nasize=${#na[@]};
	if [ $nasize -lt 2 ]; then
		echo "Error: invalid file name: ${fname}";
		exit 1;
	fi;
	na[$((nasize-1))]=${3};
	local newname="";
	for (( i=0; i < ${nasize}; i++ )); do
		newname+="${na[$i]}";
		if [ $i -lt $((nasize-1)) ]; then
			newname+=".";
		fi;
	done;
	eval "${var}=${newname}";
}

gen_param()
{
	local tf_v=1;
	local len;
	local binsidx;
	local a=`echo "$1" | sed -e s/\"//g -e s/\;//g`;
	local OIFS=${IFS};
	IFS=' ';
	a=($a);
	IFS=$OIFS;

	blobxmltxt="";
	chkidx "--bl" "${a[@]}";
	if [ $? -eq 0 ]; then
		getidx "--bl" "" "${a[@]}";
		ebtarg="${a[$?]}";
	fi;

	getidx "--chip" "" "${a[@]}";
	cidarg="${a[$?]}";
	len=$(expr length "${cidarg}");
	if [ ${len} -le 4 ]; then
		tgid="${cidarg}";
		if [ "${CHIPMAJOR}" != "" ]; then
			cidarg="${cidarg} ${CHIPMAJOR}";
		else
			local addchipmajor="true";
			local relfile="${LDK_DIR}/rootfs/etc/nv_tegra_release";
			if [ -f "${relfile}" ]; then
				rel=`head -n 1 "${relfile}"`;
				rel=`echo "${rel}" | awk -F ' ' '{print $2}'`;
				if [ "${rel}" \< "R32" ]; then
					addchipmajor="false";
				fi;
			fi;
			if [ "${addchipmajor}" = "true" ]; then
				cidarg="${cidarg} 0";
			fi;
		fi;
	else
		tgid=`echo "${cidarg}" | awk -F ' ' '{print $1}'`;
	fi;
	if [ "${tgid}" != "0x21" ]; then
		tf_v=2;
	fi;

	getidx "--applet" "" "${a[@]}";
	rcmarg="${a[$?]}";
	aplarg="${rcmarg}";
	if [ "${rcmarg}" = "nvtboot_recovery.bin" -o \
		"${rcmarg}" = "mb1_recovery_prod.bin" -o \
		"${rcmarg}" = "mb1_t194_prod.bin" ]; then
		rcmarg="rcm_list_signed.xml";
	fi;

	chkidx "--cfg" "${a[@]}";
	if [ $? -eq 0 ]; then
		getidx "--cfg" "" "${a[@]}";
		pttarg="${a[$?]}";
	fi;

	chkidx "--bins" "${a[@]}";
	if [ $? -eq 0 ]; then
		getidx "--bins" "" "${a[@]}";
		binsidx=$?;
	else
		chkidx "--bin" "${a[@]}";
		if [ $? -eq 0 ]; then
			getidx "--bin" "" "${a[@]}";
			binsidx=$?;
		fi;
	fi;

	if [ ${tf_v} -eq 1 ]; then
		# Tegraflash V1
		getidx "blowfuses" "" "${a[@]}";
		fusecfg="${a[$?]}";
		chext fusecfgbin ${fusecfg} "bin";
		return ${tf_v};
	fi;

	# Tegraflash V2
	# BCT params
	chkidx "--bct" "${a[@]}";
	if [ $? -eq 0 ]; then
		getidx "--bct" "" "${a[@]}";
		bctarg="${a[$?]}";
		dlbrbctarg="${bctarg}";
	else
		dlbrbctarg="br_bct_BR.bct";
	fi;
	wrbrbctarg="${dlbrbctarg}";

	chkidx "--applet_softfuse" "${a[@]}";
	if [ $? -eq 0 ]; then
		getidx "--applet_softfuse" "" "${a[@]}";
		rcmsfarg="${a[$?]}";
	fi;

	chkidx "--mb1_bct" "${a[@]}";
	if [ $? -eq 0 ]; then
		getidx "--mb1_bct" "" "${a[@]}";
		mb1bctarg="${a[$?]}";
		dlmb1bctarg="${mb1bctarg}";
	else
		dlmb1bctarg="mb1_bct_MB1_sigheader.bct";
		chkidx "--key" "${a[@]}";
		if [ $? -eq 0 ]; then
			dlmb1bctarg+=".signed";
		else
			dlmb1bctarg+=".encrypt";
		fi;
	fi;

	chkidx "--mb1_cold_boot_bct" "${a[@]}";
	if [ $? -eq 0 ]; then
		getidx "--mb1_cold_boot_bct" "" "${a[@]}";
		mb1cbctarg="${a[$?]}";
		wrmb1bctarg="${mb1cbctarg}";
	else
		wrmb1bctarg="mb1_cold_boot_bct_MB1_sigheader.bct";
		wrmb1bctarg+=".encrypt";
	fi;

	if [ "${tgid}" = "0x19" ]; then
		chkidx "--mem_bct" "${a[@]}";
		if [ $? -eq 0 ]; then
			getidx "--mem_bct" "" "${a[@]}";
			membctarg="${a[$?]}";
			dlmembctarg="${membctarg}";
		else
			dlmembctarg="mem_rcm_sigheader.bct";
			dlmembctarg+=".encrypt";
			if [ "${tgid}" = "0x19" ]; then
				membctarg="${dlmembctarg}";
			fi;
		fi;

		chkidx "--mem_bct_cold_boot" "${a[@]}";
		if [ $? -eq 0 ]; then
			getidx "--mem_bct_cold_boot" "" "${a[@]}";
			memcbctarg="${a[$?]}";
			wrmembctarg="${memcbctarg}";
		else
			wrmembctarg="mem_coldboot_sigheader.bct";
			wrmembctarg+=".encrypt";
		fi;
	fi;

	chkidx "blowfuses" "${a[@]}";
	if [ $? -eq 0 ]; then
		getidx "blowfuses" "" "${a[@]}";
		fusecfg="${a[$?]}";
	else
		chkidx "burnfuses" "${a[@]}";
		if [ $? -eq 0 ]; then
			getidx "burnfuses" "" "${a[@]}";
			fusecfg="${a[$?]}";
			chext fusecfgbin ${fusecfg} "bin";
		fi;
	fi;

	# BIN params
	blobxmltxt+="<file_list mode=\"blob\">";
	blobxmltxt+="<!--Auto generated by tegraflash.py-->";
	blobfiles="";
	# The first entry is EBT binary.
	if [ "${bctarg}" != "" -a "${mb1bctarg}" != "" ]; then
		blobxmltxt+="<file name=\"";
		blobxmltxt+="${ebtarg}\" ";
		blobfiles+="${ebtarg} ";
		blobxmltxt+="type=\"bootloader\" />";
		for (( i=${binsidx}; i<${#a[@]}; i++ )); do
			if [[ ${a[$i]} =~ ^\-\- ]]; then
				break;
			fi;
			blobxmltxt+="<file name=\"";
			blobxmltxt+="${a[$((i+1))]}\" ";
			blobfiles+="${a[$((i+1))]} ";
			blobxmltxt+="type=\"${a[$i]}\" />";
			i=$((i+1));
		done;
	else
		local na=`echo "${ebtarg}" | cut -d'.' -f1`;
		local suf=`echo "${ebtarg}" | cut -d'.' -f2`;
		blobxmltxt+="<file name=\"";
		blobxmltxt+="${na}_sigheader.${suf}.encrypt\" ";
		blobfiles+="${na}_sigheader.${suf}.encrypt ";
		blobxmltxt+="type=\"bootloader\" />";
		for (( i=${binsidx}; i<${#a[@]}; i++ )); do
			if [[ ${a[$i]} =~ ^\-\- ]]; then
				break;
			fi;
			if [ "${a[$i]}" = "kernel" -o \
				"${a[$i]}" = "kernel_dtb" ]; then
				i=$((i+1));
				continue;
			fi;
			na=`echo "${a[$((i+1))]}" | cut -d'.' -f1`;
			suf=`echo "${a[$((i+1))]}" | cut -d'.' -f2`;
			blobxmltxt+="<file name=\"";
			blobxmltxt+="${na}_sigheader.${suf}.encrypt\" ";
			blobfiles+="${na}_sigheader.${suf}.encrypt ";
			blobxmltxt+="type=\"${a[$i]}\" />";
			i=$((i+1));
		done;
	fi;
	blobxmltxt+="</file_list>";
	return ${tf_v};
}

findadev()
{
	local devpaths=($(find /sys/bus/usb/devices/usb*/ -name devnum -print0 | {
		local fn_devnum;
		local found=();
		while read -r -d "" fn_devnum; do
			local dir="$(dirname "${fn_devnum}")";
			local vendor="$(cat "${dir}/idVendor")";
			if [ "${vendor}" != "0955" ]; then
				continue
			fi;
			local product="$(cat "${dir}/idProduct")";
			case "${product}" in
			"7721") ;;
			"7f21") ;;
			"7018") ;;
			"7c18") ;;
			"7121") ;;
			"7019") ;;
			"7e19") ;;
			*) continue ;;
			esac
			local fn_busnum="${dir}/busnum";
			if [ ! -f "${fn_busnum}" ]; then
				continue;
			fi;
			local fn_devpath="${dir}/devpath";
			if [ ! -f "${fn_devpath}" ]; then
				continue;
			fi;
			local busnum="$(cat "${fn_busnum}")";
			local devpath="$(cat "${fn_devpath}")";
			found+=("${busnum}-${devpath}");
		done;
		echo "${found[@]}";
	}))
	echo "${#devpaths[@]} Jetson devices in RCM mode. USB: ${devpaths[@]}";
	return "${#devpaths[@]}";
}

chkerr()
{
	if [ $? -ne 0 ]; then
		echo "*** Error: $1 failed.";
		rm -f ${storagefile};
		exit 1;
	fi;
	echo "*** $1 succeeded.";
}

execmd ()
{
	local banner="$1";
	local cmd="$2";
	local nochk="$3";

	echo; echo "*** ${banner}";
	echo "${cmd}";
	if [ "${nochk}" != "" ]; then
		${cmd};
		return;
	fi;
	${cmd};
	chkerr "${banner}";
}

create_signdir_v1 ()
{
	local i;
	local v;
	local f;
	local cmd;
	local l=(\
		"aplarg" \
		"fusecfg" \
		);
	local a=(\
		"tegraparser" \
		"tegrarcm" \
		"tegrasign" \
		);

	if [ "$1" = "" ]; then
		echo "Error: Null sign directory name.";
		exit 1;
	fi;
	rm -rf "$1";
	mkdir "$1";
	pushd "$1" > /dev/null 2>&1;
	for (( i=0; i<${#l[@]}; i++ )); do
		v=${l[$i]};
		if [ ! -f ../${!v} ]; then
			echo "Error: ../${!v} does not exist";
			exit 1;
		fi;
		echo -n "copying ${!v} ... ";
		cp -f ../${!v} .;
		if [ $? -eq 0 ]; then
			echo "succeeded."
		else
			echo "failed."
			exit 1;
		fi;
	done;

	for (( i=0; i<${#a[@]}; i++ )); do
		if [ -f "${a[$i]}" ]; then
			continue;
		fi;
		if [ ! -f "../${a[$i]}" ]; then
			echo "Error: ${a[$i]} does not exist.";
			exit 1;
		fi;
		echo -n "copying ${a[$i]} ... ";
		cp ../${a[$i]} .;
		if [ $? -eq 0 ]; then
			echo "succeeded."
		else
			echo "failed."
			exit 1;
		fi;
	done;

	banner="Parsing fuse info as per xml file";
	cmd="./tegraparser --fuse_info ${fusecfg} ${fusecfgbin}";
	execmd "${banner}" "${cmd}";

	banner="Generating RCM messages";
	cmd="./tegrarcm --listrcm rcm_list.xml ";
	cmd+="--chip ${cidarg} ";
	cmd+="--download rcm ${aplarg} 0 0";
	execmd "${banner}" "${cmd}";	# Generates rcm_list.xml, rcm_?.rcm

	banner="Signing RCM messages";
	cmd="./tegrasign --key None --list rcm_list.xml ";
	cmd+="--pubkeyhash pub_key.key";
	execmd "${banner}" "${cmd}";	# Generates rcm_list_signed.xml

	banner="Copying signature to RCM messages";
	cmd="./tegrarcm --chip ${cidarg} ";
	cmd+="--updatesig rcm_list_signed.xml ";
	execmd "${banner}" "${cmd}";	# Updates signatures in rcm_?.rcm files

	popd > /dev/null 2>&1;
}

fill_mfusetmpdir ()
{
	local i;
	local l;
	local tf_v1=(\
		"nvmfuse.sh" \
		"nvafuse.sh" \
		);

	if [ "$2" = "" ]; then
		echo "Error: Null MFUSE temporary directory.";
		exit 1;
	fi;
	if [ ! -d "$2" ]; then
		echo "Error: MFUSE temporary directory ($2) does not exists.";
		exit 1;
	fi;
	pushd "$2" > /dev/null 2>&1;

	if [ $1 -lt 2 ]; then
		l=( ${tf_v1[@]} );
		for (( i=0; i<${#l[@]}; i++ )); do
			if [ ! -f ${l[$i]} ]; then
				echo -n "copying ${l[$i]} ... ";
				cp -f "../${l[$i]}" .;
				if [ $? -eq 0 ]; then
					echo "succeeded."
				else
					echo "failed."
					exit 1;
				fi;
			fi;
		done;
		popd > /dev/null 2>&1;
		return;
	fi;

	local lst=`ls -1`;
	local a=($lst);
	for (( i=0; i<${#a[@]}; i++ )); do
		if [ -L "${a[$i]}" ]; then
			rm -f "${a[$i]}";
			echo -n "copying ${a[$i]} ... ";
			cp -f "../${a[$i]}" .;
			if [ $? -eq 0 ]; then
				echo "succeeded."
			else
				echo "failed."
				exit 1;
			fi;
		fi;
	done;

	if [ "${blobxmltxt}" != "" ]; then
		local tid=`echo "${cidarg}" | cut -d' ' -f1`;
		echo "${blobxmltxt}" > blob.xml;
		./tegrahost_v2 --chip ${tid} --generateblob blob.xml blob.bin;
	fi;

	if [ "${fusecfgbin}" != "" ]; then
		./tegraparser_v2 --fuse_info ${fusecfg} ${fusecfgbin};
	fi;

	popd > /dev/null 2>&1;
}

fill_mfusedir ()
{
	local i;
	local l;
	local tf_v1=(\
		"nvmfuse.sh" \
		"nvafuse.sh" \
		"tegrarcm" \
		"${aplarg}" \
		);
	local tf_v2=(\
		"nvmfuse.sh" \
		"nvafuse.sh" \
		"tegrarcm_v2" \
		"tegradevflash_v2" \
		"tegraparser_v2" \
		);
	local opt=(\
		"${rcmarg}" \
		"rcm_0_encrypt.rcm" \
		"rcm_1_encrypt.rcm" \
		"rcm_2_encrypt.rcm" \
		"${dlbrbctarg}" \
		"${dlmb1bctarg}" \
		"${dlmembctarg}" \
		"${fusecfgbin}" \
		"blob.bin" \
		);
	if [ $1 -eq 2 ]; then
		l=( ${tf_v2[@]} );
	else
		l=( ${tf_v1[@]} );
	fi;

	if [ "$2" = "" ]; then
		echo "Error: Null MFUSE temporary directory.";
		exit 1;
	fi;
	if [ ! -d "$2" ]; then
		echo "Error: MFUSE temporary directory ($2) does not exists.";
		exit 1;
	fi;
	local fromdir="$2";

	if [ "$3" = "" ]; then
		echo "Error: Null MFUSE directory.";
		exit 1;
	fi;
	if [ ! -d "$3" ]; then
		echo "Error: MFUSE directory ($3) does not exists.";
		exit 1;
	fi;
	local todir="$3";

	pushd "$3" > /dev/null 2>&1;

	for (( i=0; i<${#l[@]}; i++ )); do
		if [ ! -f ${l[$i]} ]; then
			echo -n "copying ${l[$i]} ... ";
			cp -f "${fromdir}/${l[$i]}" .;
			if [ $? -eq 0 ]; then
				echo "succeeded."
			else
				echo "failed."
				exit 1;
			fi;
		fi;
	done;

	for (( i=0; i<${#opt[@]}; i++ )); do
		if [ "${opt[$i]}" = "" ]; then
			continue;
		fi;
		if [ ! -f "${opt[$i]}" -a -f "${fromdir}/${opt[$i]}" ]; then
			echo -n "copying ${opt[$i]} ... ";
			cp -f "${fromdir}/${opt[$i]}" .;
			if [ $? -eq 0 ]; then
				echo "succeeded."
			else
				echo "failed."
				exit 1;
			fi;
		fi;
	done;

	popd > /dev/null 2>&1;
}

ndev=0;
if [ "${BOARDID}" = "" -o "${BOARDSKU}" = "" -o \
	"${FAB}" = "" -o "${FUSELEVEL}" = "" ]; then
	cat << EOF
================================================================================
|| Generate Massfuse Image with Jetson device connected:
|| Requires the Jetson connected in RCM mode.
================================================================================
EOF
	findadev;
	ndev=$?;
	if [ $ndev -ne 1 ]; then
		if [ $ndev -gt 1 ]; then
			echo "*** Too many Jetson devices found.";
		else
			echo "*** Error: No Jetson device found.";
		fi;
		echo "Connect 1 Jetson in RCM mode and rerun $0 $@";
		exit 1;
	fi;
else
	cat << EOF
================================================================================
|| Generate Massfuse Image without Jetson device connected:
|| BOARDID=${BOARDID} BOARDSKU=${BOARDSKU} FAB=${FAB} FUSELEVEL=${FUSELEVEL}
================================================================================
EOF
fi;

cat << EOF
+-------------------------------------------------------------------------------
| Step 1: Generate Command File
+-------------------------------------------------------------------------------
EOF

BOARDID=${BOARDID} BOARDSKU=${BOARDSKU} FAB=${FAB} FUSELEVEL=${FUSELEVEL} ${curdir}/odmfuse.sh --noburn $@
if [ $? -ne 0 ]; then
	echo "*** Error: ${FUSECMD} generation failed.";
	exit 1;
fi;
if [ ! -f "${BLDIR}/${FUSECMD}" ]; then
	echo "*** Error: command file generation failed.";
	exit 1;
fi;
cmd=`tail -1 ${BLDIR}/${FUSECMD} | sed -e s/^eval// -e s/\'//g`;
gen_param "${cmd}"; tfvers=$?;
if [ "${fusecfg}" = "" ]; then
	echo "Error: generating fuse config failed.";
	exit 1;
fi;

pushd ${BLDIR} > /dev/null 2>&1;
touch VERFILE;
fusecfgtst="${fusecfg}.tst";
if [ -f "${fusecfgtst}" ]; then
	mv -f "${fusecfg}" "${fusecfg}.sav";
	cp -f "${fusecfgtst}" "${fusecfg}";
fi;
if [[ ${cmd} =~ blowfuses ]]; then
	cat << EOF
+-------------------------------------------------------------------------------
| Step 2: Extract Signed Binaries
+-------------------------------------------------------------------------------
EOF
	mfusedir="${mfusedir}_signed";
	mfusetmpdir="${mfusetmpdir}_signed";
	signdir="mfusetmp";
	create_signdir_v1 "${signdir}";
else
	cat << EOF
+-------------------------------------------------------------------------------
| Step 2: Sign Binaries
+-------------------------------------------------------------------------------
EOF

	cmdconv="-e s/${fusecfg}// -e s/burnfuses/sign/";
	cmd=`echo "${cmd}" | sed ${cmdconv}`;

	echo "${cmd} --keep --skipuid" > ${MFGENCMD};
	cat ${MFGENCMD};
	bash ${MFGENCMD} 2>&1 | tee mfusegen.log;
	if [ $? -ne 0 ]; then
		echo "Error: Signing binaries failed.";
		exit 1;
	fi;

	tok=`grep "Keep temporary directory" mfusegen.log`;
	if [ "${tok}" = "" ]; then
		echo "Error: signing binaries failed.";
		exit 1;
	fi;
	signdir=`echo "${tok}" | awk -F ' ' '{print $4}'`;
	signdir=`basename ${signdir}`;
fi;

cat << EOF
+-------------------------------------------------------------------------------
| Step 3: Generate Mass-fuse scripts
+-------------------------------------------------------------------------------
EOF
gen_mfuse_sh;
gen_afuse_sh ${tfvers};

cat << EOF
+-------------------------------------------------------------------------------
| Step 4: Generate Mass-fuse image tarball
+-------------------------------------------------------------------------------
EOF

rm -rf "${mfusetmpdir}";
mv "${signdir}" "${mfusetmpdir}";
fill_mfusetmpdir ${tfvers} "${mfusetmpdir}";
rm -f VERFILE;
rm -rf "${mfusedir}";
mkdir "${mfusedir}";
mfusetmpdir=`readlink -f "${mfusetmpdir}"`;
fill_mfusedir ${tfvers} "${mfusetmpdir}" "${mfusedir}";
mfitarball="${mfusedir}.tbz2";
tar cvjf ../${mfitarball} ${mfusedir};
popd > /dev/null 2>&1;

echo "\
********************************************************************************
*** Mass Fusing tarball ${mfitarball} is ready.
********************************************************************************
    1. Download ${mfitarball} to each fusing hosts.
    2. Untar ${mfitarball}. ( tar xvjf ${mfitarball} )
    3. cd ${mfusedir}
    4. Connect Jetson boards(${ext_target_board} only) and put them in RCM mode.
    5. ./nvmfuse.sh
";
