#!/bin/bash

# Copyright (c) 2020, NVIDIA CORPORATION.  All rights reserved.
#
# NVIDIA CORPORATION and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA CORPORATION is strictly prohibited.

#
# odmfuseread.sh: Read the fuse info from the target board.
#                 It only supports T186 and T194 platforms now.
#
# Usage: Place the board in recovery mode and run:
#
#	./odmfuseread.sh -c <crypto_type> -i <chip_id> [options] target_board
#
#	for more detail enter './odmfuseread.sh -h'
#
# Examples for Jetson Xavier:
#   1. Read fuse without any boot authentication
#      ./odmfuseread.sh -c NS -i 0x19 jetson-xavier
#   2. Read fuse when public key is burned
#      ./odmfuseread.sh -c PKC -i 0x19 jetson-xavier
#
# Examples for Jetson TX2:
#   1. Read fuse without any boot authentication
#      ./odmfuseread.sh -c NS -i 0x18 jetson-xavier
#   2. Read fuse when public key is burned
#      ./odmfuseread.sh -c PKC -i 0x18 jetson-xavier
#

usage ()
{
	cat << EOF
Usage:
  ./odmfuseread.sh -c <crypto_type> -i <chip_id> [options] target_board

  where:
    crypto_type ----------- Either "NS" or "PKC"
    chip_id --------------- Jetson TX2: 0x18, Jetson Xavier: 0x19

  options:
    -k <key_file> --------- The public key file.
    -s <sbk_file> --------- The SBK file.

EOF
    exit 1;
}

get_fuse_level ()
{
	local ECID;
	local rcmcmd;
	local inst_args="";
	local idval_1="";
	local idval_2="";
	local flval="";
	local baval="None";
	local flvar="$1";
	local hivar="$2";
	local bavar="$3";

	if [ -f "${BL_DIR}/tegrarcm_v2" ]; then
		rcmcmd="tegrarcm_v2";
	elif [ -f "${BL_DIR}/tegrarcm" ]; then
		rcmcmd="tegrarcm";
	else
		echo "Error: tegrarcm is missing.";
		exit 1;
	fi;
	if [ -n "${usb_instance}" ]; then
		inst_args="--instance ${usb_instance}";
	fi;
	pushd "${BL_DIR}" > /dev/null 2>&1;
	ECID=$(./${rcmcmd} ${inst_args} --uid | grep BR_CID | cut -d' ' -f2);
	popd > /dev/null 2>&1;
	SKIPUID="--skipuid";

	if [ "${ECID}" != "" ]; then
		idval_1="0x${ECID:3:2}";
		eval "${hivar}=\"${idval_1}\"";
		idval_2="0x${ECID:6:2}";

		flval="${ECID:2:1}";
		baval="";
		if [ "${idval_1}" = "0x21" -o "${idval_1}" = "0x12" -o \
			"${idval_1}" = "0x00" -a "${idval_2}" = "0x21" ]; then
			case ${flval} in
			0|1|2) flval="fuselevel_nofuse"; ;;
			3)     flval="fuselevel_production"; ;;
			4)     flval="fuselevel_production"; baval="NS"; ;;
			5)     flval="fuselevel_production"; baval="SBK"; ;;
			6)     flval="fuselevel_production"; baval="PKC"; ;;
			*)     flval="fuselevel_unknown"; ;;
			esac;
			if [ "${idval_1}" = "0x00" ]; then
				eval "${hivar}=\"${idval_2}\"";
			fi;
		elif [ "${idval_1}" = "0x80" ]; then
			if [ "${idval_2}" = "0x19" ]; then
				case ${flval} in
				0|1|2) flval="fuselevel_nofuse"; ;;
				8)     flval="fuselevel_production"; ;;
				9)     flval="fuselevel_production"; baval="PKC"; ;;
				esac;
				hwchipid="0x19";
				hwchiprev="${ECID:5:1}";
			fi
		else
			case ${flval} in
			0|1|2) flval="fuselevel_nofuse"; ;;
			8)     flval="fuselevel_production"; ;;
			9|d)   flval="fuselevel_production"; baval="SBK"; ;;
			a|e)   flval="fuselevel_production"; baval="PKC"; ;;
			b|f)   flval="fuselevel_production"; baval="SBKPKC"; ;;
			c)     flval="fuselevel_production"; baval="NS"; ;;
			*)     flval="fuselevel_unknown"; ;;
			esac;
		fi;
		eval "${flvar}=\"${flval}\"";
		eval "${bavar}=\"${baval}\"";
	fi;
}

