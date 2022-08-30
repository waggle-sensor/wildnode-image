#!/bin/bash

# Copyright (c) 2015-2020, NVIDIA CORPORATION.  All rights reserved.
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
# odmfuse.sh: Fuse the target board.
#	    odmfuse performs the best in L4T fuse environment.
#
# Usage: Place the board in recovery mode and run:
#
#	./odmfuse.sh -c <cryptoType> -i <TegraID> [-k <KeyFile>] [Target Board]
#
#	for more detail enter 'odmfuse -h'
#
# Examples for Jetson Xavier:
#   1. Secure fuse without any boot authentication:
#      ./odmfuse.sh -i 0x19 -c NS -p jetson-xavier
#   2. Secure fuse with PKC:
#      ./odmfuse.sh -i 0x19 -c PKC -p -k <KeyFile> jetson-xavier
#   3. Secure fuse with PKC and encryption service preparation:
#      ./odmfuse.sh -i 0x19 -c PKC -p -k <KeyFile> -S <SBK> jetson-xavier
#
# Examples for Jetson TX2:
#   1. Secure fuse without any boot authentication:
#      ./odmfuse.sh -i 0x18 -c NS -p jetson-tx2
#   2. Secure fuse with PKC:
#      ./odmfuse.sh -i 0x18 -c PKC -p -k <KeyFile> jetson-tx2
#   3. Secure fuse with PKC and encryption service preparation:
#      ./odmfuse.sh -i 0x18 -c PKC -p -k <KeyFile> -S <SBK> jetson-tx2
#
# Examples for Jetson TX1:
#   1. Secure fuse without any boot authentication:
#      ./odmfuse.sh -i 0x21 -c NS -p
#   2. Secure fuse with PKC:
#      ./odmfuse.sh -i 0x21 -c PKC -p -k <KeyFile>
#   3. Secure fuse with PKC and encryption service preparation:
#      ./odmfuse.sh -i 0x21 -c PKC -p -k <KeyFile> -D <DK file> -S <SBK file>
#
# Examples for Jetson TK1:
#   1. Secure fuse without any boot authentication:
#      ./odmfuse.sh -i 0x40 -c NS -p
#   2. Secure fuse with PKC:
#      ./odmfuse.sh -i 0x40 -c PKC -p -k <KeyFile>
#   3. Secure fuse with PKC and encryption service preparation:
#      ./odmfuse.sh -i 0x40 -c PKC -p -k <KeyFile> -D <DK file> -S <SBK file>
#

validateMaster ()
{
	if [[ "$1" =~ ^[^@]{1,}@[^@]{1,}$ ]]; then
		return 0;
	fi;
	echo "Error: dbmaster is not in <user>@<db server> format.";
	exit 1;
}

