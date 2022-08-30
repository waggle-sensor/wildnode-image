#!/bin/bash

# Copyright (c) 2017, NVIDIA CORPORATION.  All rights reserved.
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
# wb_sign.sh: Sign wb0 code that is embedded in u-boot binary file.
#
#  ./wb_sign.sh <u-boot-dtb-tegra.bin> <pkc_key> <u-boot-elf> <u-boot-spl-elf>
#

IMAGE_FILE=$1;
KEY_FILE=$2;
U_BOOT_ELF=$3;
U_BOOT_SPL_ELF=$4;

#
# WB0 header:
#
#   offset                     length (bytes)
#          -----------------
#   0x0000 |  len_insecure |      4
#          +---------------+
#   0x0004 |  reserved     |     12
#          +---------------+
#   0x0010 |  modulus      |    256
#          +---------------+
#   0x0110 |  cmac_hash    |     16
#          +---------------+
#   0x0120 |  rsa_pss_sig  |    256
#          +---------------+ <---------- The beginning of secured section
#   0x0220 |  random_aes   |     16
#          +---------------+
#   0x0230 |  len_secure   |      4
#          +---------------+
#   0x0234 |  destination  |      4
#          +---------------+
#   0x0238 |  entry_point  |      4
#          +---------------+
#   0x023c |  code_length  |      4
#          +---------------+
#
len_insecure_offset="0x0000"
mod_offset="0x10"
sig_offset="0x120"
secure_section_offset="0x0220"
len_secure_offset="0x0230"
code_lenght_offset="0x023c"
wb_header_len="0x240"

#
# function: usage
#
function usage()
{
	echo -e "
Usage: ./wb_sign.sh <u-boot.bin> <key> <u-boot.elf> <u-boot-spl.elf>
  Where,
      u-boot.bin: The bootloader that has wb code built in. Its original
                  name is u-boot-dtb-tegra.bin after build but is renamed
                  to u-boot.bin after placed into release package.
             key: The rsa private key file. Ex: rsa_priv.pem
      u-boot.elf: The u-boot ELF file. Its name is u-boot after build.
   u-boot-sp.elf: The u-boot-spl ELF file. Its name is u-boot-spl after build
                  under spl directory.

  Command Example:

     ./wb_sign.sh u-boot-dtb-tegra.bin rsa_priv.pem u-boot u-boot-spl
	 ";
}

#
# function: debug_print
#
function debug_print()
{
	local message="$1";

	if [ ${debug} -ne 0 ]; then
		echo "${message}"
	fi;
}

#
# function: get_symbol_value
#
function get_value()
{
	local symbol="$1";
	local symbol_file="$2";
	local ret_var="$3";

	local str
	str=`objdump -t "${symbol_file}" | grep "${symbol}"`
	local tokens=($str)
	eval "${ret_var}=`echo 0x${tokens[0]}`"
}

#
# function: get offset
#
function get_offset()
{
	local symbol="$1";
	local ret_var="$2";

	# get symbol loc
	local symbol_loc
	get_value "${symbol}" "${U_BOOT_ELF}" symbol_loc
	debug_print "${symbol}: ${symbol_loc}"

	# get U-Boot base
	local text_base_sym="d  .text"
	local uboot_text_base;
	get_value "${text_base_sym}" "${U_BOOT_ELF}" uboot_text_base
	debug_print "uboot_base: ${uboot_text_base}"

	# get U-Boot-spl base
	local uboot_spl_text_base;
	get_value "${text_base_sym}" "${U_BOOT_SPL_ELF}" uboot_spl_text_base
	debug_print "uboot_spl_base: ${uboot_spl_text_base}"

	# get symbol offset from the packed image (u-boot-spl + u-boot + dtb)
	#  symbol_loc = ${uboot_text_base} - ${uboot_spl_text_base} + ${symbol_loc}
	#				-${uboot_text_base};
	#			  = ${symbol_loc} - ${uboot_spl_text_base}
	symbol_loc=$((${symbol_loc}-${uboot_spl_text_base}));
	debug_print "${symbol}_offset: ${symbol_loc}";

	eval "${ret_var}=${symbol_loc}";
}

function inject_value()
{
	local value="$1";
	local offset="$2";
	local output="$3";

	local num=num.tmp
	rm -f "${num}" > /dev/null 2>&1;
	printf "0: %.8x" "${value}" | sed -E 's/0: (..)(..)(..)(..)/0: \4\3\2\1/' \
		| xxd -r -g0 >> "${num}"
	dd conv=notrunc bs=1 seek="$((${offset}))" count=4 if="${num}" \
		of="${output}" > /dev/null 2>&1;
}

function sign_wb0()
{
	local wb="$1";
	local secure_sec_offset="$2";
	local sig_offset="$3";
	local mod_offset="$4";
	local key="$5";

	debug_print " Extract the part of the binary that needs to be signed"
	dd bs=1 skip="$((${secure_sec_offset}))" if="${wb}" of="${wb}".tosig \
		> /dev/null 2>&1;

	debug_print " Calculate rsa-pss signature and save to ${wb}.rsa.sig"
	openssl dgst -sha256 -sigopt rsa_padding_mode:pss -sigopt \
		rsa_pss_saltlen:-1 -sign "${key}" -out "${wb}".rsa.sig "${wb}".tosig

	debug_print " Reverse rsa signature byte order"
	objcopy -I binary --reverse-bytes=256 "${wb}".rsa.sig "${wb}".rsa.sig.rev

	debug_print " Inject rsa-pss signature ${wb}.rsa.sig.rev into wb_header"
	dd conv=notrunc bs=1 seek="$((${sig_offset}))" count=256 \
		if="${wb}".rsa.sig.rev of="${wb}" > /dev/null 2>&1;

	debug_print " Generate public key modulus and save to ${key}.mod"
	openssl rsa -in "${key}" -noout -modulus -out "${key}".mod
	# remove prefix
	cut -d= -f2 < "${key}".mod > "${key}".mod.tmp
	# convert from hexdecimal to binary
	xxd -r -p -l 256 "${key}".mod.tmp "${key}".mod.tmp2
	# reverse byte order"
	objcopy -I binary --reverse-bytes=256 "${key}".mod.tmp2 "${key}".mod.rev

	debug_print " Inject public key modulus ${key}.mod.rev into wb_header"
	dd conv=notrunc bs=1 seek="$((${mod_offset}))" count=256 \
		if="${key}".mod.rev of="${wb}" > /dev/null 2>&1;

	debug_print " Image signed to file ${wb}"
}