chkerr ()
{
	if [ $? -ne 0 ]; then
		if [ "$1" != "" ]; then
			echo "$1";
		else
			echo "failed.";
		fi;
		exit 1;
	fi;
	if [ "$1" = "" ]; then
		echo "done.";
	fi;
}

cp2local ()
{
	local src=$1;
	if [ "${!src}" = "" ]; then return 1; fi;
	if [ ! -f "${!src}" ]; then return 1; fi;
	if [ "$2" = "" ];      then return 1; fi;
	if [ -f $2 -a ${!src} = $2 ]; then
		local sum1=`sum ${!src}`;
		local sum2=`sum $2`;
		if [ "$sum1" = "$sum2" ]; then
			echo "Existing ${src}($2) reused.";
			return 0;
		fi;
	fi;
	echo -n "copying ${src}(${!src})... ";
	cp -f ${!src} $2;
	chkerr;
	return 0;
}

mkarg ()
{
	local var="$1";
	local varname="$1name";

	eval "${var}=$2";
	if [ -f ${!var} ]; then
		eval "${var}=`readlink -f ${!var}`";
		eval "${varname}=`basename ${!var}`";
		cp2local ${var} "${BL_DIR}/${!varname}";
		if [ $? -ne 0 ]; then
			return 1;
		fi;
	else
		eval "${varname}=$2";
	fi;
	if [ "$3" != "" ]; then
		if [ "$3" = "BINSARGS" ]; then
			eval "${3}+=\"${var} ${!varname}; \"";
		else
			eval "${3}+=\"--${var} ${!varname} \";";
		fi;
	fi;
	return 0;
}

getsize ()
{
	local var="$1";
	local val="$2";
	if [[ ${!val} != *[!0-9]* ]]; then
		eval "${var}=${!val}";
	elif [[ (${!val} == *KiB) && (${!val} != *[!0-9]*KiB) ]]; then
		eval "${var}=$(( ${!val%KiB} * 1024 ))";
	elif [[ (${!val} == *MiB) && (${!val} != *[!0-9]*MiB) ]]; then
		eval "${var}=$(( ${!val%MiB} * 1024 * 1024 ))";
	elif [[ (${!val} == *GiB) && (${!val} != *[!0-9]*GiB) ]]; then
		eval "${var}=$(( ${!val%GiB} * 1024 * 1024 * 1024))";
	else
		echo "Error: Invalid $1: ${!val}";
		exit 1;
	fi;
}