#
# Regardless of TegraID, all HEX inputs(DK, KEK, SBK, HASH) should be in
# single Big Endian format. This routine should not only check the
# input format but also convert to LE format.
#
chkhash ()
{
	local i;
	local keyname=$1;
	local keylen=$2;
	local keystr="${!keyname}";
	local le="";
	local resid=0;

	# 1. Check single HEX format.
	if [[ ${keystr} =~ ^0[xX] ]]; then
		keystr=${keystr:2};
	fi;
	keylen=$(( keylen * 2 ));
	if [ ${keylen} -ne ${#keystr} ]; then
		echo "Error: The length of ${keystr} = ${#keystr} != ${keylen}";
		exit 1;
	fi;
	resid=$((keylen % 8));
	if [ $resid -ne 0 ]; then
		echo "Error: ${keyname} length is not modulo 32bit";
		exit 1;
	fi;

	if [[ "${keystr}" = *[^[:alnum:]]* ]]; then
		echo "Error: ${keyname} has non-alphanumeric value";
		exit 1;
	fi;

	if [[ "${keystr}" =~ [g-zG-Z] ]]; then
		echo "Error: ${keyname} is not in HEX format.";
		exit 1;
	fi;

	# 2. Convert to Little Endian.
	# 3. Split to multiple 32 HEX string if necessary.
	if [ "${tid}" = "0x40" ]; then
		local tmpstr="";
		local n=$(( keylen + 7 ));
		n=$(( n / 8 ));
		local lastn=$((n - 1));
		for (( i=0; i<n; i++ )); do
			local s=$((i * 8));
			local tmple="${keystr:$s}";
			tmpstr+="0x${tmple:6:2}${tmple:4:2}";
			tmpstr+="${tmple:2:2}${tmple:0:2}";
			if [ $i -lt $lastn ]; then
				tmpstr+=" ";
			fi;
			keylen=$((keylen - 8));
		done;
		eval "${keyname}=\"${tmpstr}\"";
	elif [ "${tid}" != "0x18" -a "${tid}" != "0x19" ]; then
		i=${#keystr}
		while [ $i -gt 0 ]; do
			i=$[$i-2]
			le+="${keystr:$i:2}"
		done;
		eval "${keyname}=0x\"${le}\"";
	fi;
}

#
# Convert Little Endian hashes to single Big Endian HEX.
#
convhash ()
{
	local le="";
	local be="";
	local keyname=$1;
	local keylen=$2;
	local keystr="${!keyname}";

	# 1. Consolidate multiple hash tokens into single HEX format.
	if [ "${tid}" = "0x40" ]; then
		local keyarr="${keyname}arr";
		local n=$(( keylen * 2 ));
		n=$(( n + 7 ));
		n=$(( n / 8 ));
		OIFS=${IFS};
		IFS=' ';
		keyarr=(${keystr});
		IFS=${OIFS};
		if (( ${n}!=${#keyarr[@]} )); then
			echo "*** Error: bad ${keyname} length."
			exit 1;
		fi;

		for (( i=0; i<${n}; i++ )); do
			if ! [[ ${keyarr[$i]} =~ ^0x[0-9,A-F,a-f]{8} ]]; then
				echo "*** Error: bad ${keyname} element.";
				exit 1;
			fi;
			le+="${keyarr[$i]:8:2}${keyarr[$i]:6:2}";
			le+="${keyarr[$i]:4:2}${keyarr[$i]:2:2}";
		done;
		be=${le};
	else
		if [[ ${keystr} =~ ^0[xX] ]]; then
			le=${keystr:2};
		fi;
		local i=${#le}
		while [ $i -gt 0 ]; do
			i=$[$i-2]
			be+="${le:$i:2}"
		done;
	fi;

	# 2. Set the global variable with new value.
	eval "${keyname}=0x\"${be}\"";
}

factory_overlay_gen ()
{
	local fusecmd="$1";
	local fuseconf="$2";
	local boardcmd="$3";
	local srcdir="bootloader";

	echo "*** Start preparing fuse configuration ... ";
	local fusecmdfile="fusecmd.sh"
	echo "#!/bin/bash" >  "${fusecmdfile}";
	echo "set -e" >> "${fusecmdfile}";
	if [ -n "${boardcmd}" ] && [ "${tid}" = "0x19" ]; then
		echo "eval '${boardcmd}'" >> "${fusecmdfile}";
	fi;
	echo "eval '${fusecmd}'" >> "${fusecmdfile}";
	chmod +x "${fusecmdfile}";
	popd > /dev/null 2>&1;
	cp -f pkc/mkpkc "${srcdir}";
	rm -f "${srcdir}"/*.raw;
	fuselist="${srcdir}/${fuseconf} ";
	fuselist+="${srcdir}/${fusecmdfile} ";
	fuselist+="${srcdir}/mkpkc ";
	if [ "${tid}" = "0x40" ]; then
		fuselist+="${srcdir}/nvflash ";
		fuselist+="${srcdir}/fastboot.bin ";
	elif [ "${tid}" = "0x21" ]; then
		fuselist+="${srcdir}/nvtboot_recovery.bin ";
		fuselist+="${srcdir}/tegraflash_internal.py ";
		fuselist+="${srcdir}/tegraflash.py ";
		fuselist+="${srcdir}/tegraparser ";
		fuselist+="${srcdir}/tegrarcm ";
		fuselist+="${srcdir}/tegrasign ";
	elif [ "${tid}" = "0x18" -o "${tid}" = "0x19" ]; then
		fuselist+="${srcdir}/tegrabct_v2 ";
		fuselist+="${srcdir}/tegradevflash_v2 ";
		fuselist+="${srcdir}/tegraflash.py ";
		fuselist+="${srcdir}/tegraflash_internal.py ";
		fuselist+="${srcdir}/tegrahost_v2 ";
		fuselist+="${srcdir}/tegraparser_v2 ";
		fuselist+="${srcdir}/tegrarcm_v2 ";
		fuselist+="${srcdir}/tegrasign_v2 ";
		if [ "${tid}" = "0x19" ]; then
			fuselist+="${srcdir}/sw_memcfg_overlay.pl ";
		fi;

		fuselist+="${srcdir}/${sdram_configname} ";
		fuselist+="${srcdir}/${misc_configname} ";
		fuselist+="${srcdir}/${pinmux_configname} ";
		fuselist+="${srcdir}/${scr_configname} ";
		fuselist+="${srcdir}/${scr_cold_boot_configname} ";
		fuselist+="${srcdir}/${pmc_configname} ";
		fuselist+="${srcdir}/${pmic_configname} ";
		fuselist+="${srcdir}/${br_cmd_configname} ";
		fuselist+="${srcdir}/${prod_configname} ";
		fuselist+="${srcdir}/${dev_paramsname} ";

		fuselist+="${srcdir}/${mb2_bootloadername} ";
		if [ "${tid}" = "0x19" ]; then
			fuselist+="${srcdir}/${MB2APPLET} ";
		fi;
		fuselist+="${srcdir}/${mts_prebootname} ";
		if [ "${tid}" = "0x19" ]; then
			fuselist+="${srcdir}/${sdram_config1name} ";
			fuselist+="${srcdir}/${mts_mcename} ";
			fuselist+="${srcdir}/${mts_propername} ";
		else
			fuselist+="${srcdir}/${mts_bootpackname} ";
		fi;
		fuselist+="${srcdir}/${bootloader_dtbname} ";
		fuselist+="${srcdir}/${bpmp_fwname} ";
		fuselist+="${srcdir}/${bpmp_fw_dtbname} ";
		fuselist+="${srcdir}/${tlkname} ";
		fuselist+="${srcdir}/${eksname} ";

		fuselist+="${srcdir}/${appletname} ";
		fuselist+="${srcdir}/${blname} ";
		fuselist+="${srcdir}/${cfgname} ";

		fuselist+="${srcdir}/${mb1filename} ";
		fuselist+="${srcdir}/${spefilename} ";
		fuselist+="${srcdir}/${tegrabootname} ";
		fuselist+="${srcdir}/${localsysfile} ";
		fuselist+="${srcdir}/${tbcfilename} ";
		fuselist+="${srcdir}/${scefilename} ";
		fuselist+="${srcdir}/${wb0bootname} ";
		fuselist+="${srcdir}/${localbootfile} ";
		fuselist+="${srcdir}/${kernel_dtbfilename} ";
		if [ "${tid}" = "0x19" ]; then
			fuselist+="${srcdir}/${soft_fusesname} ";
			if [ "${uphy_configname}" != "" ]; then
				fuselist+="${srcdir}/${uphy_configname} ";
			fi;
			fuselist+="${srcdir}/${device_configname} ";
			fuselist+="${srcdir}/${misc_cold_boot_configname} ";
			fuselist+="${srcdir}/${gpioint_configname} ";
		fi;

		# Optional files:
		if [ -f "${srcdir}/slot_metadata.bin" ]; then
			fuselist+="${srcdir}/slot_metadata.bin ";
		fi;
		if [ -f "${srcdir}/xusb_sil_rel_fw" ]; then
			fuselist+="${srcdir}/xusb_sil_rel_fw ";
		fi;
		if [ -f "${srcdir}/adsp-fw.bin" ]; then
			fuselist+="${srcdir}/adsp-fw.bin ";
		fi;
		if [ -f "${srcdir}/bmp.blob" ]; then
			fuselist+="${srcdir}/bmp.blob ";
		fi;
		if [ "${camerafwname}" != "" -a \
			-f "${srcdir}/${camerafwname}" ]; then
			fuselist+="${srcdir}/${camerafwname} ";
		fi;
		if [ "${cbootoptionfilename}" != "" -a \
			-f "${srcdir}/${cbootoptionfilename}" ]; then
			fuselist+="${srcdir}/${cbootoptionfilename} ";
		fi;
	else
		echo "Error: Not supported yet.";
		exit 1;
	fi;
	tar cjf fuseblob.tbz2 ${fuselist};
	echo "*** done.";
}

usage ()
{
	if [ "${KEYVIADB}" = "" ]; then
		if [ "${tid}" = "0x18" -o "${tid}" = "0x19" ]; then
			cat << EOF
Usage:
  ./odmfuse.sh -c <CryptoType> -i <TegraID> -k <KeyFile> [options] TargetBoard

  Where options are,
    -c <CryptoType> ------ NS -- No Crypto, PKC - Public Key Crypto.
    -d <0xXXXX> ---------- sets sec_boot_dev_cfg=0xXXXX&0x3fff.
    -i <TegraID> --------- tegra ID: 0x40-TK1, 0x21-TX1, 0x18-TX2, 0x19-Xavier
    -j ------------------- Keep jtag enabled.
    -k <KeyFile> --------- 2048 bit RSA private KEY file. (.pem file)
    -l <0xXXX> ----------- sets odm_lock=0xXXX. (T186:8bit, T194:12bit)
    -p ------------------- sets production mode.
    -r <0xXX> ------------ sets sw_reserved=0xXX.
    -S <SBK file> -------- 128bit Secure Boot Key file in HEX format.
    --noburn ------------- Prepare fuse blob without actual burning.
    --test --------------- No fuses will be really burned, for test purpose.
    --KEK0 <Key file> ---- 128bit Key Encryption Key file in HEX format.
    --KEK1 <Key file> ---- 128bit Key Encryption Key file in HEX format.
    --KEK2 <Key file> ---- 128bit Key Encryption Key file in HEX format.
    --KEK256 <Key file> -- 256bit Key Encryption Key file in HEX format.
    --odm_reserved[0-7] -- sets 32bit ReservedOdm[0-7]. (Input=0xXXXXXXXX)
    --odm_reserved[8-11] -- sets 32bit ReservedOdm[8-11] (T194 only)
EOF
		else
			cat << EOF
Usage:
  ./odmfuse.sh -c <CryptoType> -i <TegraID> -k <KeyFile> [options]

  Where options are,
    -c <CryptoType> ------ NS -- No Crypto, PKC - Public Key Crypto.
    -d <0xXXXX> ---------- sets sec_boot_dev_cfg=0xXXXX&0x3fff.
    -i <TegraID> --------- tegra ID: 0x40-TK1, 0x21-TX1
    -j ------------------- Keep jtag enabled.
    -k <KeyFile> --------- 2048 bit RSA private KEY file. (.pem file)
    -l <0xX> ------------- sets odm_lock=0xX.
    -o <8-0xXXXXXXXX> ---- sets odm_reserved=<8-0xXXXXXXXX>
                           1 256bit Big Endian value.
    -p ------------------- sets production mode.
    -r <0xXX> ------------ sets sw_reserved=0xXX.
    -D <DK file> --------- 32bit Device Key file in HEX format (TK1 & TX1 only).
    -S <SBK file> -------- 128bit Secure Boot Key file in HEX format.
    --noburn ------------- Prepare fuse blob without actual burning.
    --test --------------- No fuses will be really burned, for test purpose.
EOF
		fi;
	else
		cat << EOF
Usage: ./odmfuse.sh [options] -c <CryptoType> -i <Tegra ID> <master> <SN> [item]
  Where,
    -c <CryptoType> ------ NS -- No Crypto, PKC - Public Key Crypto.
    -d <0xXXXX> ---------- sets sec_boot_dev_cfg=0xXXXX&0x3fff.
    -i <TegraID> --------- tegra ID: 0x40-TK1, 0x21-TX1, 0x18-TX2, 0x19-Xavier
    -j ------------------- Keep jtag enabled.
    -l <0xX> ------------- sets odm_lock=0xX.
    -o <8-0xXXXXXXXX> ---- sets odm_reserved=<8-0xXXXXXXXX>
                           8 32bit values MUST be quoted.
    -p ------------------- sets production mode.
    -r <0xXX> ------------ sets sw_reserved=0xXX.
    -s <sku> ------------- Board SKU.
    --test --------------- No fuses will be really burned, for test purpose.

    master --------------- PKC DB master in <user>@<server> format.
    SN ------------------- Target board's Serial Number n arbitrary format.
    item ----------------- one DB column to be fetched:
                           id,sku,type,pub,hash,fusecnt,signcnt,ctime,atime
EOF
	fi;
	exit 1;
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
	else
		echo "Error: ECID read failed.";
		echo "The target board must be attached in RCM mode.";
		exit 1;
	fi;
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
	if [ "${keyfile}" != "" ]; then
		cmd+="--key \"${keyfile}\" ";
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

get_board_version_cmd ()
{
	local args="";
	local __board_command=$1;
	local command="dump eeprom boardinfo cvm.bin"
	if [ -n "${usb_instance}" ]; then
		args+="--instance ${usb_instance} ";
	fi;
	if [ "${CHIPMAJOR}" != "" ]; then
		args+="--chip \"${CHIPID} ${CHIPMAJOR}\" ";
	else
		args+="--chip ${CHIPID} ";
	fi;
	args+="--applet \"${SOSFILE##*/}\" ";
	if [ "${CHIPID}" = "0x19" ]; then
		mkarg soft_fuses     "${TARGET_DIR}/BCT/${SOFT_FUSES}" "";
		cp2local soft_fuses "${BL_DIR}/${soft_fusesname}";
		args+="--soft_fuses ${soft_fusesname} "
		args+="--bins \"mb2_applet ${MB2APPLET}\" ";
		command+=";reboot recovery"
	fi
	args+="--cmd \"${command}\" ";
	local cmd="./tegraflash.py ${args}";
	if [ "${keyfile}" != "" ]; then
		cmd+="--key \"${keyfile}\" ";
	fi;
	eval ${__board_command}="'${cmd}'";
}

noburn=0;
testmode=0;
jtag_disable="yes";
while getopts "c:d:i:jk:l:o:pr:s:D:H:S:X:-:" OPTION
do
	case $OPTION in
	c) Ctype=${OPTARG}; pkcopt+="-f ${Ctype} "; ;;
	d) BootDevCfg="${OPTARG}"; ;;
	i) tid="${OPTARG}"; pkcopt+="-i ${tid} "; ;;
	j) jtag_disable="no"; ;;
	k) KEYFILE="${OPTARG}"; ;;
	l) odm_lock="${OPTARG}"; ;;
	o) odm_reserved="${OPTARG}"; ;;
	p) set_productionmode="yes"; ;;
	r) sw_reserved="${OPTARG}"; ;;
	s) sku=${OPTARG}; pkcopt+="-s ${sku} "; ;;
	D) DKFILE="${OPTARG}"; ;;
	H) HASHFILE=${OPTARG}; ;;
	S) SBKFILE="${OPTARG}"; ;;
	X) XFILE="${OPTARG}"; ;;
	-) case ${OPTARG} in
	   noburn) noburn=1; ;;
	   test) testmode=1; ;;
	   KEK0) KEK0FILE="${!OPTIND}"; OPTIND=$((OPTIND+1));;
	   KEK1) KEK1FILE="${!OPTIND}"; OPTIND=$((OPTIND+1));;
	   KEK2) KEK2FILE="${!OPTIND}"; OPTIND=$((OPTIND+1));;
	   KEK256) KEK256FILE="${!OPTIND}"; OPTIND=$((OPTIND+1));;
	   odm_reserved0) odm_reserved0="${!OPTIND}"; OPTIND=$((OPTIND+1));;
	   odm_reserved1) odm_reserved1="${!OPTIND}"; OPTIND=$((OPTIND+1));;
	   odm_reserved2) odm_reserved2="${!OPTIND}"; OPTIND=$((OPTIND+1));;
	   odm_reserved3) odm_reserved3="${!OPTIND}"; OPTIND=$((OPTIND+1));;
	   odm_reserved4) odm_reserved4="${!OPTIND}"; OPTIND=$((OPTIND+1));;
	   odm_reserved5) odm_reserved5="${!OPTIND}"; OPTIND=$((OPTIND+1));;
	   odm_reserved6) odm_reserved6="${!OPTIND}"; OPTIND=$((OPTIND+1));;
	   odm_reserved7) odm_reserved7="${!OPTIND}"; OPTIND=$((OPTIND+1));;
	   odm_reserved8) odm_reserved8="${!OPTIND}"; OPTIND=$((OPTIND+1));;
	   odm_reserved9) odm_reserved9="${!OPTIND}"; OPTIND=$((OPTIND+1));;
	   odm_reserved10) odm_reserved10="${!OPTIND}"; OPTIND=$((OPTIND+1));;
	   odm_reserved11) odm_reserved11="${!OPTIND}"; OPTIND=$((OPTIND+1));;
	   *) usage; ;;
	   esac;;
	*) usage; ;;
	esac
