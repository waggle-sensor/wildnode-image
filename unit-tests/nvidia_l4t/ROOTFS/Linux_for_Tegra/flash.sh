#!/bin/bash -e

# Fake NVidia L4T flash script

# code block to be modified
			if [[ "${ext_target_board_canonical}" == "p3509-0000+p3668"* ||
				"${ext_target_board_canonical}" == "p3448-0000-sd"* ||
				"${ext_target_board_canonical}" == "p3448-0000-max-spi"* ]]; then
				# issue an erase command before write
				FLASHARGS+="erase ${target_partname}; ";
			fi