cpcfg ()
{
	local CFGCONV="";

	# BCT: nothing to do.

	# MB1_TAG:
	mkarg mb1file "${MB1FILE}" "";
	CFGCONV+="-e s/MB1NAME/mb1/ ";
	CFGCONV+="-e s/MB1TYPE/mb1_bootloader/ ";
	CFGCONV+="-e s/MB1FILE/${mb1filename}/ ";

	# SPE_TAG:
	if [ "${SPEFILE}" = "" ]; then
		SPEFILE="${BL_DIR}/spe.bin"
	fi;
	mkarg spefile "${SPEFILE}" "";
	CFGCONV+="-e s/SPENAME/spe-fw/ ";
	CFGCONV+="-e s/SPETYPE/spe_fw/ ";
	CFGCONV+="-e s/SPEFILE/${spefilename}/ ";

	# NVC_TAG:
	mkarg tegraboot "${TEGRABOOT}" "";
	CFGCONV+="-e s/MB2NAME/mb2/ ";
	CFGCONV+="-e s/MB2TYPE/mb2_bootloader/ ";
	CFGCONV+="-e s/MB2FILE/${tegrabootname}/ ";
	CFGCONV+="-e s/TEGRABOOT/${tegrabootname}/ ";

	# MPB_TAG:
	CFGCONV+="-e s/MPBNAME/mts-preboot/ ";
	CFGCONV+="-e s/MPBTYPE/mts_preboot/ ";
	CFGCONV+="-e s/MPBFILE/${mts_prebootname}/ ";
	CFGCONV+="-e s/MTSPREBOOT/${mts_prebootname}/ ";

	# GPT_TAG:
	CFGCONV+="-e s/PPTSIZE/16896/ ";

	# APP_TAG:
	getsize    rootfssize	ROOTFSSIZE;
	localsysfile=system.img;
	echo "This is dummy RootFS" > ${BL_DIR}/${localsysfile};
	CFGCONV+="-e s/APPSIZE/${rootfssize}/ ";
	CFGCONV+="-e s/APPFILE/${localsysfile}/ ";

	# MBP_TAG:
	if [ "${tid}" = "0x19" ]; then
		CFGCONV+="-e s/MTS_MCE/${mts_mcename}/ ";
		CFGCONV+="-e s/MTSPROPER/${mts_propername}/ ";
	else
		CFGCONV+="-e s/MBPNAME/mts-bootpack/ ";
		CFGCONV+="-e s/MBPTYPE/mts_bootpack/ ";
		CFGCONV+="-e s/MBPFILE/${mts_bootpackname}/ ";
	fi;

	# TBC_TAG:
	mkarg tbcfile "${TBCFILE}" "";
	CFGCONV+="-e s/TBCNAME/cpu-bootloader/ ";
	CFGCONV+="-e s/TBCTYPE/bootloader/ ";
	CFGCONV+="-e s/TBCFILE/${tbcfilename}/ ";

	# TBCDTB_TAG:
	CFGCONV+="-e s/TBCDTB-NAME/bootloader-dtb/ ";
	CFGCONV+="-e s/TBCDTB-FILE/${bootloader_dtbname}/ ";

	# TOS_TAG:
	CFGCONV+="-e s/TOSNAME/secure-os/ ";
	CFGCONV+="-e s/TOSFILE/${tlkname}/ ";

	# EKS_TAG:
	CFGCONV+="-e s/EKSFILE/${eksname}/ ";

	# BPF_TAG:
	CFGCONV+="-e s/BPFNAME/bpmp-fw/ ";
	CFGCONV+="-e s/BPFSIGN/true/ ";
	CFGCONV+="-e s/BPFFILE/${bpmp_fwname}/ ";

	# BPFDTB_TAG:
	if [ "${tid}" = "0x19" ]; then
		CFGCONV+="-e s/BPFDTB_FILE/${bpmp_fw_dtbname}/ ";
	else
		CFGCONV+="-e s/BPFDTB-NAME/bpmp-fw-dtb/ ";
		CFGCONV+="-e s/BPMPDTB-SIGN/true/ ";
		CFGCONV+="-e s/BPFDTB-FILE/${bpmp_fw_dtbname}/ ";
	fi;

	# SCE_TAG:
	if [ "${SCEFILE}" = "" -o ! -f "${SCEFILE}" ]; then
		SCEFILE="${BL_DIR}/camera-rtcpu-sce.img";
	fi;
	mkarg scefile "${SCEFILE}" "";
	CFGCONV+="-e s/SCENAME/sce-fw/ ";
	CFGCONV+="-e s/SCESIGN/true/ ";
	CFGCONV+="-e s/SCEFILE/${scefilename}/ ";
	if [ "${CAMERAFW}" != "" -a -f "${CAMERAFW}" ]; then
		mkarg camerafw "${CAMERAFW}" "";
		CFGCONV+="-e s/CAMERAFW/${camerafwname}/ ";
	else
		CFGCONV+="-e /CAMERAFW/d ";
	fi;

	# SPE_TAG:
	if [ "${spe_fwname}" != "" ]; then
		CFGCONV+="-e s/SPENAME/spe-fw/ ";
		CFGCONV+="-e s/SPETYPE/spe_fw/ ";
		CFGCONV+="-e s/SPEFILE/${spe_fwname}/ ";
		CFGCONV+="-e s/spe.bin/${spe_fwname}/ ";
	else
		CFGCONF+="-e s/SPETYPE/data/ ";
		CFGCONF+="-e /SPEFILE/d ";
	fi;

	# WB0_TAG:
	mkarg wb0boot "${WB0BOOT}" "";
	CFGCONV+="-e s/SC7NAME/sc7/ ";
	CFGCONV+="-e s/WB0TYPE/WB0/ ";
	CFGCONV+="-e s/WB0FILE/${wb0bootname}/ ";
	CFGCONV+="-e s/WB0BOOT/${wb0bootname}/ ";

	# FB_TAG:
	CFGCONV+="-e s/FBTYPE/data/ ";
	CFGCONV+="-e s/FBSIGN/false/ ";
	CFGCONV+="-e /FBFILE/d ";

	# SOS_TAG:
	CFGCONV+="-e /SOSFILE/d ";

	# LNX_TAG:
	localbootfile=boot.img;
	echo "This is dummy Kernel" > "${BL_DIR}/${localbootfile}";
	CFGCONV+="-e s/LNXNAME/kernel/ ";
	CFGCONV+="-e s/LNXSIZE/67108864/ ";
	CFGCONV+="-e s/LNXFILE/${localbootfile}/ ";

	# DTB_TAG:
	mkarg kernel_dtbfile "${DTB_FILE}" "";
	CFGCONV+="-e s/KERNELDTB-NAME/kernel-dtb/ ";
	CFGCONV+="-e s/KERNELDTB-FILE/${kernel_dtbfilename}/ ";
	CFGCONV+="-e s/DTB_FILE/${kernel_dtbfilename}/ ";

	# DRAMECC_TAG:
	if [ "${DRAMECCFILE}" != "" -a -f "${DRAMECCFILE}" ]; then
		mkarg drameccfile "${DRAMECCFILE}" "";
		CFGCONV+="-e s/DRAMECCNAME/dram-ecc-fw/ ";
		CFGCONV+="-e s/DRAMECCTYPE/dram_ecc/ ";
		CFGCONV+="-e s/DRAMECCFILE/${drameccfilename}/ ";
		CFGCONV+="-e s/dram-ecc.bin/${drameccfilename}/ ";
	else
		CFGCONV+="-e s/DRAMECCTYPE/data/ ";
		CFGCONV+="-e /DRAMECCFILE/d ";
	fi;

	# BADPAGE_TAG:
	if [ "${BADPAGEFILE}" != "" -a -f "${BADPAGEFILE}" ]; then
		mkarg badpagefile "${BADPAGEFILE}" "";
		CFGCONV+="-e s/BADPAGENAME/badpage-fw/ ";
		CFGCONV+="-e s/BADPAGETYPE/black_list_info/ ";
		CFGCONV+="-e s/BADPAGEFILE/${badpagefilename}/ ";
	else
		CFGCONV+="-e s/BADPAGETYPE/data/ ";
		CFGCONV+="-e /BADPAGEFILE/d ";
	fi;

	# CBOOTOPTION_TAG:
	if [ "${CBOOTOPTION_FILE}" != "" -a -f "${CBOOTOPTION_FILE}" ]; then
		mkarg cbootoptionfile "${CBOOTOPTION_FILE}" "";
		CFGCONV+=="-e s/CBOOTOPTION_FILE/${cbootoptionfilename}/ ";
	else
		CFGCONV+="-e /CBOOTOPTION_FILE/d ";
	fi;

	# NCT_TAG:
	CFGCONV+="-e /NCTFILE/d ";
	CFGCONV+="-e s/NCTTYPE/data/ ";

	# EBT_TAG: nothing to do.

	# VER_TAG:
	CFGCONV+="-e /VERFILE/d ";

	# MB2BL_TAG: nothing to do.

	# EFI_TAG:
	CFGCONV+="-e s/EFISIZE/4096/ ";
	CFGCONV+="-e /EFIFILE/d ";

	# REC_TAG:
	CFGCONV+="-e s/RECSIZE/4096/ "
	CFGCONV+="-e /RECFILE/d ";

	# RECDTB_TAG:
	CFGCONV+="-e /RECDTB-FILE/d ";

	# BOOTCTRL_TAG:
	CFGCONV+="-e /BOOTCTRL-FILE/d ";

	# RECROOTFS_TAG:
	CFGCONV+="-e s/RECROOTFSSIZE/4096/ ";

	cat ${1} | sed ${CFGCONV} > ${2}; chkerr;
}