done

if [ "${tid}" = "" ]; then
	echo "*** Error: Tegra ID is missing.";
	usage;
fi;
if [ "${tid}" != "0x40" -a "${tid}" != "0x21" -a "${tid}" != "0x18" -a \
	"${tid}" != "0x19" ]; then
	echo "*** Error: Unsupported Tegra ID ${tid}.";
	exit 1;
fi;

shift $((OPTIND - 1));
SKIPUID=""
if [ -f "${PWD}/pkc/keyviadb" ]; then
	KEYVIADB="yes";
	if [ $# -lt 2 ]; then
		usage;
	fi;
	master=$1;
	validateMaster ${master};
	sn=$2;

	if [ "${SUDO_USER}" != "" ]; then
		sudocmd="sudo -u ${SUDO_USER}";
	fi;

	if [ $# -gt 2 ]; then
		if [ "$3" == "all" ]; then
			colst="SN,ID,SKU,TYPE,FUSECNT, SIGNCNT, CTIME, ATIME";
			pkcmd="bash -l -c 'mkpkc getcol ${sn} \"${colst}\"'";
		else
			pkcmd="bash -l -c 'mkpkc getcol ${sn} $3'";
		fi;
		${sudocmd} ssh ${master} "${pkcmd}";
		exit $?;
	fi;
else
	if [ "${tid}" = "0x18" -o "${tid}" = "0x19" ]; then
		if [ $# -ne 1 ]; then
			usage;
		fi;
		if [ $# -eq 1 ]; then
			nargs=$#;
			ext_target_board=${!nargs};
			if [ ! -r ${ext_target_board}.conf ]; then
				echo -n "Error: Invalid target board - ";
				echo "${ext_target_board}";
				exit 1;
			fi;

			# set up environments:
			LDK_DIR=$(cd `dirname $0` && pwd);
			LDK_DIR=`readlink -f "${LDK_DIR}"`;
			source ${ext_target_board}.conf
			BL_DIR="${LDK_DIR}/bootloader";
			TARGET_DIR="${BL_DIR}/${target_board}";
			KERNEL_DIR="${LDK_DIR}/kernel";
			DTB_DIR="${KERNEL_DIR}/dtb";

			# Check fuse-level:
			if [ $noburn -eq 0 -o \
				"${FAB}" = "" -a \
				"${BOARDID}" = "" -a \
				"${BOARDSKU}" = "" -a \
				"${BOARDREV}" = "" \
				]; then
				get_fuse_level fuselevel hwchipid bootauth;
			else
				fuselevel="fuselevel_production";
				hwchipid="${CHIPID}";
				bootauth="None";
				hwchiprev="0";
			fi;
			if [ "${fuselevel}" != "fuselevel_production" ]; then
				echo "Error: Cannot fuse non-production board.";
				exit 1;
			fi;
			declare -F -f process_fuse_level > /dev/null 2>&1;
			if [ $? -eq 0 ]; then
				process_fuse_level "${fuselevel}";
			fi;

			bd_ver="${FAB}";
			bd_id="${BOARDID}";
			bd_sku="${BOARDSKU}";
			bd_rev="${BOARDREV}";
			bd_cmd="";
			# get the board version and update the data accordingly
			declare -F -f process_board_version > /dev/null 2>&1;
			if [ $? -eq 0 ]; then
				if [ $noburn -eq 0 -o \
					"${FAB}" = "" -a \
					"${BOARDID}" = "" -a \
					"${BOARDSKU}" = "" -a \
					"${BOARDREV}" = "" \
					]; then
					get_board_version bd_id bd_ver bd_sku bd_rev;
					BOARDID="${bd_id}";
					BOARDSKU="${bd_sku}";
					FAB="${bd_ver}";
					BOARDREV="${bd_rev}";
				else
					get_board_version_cmd bd_cmd;
				fi;
				if [ "${CHIPREV}" != "" ]; then
					hwchiprev="${CHIPREV}";
				fi;
				process_board_version "${bd_id}" "${bd_ver}" "${bd_sku}" "${bd_rev}" "${hwchiprev}";
			fi;
			mkfuseargs;
		fi;
	else
		if [ $# -ne 0 ]; then
			usage;
		fi;
	fi;
	export PATH="${PWD}/pkc:${PATH}";
	if [ ! -f "${PWD}/pkc/sha2_key" ]; then
		USEOPENSSL="yes";
	fi;
fi;

if [ "${DKFILE}" != "" ]; then
	if [ "${tid}" != "0x40" -a "${tid}" != "0x21" ]; then
		echo "Error: Device Key is not supported for TX2";
		exit 1;
	fi;
	if [ ! -f "${DKFILE}" ]; then
		echo "*** Error: ${DKFILE} doesn't exits.";
		exit 1;
	fi;
	DKFILE=`readlink -f "${DKFILE}"`;
	if [ "${SBKFILE}" = "" ]; then
		echo "*** Error: SBK is missing.";
		exit 1;
	fi;
fi;

if [ "${HASHFILE}" != "" ]; then
	if [ ! -f "${HASHFILE}" ]; then
		echo "*** Error: ${HASHFILE} doesn't exits.";
		exit 1;
	fi;
	HASHFILE=`readlink -f "${HASHFILE}"`;
	if [ "${KEYFILE}" != "" ]; then
		echo "*** Error: KEY and HASH are mutually exclusive.";
		exit 1;
	fi;
fi;

if [ "${KEK0FILE}" != "" ]; then
	if [ "${tid}" != "0x18" -a "${tid}" != "0x19" ]; then
		echo "Error: Key Encryption Key is supported only for TX2";
		exit 1;
	fi;
	if [ ! -f "${KEK0FILE}" ]; then
		echo "*** Error: ${KEK0FILE} doesn't exits.";
		exit 1;
	fi;
	KEK0FILE=`readlink -f "${KEK0FILE}"`;
fi;

if [ "${KEK1FILE}" != "" ]; then
	if [ "${tid}" != "0x18" -a "${tid}" != "0x19" ]; then
		echo "Error: Key Encryption Key is supported only for TX2";
		exit 1;
	fi;
	if [ ! -f "${KEK1FILE}" ]; then
		echo "*** Error: ${KEK1FILE} doesn't exits.";
		exit 1;
	fi;
	KEK1FILE=`readlink -f "${KEK1FILE}"`;
fi;

if [ "${KEK2FILE}" != "" ]; then
	if [ "${tid}" != "0x18" -a "${tid}" != "0x19" ]; then
		echo "Error: Key Encryption Key is supported only for TX2";
		exit 1;
	fi;
	if [ ! -f "${KEK2FILE}" ]; then
		echo "*** Error: ${KEK2FILE} doesn't exits.";
		exit 1;
	fi;
	KEK2FILE=`readlink -f "${KEK2FILE}"`;
fi;

if [ "${KEK256FILE}" != "" ]; then
	if [ "${tid}" != "0x18" -a "${tid}" != "0x19" ]; then
		echo "Error: Key Encryption Key is supported only for TX2";
		exit 1;
	fi;
	if [ ! -f "${KEK256FILE}" ]; then
		echo "*** Error: ${KEK256FILE} doesn't exits.";
		exit 1;
	fi;
	KEK256FILE=`readlink -f "${KEK256FILE}"`;
fi;

if [ "${KEYFILE}" != "" ]; then
	if [ ! -f "${KEYFILE}" ]; then
		echo "*** Error: ${KEYFILE} doesn't exits.";
		exit 1;
	fi;
	KEYFILE=`readlink -f "${KEYFILE}"`;
	pkcopt+="-k ${KEYFILE} ";
	if [ "${HASHFILE}" != "" ]; then
		echo "*** Error: HASH and KEY are mutually exclusive.";
		exit 1;
	fi;
fi;

if [ "${SBKFILE}" != "" ]; then
	if [ ! -f "${SBKFILE}" ]; then
		echo "*** Error: ${SBKFILE} doesn't exits.";
		exit 1;
	fi;
	SBKFILE=`readlink -f "${SBKFILE}"`;
	if [ "${DKFILE}" = "" ]; then
		if [ "${tid}" = "0x40" -o "${tid}" = "0x21" ]; then
			echo "*** Error: DK is missing.";
			exit 1;
		fi;
	fi;
fi;

if [ "${XFILE}" != "" ]; then
	if [ "${Ctype}" != "" -o \
	     "${BootDevCfg}" != "" -o \
	     "${jtag_disable}" != "yes" -o \
	     "${KEYFILE=}" != "" -o \
	     "${odm_lock}" != "" -o \
	     "${odm_reserved}" != "" -o \
	     "${set_productionmode}" != "" -o \
	     "${sw_reserved}" != "" -o \
	     "${DKFILE}" != "" -o \
	     "${SBKFILE}" != "" ]; then
		usage;
	fi;
	if [ ! -f "${XFILE}" ]; then
		echo "*** Error: ${XFILE} doesn't exits.";
		exit 1;
	fi;
	XFILE=`readlink -f "${XFILE}"`;
	pushd bootloader > /dev/null 2>&1;

	cp -f "${XFILE}" . > /dev/null 2>&1;
	fusecfg=`basename "${XFILE}"`;
	echo "*** Start fusing from fuse configuration ... ";
	if [ "${tid}" = "0x40" ]; then
		cp -f ardbeg/fastboot.bin .;
		fcmd="./nvflash --writefuse ${fusecfg} --bl fastboot.bin --go";
	elif [ "${tid}" = "0x21" ]; then
		fcmd="./tegraflash.py --chip ${tid} --applet nvtboot_recovery.bin ";
		fcmd+="--cmd \"blowfuses ${fusecfg};\"";
	elif [ "${tid}" = "0x18" ]; then
		fcmd="./tegraflash.py ${FUSEARGS} ";
		fcmd+="--cmd \"burnfuses ${fusecfg}\"";
	elif [ "${tid}" = "0x19" ]; then
		fcmd="./tegraflash.py ${FUSEARGS} ";
		fcmd+="--cmd \"burnfuses ${fusecfg}\"";
	fi;
	if [ $noburn -eq 1 ]; then
		factory_overlay_gen "${fcmd}" "${fusecfg}" "${bd_cmd}";
		exit $?;
	fi;
	echo "${fcmd}";
	eval ${fcmd};
	if [ $? -ne 0 ]; then
		echo "failed.";
		exit 1;
	fi;
	popd > /dev/null 2>&1;
	exit 0;
fi;

if [ "${Ctype}" = "" ]; then
	echo "*** Error: Crypto type is missing.";
	usage;
fi;
if [ "${Ctype}" != "NS" -a "${Ctype}" != "PKC" ]; then
	echo "*** Error: unknown crypto type. (valid type = \"NS\" or \"PKC\")";
	exit 1;
fi;

if [ "${KEYFILE}" != "" ]; then
	if [ "${KEYVIADB}" != "" ]; then
		echo "*** Error: DB config does not accept keyfile.";
		exit 1;
	fi;
	if [ "${Ctype}" = "NS" ]; then
		echo "*** Error: NS mode does not accept keyfile.";
		exit 1;
	fi;
elif [ "${KEYVIADB}" = "" -a "${Ctype}" = "PKC" ]; then
	if [ "${HASHFILE}" = "" ]; then
		if [ "${USEOPENSSL}" = "" ]; then
			KEYFILE="bootloader/rsa_priv.txt";
		else
			KEYFILE="bootloader/rsa_priv.pem";
		fi;
		KEYFILE=`readlink -f ${KEYFILE}`;
	fi;
fi;

pushd bootloader > /dev/null 2>&1;
if [ "${KEYVIADB}" != "" ]; then
	echo -n "*** Requesting HASH from DB server ... ";
	hcmd="${sudocmd} ssh ${master}";
	hash=`${hcmd} "bash -l -c 'mkpkc ${pkcopt} genkey ${sn}'"`;
	if [[ "${hash}" =~ ^Error:[^@]{1,}$ ]]; then
		hash=`${hcmd} "bash -l -c 'mkpkc ${pkcopt} getcol ${sn} hash'"`;
		if [[ "${hash}" =~ ^Error:[^@]{1,}$ ]]; then
			echo "${hash}";
			echo "Error: failed to get key hash";
			exit 1;
		fi;
		hash="HASH: ${hash}";
	fi;
	echo "done";
elif [ "${Ctype}" = "PKC" ]; then
	use_hash=0;
	if [ -f "${KEYFILE}" ]; then
		echo -n "*** Calculating HASH from keyfile ${KEYFILE} ... ";
	elif [ -f "${HASHFILE}" ]; then
		echo -n "*** Using HASH from ${HASHFILE} ... ";
		use_hash=1;
	else
		echo -n "*** Generating new HASH ... ";
	fi;
	if [ $use_hash -ne 1 ]; then
		hash=`mkpkc ${pkcopt} genkey`;
		if [ $? -ne 0 ]; then
			echo "failed.";
			exit 1;
		fi;
		if [[ "${hash}" =~ ^Error:[^@]{1,}$ ]]; then
			echo "${hash}";
			echo "Error: failed to get key hash";
			exit 1;
		fi;
		if ! [[ ${hash} =~ ^HASH:[\ ] ]]; then
			echo "Error: bad key hash format";
			exit 1;
		fi;
		hash="${hash:6}";
		behash=${hash};
		echo "done";
		convhash "behash" 32;
		echo "PKC HASH: ${behash}";
	else
		hash=`cat "${HASHFILE}"`;
		chkhash "hash" 32;
		echo "done";
	fi;
fi;

if [ "${KEK0FILE}" != "" ]; then
	kek0=`cat ${KEK0FILE}`;
	chkhash "kek0" 16;
fi;

if [ "${KEK1FILE}" != "" ]; then
	kek1=`cat ${KEK1FILE}`;
	chkhash "kek1" 16;
fi;

if [ "${KEK2FILE}" != "" ]; then
	kek2=`cat ${KEK2FILE}`;
	chkhash "kek2" 16;
fi;

if [ "${KEK256FILE}" != "" ]; then
	kek256=`cat ${KEK256FILE}`;
	chkhash "kek256" 64;
fi;

if [ "${DKFILE}" != "" ]; then
	DK=`cat "${DKFILE}"`;
	chkhash "DK" 4;
fi;

if [ "${SBKFILE}" != "" ]; then
	SBK="$(cat "${SBKFILE}" | sed -e s/^[[:space:]]*// -e s/[[:space:]]0x//g -e s/[[:space:]]*//g)";
	chkhash "SBK" 16;
fi;

echo -n "*** Generating fuse configuration ... ";
if [ "${Ctype}" = "NS" ]; then
	if [ "${tid}" = "0x21" -o "${tid}" = "0x18" -o "${tid}" = "0x19" ]; then
		fusecfg="odmfuse_pkc.xml";
		fusename="PkcDisable";
		fusesize=4;
	else
		fusecfg="odmfuse_ns.cfg";
		fusename="pkc_disable";
	fi;
	fuseval="0x1";
elif [ "${Ctype}" = "PKC" ]; then
	if [ "${tid}" = "0x40" ]; then
		fusecfg="odmfuse_pkc.cfg";
		fusename="public_key_hash";
	elif [ "${tid}" = "0x21" -o "${tid}" = "0x18" -o \
		"${tid}" = "0x19" ]; then
		fusecfg="odmfuse_pkc.xml";
		fusename="PublicKeyHash";
	fi;
	fusesize=32;
	fuseval="${hash}";
	echo "done.";
fi;

rm -f ${fusecfg};
if [ "${tid}" = "0x40" ]; then
	if [ "${BootDevCfg}" != "" ]; then
		echo -n "<fuse:sec_boot_dev_cfg;" >> ${fusecfg};
		echo "value:${BootDevCfg}>" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${jtag_disable}" = "yes" ]; then
		echo "<fuse:jtag_disable;value:0x1>" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${odm_lock}" != "" ]; then
		echo "<fuse:odm_lock;value:${odm_lock}>" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${odm_reserved}" != "" ]; then
		echo "<fuse:odm_reserved;value:${odm_reserved}>" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${sw_reserved}" != "" ]; then
		echo "<fuse:sw_reserved;value:${sw_reserved}>" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${DK}" != "" ]; then
		echo "<fuse:device_key;value:${DK}>"  >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${SBK}" != "" ]; then
		echo "<fuse:secure_boot_key;value:${SBK}>"  >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${fusename}" != "" -a "${fuseval}" != "" ]; then
		echo "<fuse:${fusename};value:${fuseval}>"   >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${set_productionmode}" != "" ]; then
		echo "<fuse:odm_production_mode;value:0x1>"  >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
elif [ "${tid}" = "0x21" -o "${tid}" = "0x18" -o "${tid}" = "0x19" ]; then
	magicid="0x46555345";
	if [ "${tid}" = "0x18" -o "${tid}" = "0x19" ]; then
		magicid="0x45535546";	# BigEndian format
	fi;
	echo -n "<genericfuse " >> ${fusecfg};
	echo    "MagicId=\"${magicid}\" version=\"1.0.0\">" >> ${fusecfg};
	if [ "${BootDevCfg}" != "" ]; then
		echo -n "<fuse name=\"SecBootDeviceSelect\" " >> ${fusecfg};
		echo    "size=\"4\" value=\"${BootDevCfg}\" />" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${jtag_disable}" = "yes" ]; then
		echo -n "<fuse name=\"JtagDisable\" " >> ${fusecfg};
		echo    "size=\"4\" value=\"0x1\" />" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${odm_lock}" != "" ]; then
		echo -n "<fuse name=\"OdmLock\" " >> ${fusecfg};
		echo    "size=\"4\" value=\"${odm_lock}\" />" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${odm_reserved}" != "" ]; then
		echo -n "<fuse name=\"ReservedOdm\" " >> ${fusecfg};
		echo "size=\"32\" value=\"${odm_reserved}\" />" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${odm_reserved0}" != "" ]; then
		echo -n "<fuse name=\"ReservedOdm0\" " >> ${fusecfg};
		echo "size=\"4\" value=\"${odm_reserved0}\" />" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${odm_reserved1}" != "" ]; then
		echo -n "<fuse name=\"ReservedOdm1\" " >> ${fusecfg};
		echo "size=\"4\" value=\"${odm_reserved1}\" />" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${odm_reserved2}" != "" ]; then
		echo -n "<fuse name=\"ReservedOdm2\" " >> ${fusecfg};
		echo "size=\"4\" value=\"${odm_reserved2}\" />" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${odm_reserved3}" != "" ]; then
		echo -n "<fuse name=\"ReservedOdm3\" " >> ${fusecfg};
		echo "size=\"4\" value=\"${odm_reserved3}\" />" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${odm_reserved4}" != "" ]; then
		echo -n "<fuse name=\"ReservedOdm4\" " >> ${fusecfg};
		echo "size=\"4\" value=\"${odm_reserved4}\" />" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${odm_reserved5}" != "" ]; then
		echo -n "<fuse name=\"ReservedOdm5\" " >> ${fusecfg};
		echo "size=\"4\" value=\"${odm_reserved5}\" />" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${odm_reserved6}" != "" ]; then
		echo -n "<fuse name=\"ReservedOdm6\" " >> ${fusecfg};
		echo "size=\"4\" value=\"${odm_reserved6}\" />" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${odm_reserved7}" != "" ]; then
		echo -n "<fuse name=\"ReservedOdm7\" " >> ${fusecfg};
		echo "size=\"4\" value=\"${odm_reserved7}\" />" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${odm_reserved8}" != "" ]; then
		echo -n "<fuse name=\"ReservedOdm8\" " >> ${fusecfg};
		echo "size=\"4\" value=\"${odm_reserved8}\" />" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${odm_reserved9}" != "" ]; then
		echo -n "<fuse name=\"ReservedOdm9\" " >> ${fusecfg};
		echo "size=\"4\" value=\"${odm_reserved9}\" />" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${odm_reserved10}" != "" ]; then
		echo -n "<fuse name=\"ReservedOdm10\" " >> ${fusecfg};
		echo "size=\"4\" value=\"${odm_reserved10}\" />" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${odm_reserved11}" != "" ]; then
		echo -n "<fuse name=\"ReservedOdm11\" " >> ${fusecfg};
		echo "size=\"4\" value=\"${odm_reserved11}\" />" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${sw_reserved}" != "" ]; then
		echo -n "<fuse name=\"SwReserved\" " >> ${fusecfg};
		echo "size=\"4\" value=\"${sw_reserved}\" />" >> ${fusecfg};
	fi;
	if [ "${DK}" != "" ]; then
		echo -n "<fuse name=\"DeviceKey\" " >> ${fusecfg};
		echo    "size=\"8\" value=\"${DK}\" />"  >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${SBK}" != "" ]; then
		echo -n "<fuse name=\"SecureBootKey\" " >> ${fusecfg};
		echo    "size=\"16\" value=\"${SBK}\" />"  >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${kek0}" != "" ]; then
		echo -n "<fuse name=\"Kek0\" " >> ${fusecfg};
		echo    "size=\"16\" value=\"${kek0}\" />"  >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${kek1}" != "" ]; then
		echo -n "<fuse name=\"Kek1\" " >> ${fusecfg};
		echo    "size=\"16\" value=\"${kek1}\" />"  >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${kek2}" != "" ]; then
		echo -n "<fuse name=\"Kek2\" " >> ${fusecfg};
		echo    "size=\"16\" value=\"${kek2}\" />"  >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${kek256}" != "" ]; then
		echo -n "<fuse name=\"Kek256\" " >> ${fusecfg};
		echo    "size=\"32\" value=\"${kek256}\" />"  >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
	fi;
	if [ "${fusename}" != "" -a "${fuseval}" != "" ]; then
		echo -n "<fuse name=\"${fusename}\" " >> ${fusecfg};
		echo -n "size=\"${fusesize}\" " >> ${fusecfg};
		echo    "value=\"${fuseval}\" />" >> ${fusecfg};
		fusecnt=$((fusecnt + 1));
		if [ "${tid}" = "0x18" ]; then
			echo -n "<fuse name=" >> ${fusecfg};
			echo -n "\"BootSecurityInfo\" " >> ${fusecfg};
			if [ "${SBK}" != "" ]; then
				bsi="0x6";
			else
				bsi="0x2";
			fi;
			echo    "size=\"4\" value=\"${bsi}\" />"  >> ${fusecfg};
			fusecnt=$((fusecnt + 1));
		elif [ "${tid}" = "0x19" ]; then
			echo -n "<fuse name=" >> ${fusecfg};
			echo -n "\"BootSecurityInfo\" " >> ${fusecfg};
			if [ "${SBK}" != "" ]; then
				bsi="0x5";
			else
				bsi="0x1";
			fi;
			# 0x1=2K PKC 0x2=3K PKC
			echo    "size=\"4\" value=\"${bsi}\" />"  >> ${fusecfg};
			fusecnt=$((fusecnt + 1));
		fi;
	fi;
	if [ "${set_productionmode}" != "" ]; then
		if [ "${tid}" = "0x21" -o "${tid}" = "0x18" -o \
			"${tid}" = "0x19" ]; then
			echo -n "<fuse name=\"SecurityMode\" " >> ${fusecfg};
			echo    "size=\"4\" value=\"0x1\" />"  >> ${fusecfg};
		else
			echo -n "<fuse name=\"ProductionMode\" " >> ${fusecfg};
			echo    "size=\"4\" value=\"0x1\" />"  >> ${fusecfg};
		fi;
		fusecnt=$((fusecnt + 1));
	fi;
	echo "</genericfuse>" >> ${fusecfg};
fi;
echo "done.";

if [ $fusecnt -eq 0 ]; then
	echo "*** No fuse bit specified. Terminating.";
	exit 0;
fi;

cp "${fusecfg}" "${fusecfg}.sav";

if [ "${tid}" = "0x40" ]; then
	cp -f ardbeg/fastboot.bin .;
	fcmd="./nvflash --writefuse ${fusecfg} --bl fastboot.bin --go";
elif [ "${tid}" = "0x21" ]; then
	if [ ${testmode} -eq 1 ]; then
		echo "Test mode: removing all lines with '<fuse name=' so no fuses will be burned.";
		sed -i '/<fuse name=/d' "${fusecfg}";
	fi;
	fcmd="./tegraflash.py --chip ${tid} --applet nvtboot_recovery.bin ";
	fcmd+="--cmd \"blowfuses ${fusecfg};\"";
elif [ "${tid}" = "0x18" -o "${tid}" = "0x19" ]; then
	fcmd="./tegraflash.py ${FUSEARGS} ";
	if [ ${testmode} -eq 1 ]; then
		echo "Test mode: using dummy so no fuses will be burned.";
		fcmd+="--cmd \"burnfuses dummy\"";
	else
		fcmd+="--cmd \"burnfuses ${fusecfg}\"";
	fi;
fi;

if [ $noburn -eq 1 ]; then
	factory_overlay_gen "${fcmd}" "${fusecfg}" "${bd_cmd}";
	exit $?;
fi;

fcmd+=" ${SKIPUID} "

echo "*** Start fusing ${sn} ... ";
echo "${fcmd}";
eval ${fcmd};
if [ $? -ne 0 ]; then
	echo "failed.";
	exit 1;
fi;
echo "*** The fuse configuration is saved in bootloader/${fusecfg}";
if [ "${Ctype}" = "NS" ]; then
	echo "*** The ODM fuse has been locked successfully.";
	echo "*** Flash \"clear BCT and bootloader\".";
else
	echo "*** The ODM fuse has been secured with PKC keys.";
	echo "*** Flash \"signed BCT and bootloader(s)\".";
fi;
popd > /dev/null 2>&1;
echo "*** done.";
exit 0;