#
# Main
#

#
# Debug print on/off flag
#  1: on
#  0: off
debug=0

#
# Check input files
#
if [ $# -lt 4 ]; then
	usage;
	exit 1;
fi;

IMAGE_FILE=`readlink -f "${IMAGE_FILE}"`;
KEY_FILE=`readlink -f "${KEY_FILE}"`;
U_BOOT_ELF=`readlink -f "${U_BOOT_ELF}"`;
U_BOOT_SPL_ELF=`readlink -f "${U_BOOT_SPL_ELF}"`;

debug_print "IMAGE_FILE: ${IMAGE_FILE}";
debug_print "KEY_FILE: ${KEY_FILE}";
debug_print "U_BOOT_ELF: ${U_BOOT_ELF}";
debug_print "U_BOOT_SPL_ELF: ${U_BOOT_SPL_ELF}";

my_working_dir=_tmp
mkdir -p ${my_working_dir}
pushd "${my_working_dir}" > /dev/null 2>&1;
cp "${KEY_FILE}" ./key.tmp
KEY_FILE=./key.tmp

#
# Step 1: Extract WB_header from U-Boot image
#
debug_print "1. Extract WB_header from U-Boot"
wb_header=wb_header.tmp
wb_header_off="";
wb_header_len=$((${wb_header_len}))
get_offset "wb_header" wb_header_off
dd bs=1 skip="${wb_header_off}" count="${wb_header_len}" if="${IMAGE_FILE}" \
	of="${wb_header}" > /dev/null 2>&1;
debug_print "wb_header: ${wb_header}";

#
# Step 2: Extract WB_code from U-Boot image
#
debug_print "2. Extract WB_code from U-Boot"
wb_code=wb_code.tmp
wb_start_off="";
wb_end_off="";
wb_len="";
get_offset "wb_start" wb_start_off
get_offset "wb_end" wb_end_off
wb_len=$((${wb_end_off} - ${wb_start_off}))
dd bs=1 skip="${wb_start_off}" count="${wb_len}" if="${IMAGE_FILE}" \
	of="${wb_code}" > /dev/null 2>&1;
debug_print "wb_len: ${wb_len}";
debug_print "wb_code: ${wb_code}";

#
# Step 3: Construct complete WB0, ie, wb_header + wb_code
#
debug_print "3. Construct complete WB0"
#
# Fill in wb_header
#

#
# 0x0000: len_insecure = wb_header_length + wb_code_length
#
offset=${len_insecure_offset}
len=$((${wb_header_len} + ${wb_len}))
debug_print "len_insecure = ${len}";
inject_value "${len}" "${offset}" "${wb_header}"

#
# 0x0230: len_secure: wb_header_lenght + wb_code_length
# !!! why not wb_header_secure_sec + wb_code_length
#
offset=${len_secure_offset}
len=$((${wb_header_len} + ${wb_len}))
debug_print "len_secure = ${len}";
inject_value "${len}" "${offset}" "${wb_header}"

#
# 0x023c: code_length: wb_code_length
#
offset=${code_lenght_offset}
len=$((${wb_len}))
debug_print "code_length = ${len}";
inject_value "${len}" "${offset}" "${wb_header}"

#
# Append wb_code to wb_header and save to wb.tmp
#
wb=wb.tmp
cp -f "${wb_header}" "${wb}" > /dev/null 2>&1;
dd bs=1 oflag=append conv=notrunc if="${wb_code}" of="${wb}" > /dev/null 2>&1;

#
# Step 4: Sign WB0
#
debug_print "4. Call WB0 signing function"
# error check to make sure to_sign length is 16 bytes aligned.
to_sign_len=$((${wb_header_len} - $((${secure_section_offset})) + ${wb_len}))
if ((to_sign_len % 16)); then
	echo -n "Error: To sign length is not 16 bytes aligned where wb_header_sign"
	echo -n " = $((${wb_header_len} - $((${secure_section_offset})))), wb_len ="
	echo " ${wb_len}";
	exit 1;
fi;
debug_print "to sign length: ${to_sign_len}"
sign_wb0 "${wb}" "${secure_section_offset}" "${sig_offset}" "${mod_offset}" \
	"${KEY_FILE}"

#
# Step 5: Inject WB_header back to U-Boot image
#
debug_print "5. Inject WB_header back to U-Boot image"
dd bs=1 conv=notrunc seek="${wb_header_off}" skip=0 count="${wb_header_len}" \
	if="${wb}" of="${IMAGE_FILE}" > /dev/null 2>&1;

echo "WarmBoot code reside in ${IMAGE_FILE} has been signed"

# clean up all tmp files
if [ ${debug} -eq 0 ]; then
	rm -f *.sig *.tosig *.mod *.rev *.tmp *.tmp2
fi;
popd > /dev/null 2>&1;
if [ ${debug} -eq 0 ]; then
	rmdir "${my_working_dir}" > /dev/null 2>&1;
fi;