mkfuseargs ()
{
	FUSEARGS="";
	local bldtb;

	# BCTARGS:
	local BD="${TARGET_DIR}/BCT";
	if [ "${tid}" = "0x19" ]; then
		mkarg sdram_config	"${BD}/${EMMC_BCT}"		"";
		mkarg sdram_config1	"${BD}/${EMMC_BCT1}"		"";
		BCTARGS+="--sdram_config ${sdram_configname},";
		BCTARGS+="${sdram_config1name} ";
	else
		mkarg sdram_config	"${BD}/${EMMC_BCT}"		BCTARGS;
	fi;
	mkarg misc_config		"${BD}/${MISC_CONFIG}"		BCTARGS;
	mkarg pinmux_config		"${BD}/${PINMUX_CONFIG}"	BCTARGS;
	mkarg scr_config		"${BD}/${SCR_CONFIG}"		BCTARGS;
	mkarg scr_cold_boot_config	"${BD}/${SCR_COLD_BOOT_CONFIG}"	BCTARGS;
	mkarg pmc_config		"${BD}/${PMC_CONFIG}"		BCTARGS;
	mkarg pmic_config		"${BD}/${PMIC_CONFIG}"		BCTARGS;
	mkarg br_cmd_config		"${BD}/${BOOTROM_CONFIG}"	BCTARGS;
	mkarg prod_config		"${BD}/${PROD_CONFIG}"		BCTARGS;
	mkarg dev_params 		"${BD}/${DEV_PARAMS}"		BCTARGS;
	if [ "${tid}" = "0x19" ]; then
		mkarg misc_cold_boot_config "${BD}/${MISC_COLD_BOOT_CONFIG}" BCTARGS;
		mkarg device_config	"${BD}/${DEVICE_CONFIG}"	BCTARGS;
		if [ "${UPHY_CONFIG}" != "" ]; then
			mkarg uphy_config	"${BD}/${UPHY_CONFIG}"	BCTARGS;
		fi;
		mkarg gpioint_config	"${BD}/${GPIOINT_CONFIG}"	BCTARGS;
		mkarg soft_fuses	"${BD}/${SOFT_FUSES}"		BCTARGS;
	fi;

	# Close BINSARGS before get used for the first time.
	BINSARGS="--bins \"";
	mkarg mb2_bootloader	"${MB2BLFILE}"			BINSARGS;
	mkarg mts_preboot	"${MTSPREBOOT}"			BINSARGS;
	if [ "${tid}" = "0x19" ]; then
		mkarg mts_mce		"${MTS_MCE}"		BINSARGS;
		mkarg mts_proper	"${MTSPROPER}"		BINSARGS;
	else
		mkarg mts_bootpack	"${MTS}"		BINSARGS;
	fi;

	if [ "${TBCDTB_FILE}" != "" -a \
	     -f "${TARGET_DIR}/${TBCDTB_FILE}" ]; then
		bldtb="${TARGET_DIR}/${TBCDTB_FILE}";
	elif [ "${DTB_FILE}" != "" -a  -f "${DTB_DIR}/${DTB_FILE}" ]; then
		bldtb="${DTB_DIR}/${DTB_FILE}";
	else
		echo "*** Error: bootloader DTB not found.";
		exit 1;
	fi;
	mkarg bootloader_dtb	"${bldtb}"			BINSARGS;
	mkarg bpmp_fw		"${BPFFILE}"			BINSARGS;
	mkarg bpmp_fw_dtb	"${TARGET_DIR}/${BPFDTB_FILE}"	BINSARGS;
	mkarg tlk		"${TOSFILE}"			BINSARGS;
	mkarg eks		"${EKSFILE}"			BINSARGS;
	if [ "${tid}" = "0x19" ]; then
		localbootfile=boot.img;
		echo "This is dummy Kernel" > "${BL_DIR}/${localbootfile}";
		mkarg kernel		"${localbootfile}"	BINSARGS;
		mkarg kernel_dtb	"${DTB_FILE}"		BINSARGS;
		mkarg spe_fw		"${SPEFILE}"		BINSARGS;
	fi;

	BINSARGS+="\"";
	BINSCONV+="-e s/\"[[:space:]]*/\"/ ";
	BINSCONV+="-e s/\;[[:space:]]*\"/\"/ ";
	BINSARGS=`echo "${BINSARGS}" | sed ${BINSCONV}`;

	FUSEARGS+="${BCTARGS} ${BINSARGS} ";
	localcfg="flash.xml";
	cpcfg "${TARGET_DIR}/cfg/${EMMC_CFG}" "${BL_DIR}/${localcfg}";
	mkarg cfg	"${BL_DIR}/${localcfg}"	FUSEARGS;
	mkarg bl	"${FLASHER}"		FUSEARGS;
	if [ "${ODMDATA}" = "" ]; then
		ODMDATA=0x10900000;		# Default Jetson TX2 ODMDATA.
	fi;
	mkarg odmdata	"${ODMDATA}"		FUSEARGS;
	mkarg chip	"${tid}"		FUSEARGS;
	mkarg applet	"${SOSFILE}"		FUSEARGS;
}

get_board_version ()
{
	local args="";
	local __board_id=$1;
	local __board_version=$2;
	local __board_sku=$3;
	local __board_revision=$4;
	local command="dump eeprom boardinfo cvm.bin"
	local boardid;
	local boardversion;
	local boardsku;
	local boardrevision;
	if [ -n "${usb_instance}" ]; then
		args+="--instance ${usb_instance} ";
	fi;
	if [ "${CHIPMAJOR}" != "" ]; then
		args+="--chip \"${CHIPID} ${CHIPMAJOR}\" ";
	else
		args+="--chip ${CHIPID} ";
	fi;
	args+="--applet \"${LDK_DIR}/${SOSFILE}\" ";
	args+="${SKIPUID} ";
	if [ "${CHIPID}" = "0x19" ]; then
		mkarg soft_fuses     "${TARGET_DIR}/BCT/${SOFT_FUSES}" "";
		cp2local soft_fuses "${BL_DIR}/${soft_fusesname}";
		args+="--soft_fuses ${soft_fusesname} "
		args+="--bins \"mb2_applet ${MB2APPLET}\" ";
		command+=";reboot recovery"
		# board is rebooted so SKIPUID is not needed anymore
		SKIPUID=""
	fi
	args+="--cmd \"${command}\" ";
	local cmd="./tegraflash.py ${args}";
	pushd "${BL_DIR}" > /dev/null 2>&1;
	if [ "${KEYFILE}" != "" ]; then
		cmd+="--key \"${KEYFILE}\" ";
	fi;
	if [ "${SBKFILE}" != "" ]; then
		cmd+="--encrypt_key \"${SBKFILE}\" ";
	fi;
	echo "${cmd}";
	eval "${cmd}";
	chkerr "Reading board information failed.";
	if [ "${SKIP_EEPROM_CHECK}" = "" ]; then
		boardid=`./chkbdinfo -i cvm.bin`;
		boardversion=`./chkbdinfo -f cvm.bin`;
		boardsku=`./chkbdinfo -k cvm.bin`;
		boardrevision=`./chkbdinfo -r cvm.bin`;
		chkerr "Parsing board information failed.";
	fi;
	popd > /dev/null 2>&1;
	eval ${__board_id}="${boardid}";
	eval ${__board_version}="${boardversion}";
	eval ${__board_sku}="${boardsku}";
	eval ${__board_revision}="${boardrevision}";
}

check_sbk_pkc()
{
	local __auth=$1;
	local __pkc=$2;
	local __sbk=$3;

	case ${__auth} in
		PKC)
			if [ "${__pkc}" = "" ] || [ "${__sbk}" != "" ]; then
				echo -n "Error: Either RSA key file is not provided or SBK key ";
				echo "file is provided for PKC protected target board.";
				exit 1;
			fi;
			;;
		SBKPKC)
			if [ "${__pkc}" = "" ] || [ "${__sbk}" = "" ]; then
				echo -n "Error: Either RSA key file and/or SBK key file ";
				echo "is not provided for SBK and PKC protected target board.";
				exit 1;
			fi;
			;;
		SBK)
			echo "Error: L4T does not support SBK protected target board.";
			exit 1;
			;;
		NS)
			if [ "${keyfile}" != "" ] || [ "${sbk_keyfile}" != "" ]; then
				echo -n "Error: either RSA key file and/or SBK key file ";
				echo "are provided for none SBK and PKC protected target board.";
				exit 1;
			fi;
			;;
	esac;
}

# main starts
while getopts "c:i:k:s:" OPTION
do
	case $OPTION in
	c) Ctype=${OPTARG}; ;;
	i) tid="${OPTARG}"; ;;
	k) KEYFILE="${OPTARG}"; ;;
	s) SBKFILE="${OPTARG}"; ;;
	*) usage; ;;
	esac
done

if [ "${Ctype}" = "" ]; then
	echo "Error: crypto_type is missing.";
	usage;
fi;
if [ "${Ctype}" != "NS" ] && [ "${Ctype}" != "PKC" ]; then
	echo "Error: unsupported crypto_type: ${Ctype}";
	usage;
fi;

if [ "${Ctype}" = "PKC" ] && [ "${KEYFILE}" = "" ]; then
	echo "Error: the public key is required when crypto_type is PKC.";
	usage;
fi;

if [ "${SBKFILE}" != "" ] && [ "${KEYFILE}" = "" ]; then
	echo "L4T doesn't support SBK by itself. Make sure your public key is set."
	exit 1;
fi;

if [ "${tid}" = "" ]; then
	echo "Error: chip_id is missing.";
	usage;
fi;
if [ "${tid}" != "0x18" ] && [ "${tid}" != "0x19" ]; then
	echo "Error: Unsupported chip_id: ${tid}";
	usage;
fi;

SKIPUID=""
shift $(($OPTIND - 1));
if [ $# -ne 1 ]; then
	echo "Error: target_board is not set correctly."
	usage;
fi;
cmd_target_board=${1};
if [ ! -r "${cmd_target_board}".conf ]; then
	echo -n "Error: Invalid target board - ";
	echo "${cmd_target_board}.conf is not found.";
	exit 1;
fi;

LDK_DIR=$(cd `dirname $0` && pwd);
LDK_DIR=`readlink -f "${LDK_DIR}"`;
source ${cmd_target_board}.conf
BL_DIR="${LDK_DIR}/bootloader";
TARGET_DIR="${BL_DIR}/${target_board}";
KERNEL_DIR="${LDK_DIR}/kernel";
DTB_DIR="${KERNEL_DIR}/dtb";

get_fuse_level fuselevel hwchipid bootauth;
check_sbk_pkc "${bootauth}" "${KEYFILE}" "${SBKFILE}";
declare -F -f process_fuse_level > /dev/null 2>&1;
if [ $? -eq 0 ]; then
	process_fuse_level "${fuselevel}";
fi;

bd_ver="${FAB}";
bd_id="${BOARDID}";
bd_sku="${BOARDSKU}";
bd_rev="${BOARDREV}";
# get the board version and update the data accordingly
declare -F -f process_board_version > /dev/null 2>&1;
if [ $? -eq 0 ]; then
	get_board_version bd_id bd_ver bd_sku bd_rev;
	BOARDID="${bd_id}";
	BOARDSKU="${bd_sku}";
	FAB="${bd_ver}";
	BOARDREV="${bd_rev}";
	if [ "${CHIPREV}" != "" ]; then
		hwchiprev="${CHIPREV}";
	fi;
	process_board_version "${bd_id}" "${bd_ver}" "${bd_sku}" "${bd_rev}" "${hwchiprev}";
fi;
mkfuseargs;

pushd "${BL_DIR}" >& /dev/null;
READ_CMD="./tegraflash.py ${FUSEARGS} ${SKIPUID} ";
OUTPUT_FILE="fuse_info.txt";
if [ "${Ctype}" = "PKC" ]; then
	READ_CMD+="--key \"${KEYFILE}\" ";
fi;
if [ "${SBKFILE}" != "" ]; then
	READ_CMD+="--encrypt_key \"${SBKFILE}\" ";
fi;

FUSE_XML="fuses_to_read.xml";
t18x_fuses_to_read=("PublicKeyHash" "BootSecurityInfo" "JtagDisable" "OdmLock" "SecurityMode"
			   "ReservedOdm0" "ReservedOdm1" "ReservedOdm2" "ReservedOdm3"
			   "ReservedOdm4" "ReservedOdm5" "ReservedOdm6" "ReservedOdm7"
			   "SwReserved" "SecureBootKey" "Kek0" "Kek1" "Kek2" "Kek256");
t19x_fuses_to_read=("PublicKeyHash" "BootSecurityInfo" "JtagDisable" "OdmLock" "SecurityMode"
			   "ReservedOdm0" "ReservedOdm1" "ReservedOdm2" "ReservedOdm3"
			   "ReservedOdm4" "ReservedOdm5" "ReservedOdm6" "ReservedOdm7"
			   "ReservedOdm8" "ReservedOdm9" "ReservedOdm10" "ReservedOdm11"
			   "SwReserved" "SecureBootKey" "Kek0" "Kek1" "Kek2" "Kek256");
magicid="";	# BigEndian format
echo "<genericfuse MagicId=\"0x45535546\" version=\"1.0.0\">" > "${FUSE_XML}";
if [ "${tid}" = "0x18" ]; then
	for f in ${t18x_fuses_to_read[@]}; do
		echo "<fuse name=\"${f}\" />" >> "${FUSE_XML}";
	done;
fi;
if [ "${tid}" = "0x19" ]; then
	for f in ${t19x_fuses_to_read[@]}; do
		echo "<fuse name=\"${f}\" />" >> "${FUSE_XML}";
	done;
fi;

echo "</genericfuse>" >> "${FUSE_XML}";

READ_CMD+="--cmd \"readfuses ${OUTPUT_FILE} ${FUSE_XML}\"";
echo "${READ_CMD}";
eval "${READ_CMD}";
if [ $? -ne 0 ]; then
	echo "Error: read fuse info failed.";
	exit 1;
fi;
echo "Fuse reading is done. The fuse values have been saved in: "${BL_DIR}"/"${OUTPUT_FILE}""
cat "${BL_DIR}"/"${OUTPUT_FILE}"
popd >& /dev/null;
