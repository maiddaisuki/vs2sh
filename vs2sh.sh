#!/bin/env sh

#    vs2sh.sh - create startup files for sh-compatible shells to allow use of
#    Visual Studio command line tools
#
#    Copyright (C) 2024 Kirill Makurin
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.

################################################################################

#	Global variables

export LC_ALL=C

tab='	'
nl='
'

IFS=" ${tab}${nl}"

if test "X${BASH_VERSION+set}" = Xset; then
	set -o posix
fi

################################################################################

# Execute a command and reverse its exit status
# Intended to be used in conditional tests instead of !
#
# $1: command to execute
# $*: arguments
#
# Exit status:
#	0: command exited with status other than 0
#	1: command exited with status 0
#
not() {
	"$@"

	if test $? -eq 0; then
		return 1
	else
		return 0
	fi
}

# Output functions

# Writes formatted string to standard output
#
# $1: format string
# $*: arguments
#
print() {
	printf "$@"
}

# Writes warning message to standard error
#
# $1: message to write
#
warning() {
	print '%s: WARNING: %s\n' "$(basename "$0")" "$1" >>/dev/stderr
}

# Writes error message to standard error
#
# $1: message to write
#
error() {
	print '%s: ERROR: %s\n' "$(basename "$0")" "$1" >>/dev/stderr
}

# Print an error message and abort execution of the script
#
# $1: message to write
#
die() {
	error "$1"
	kill -abrt $$
}

# Operations on variables

# Apppends text to the end of a varaible
#
# $1: name of variable
# $2: text to append
#
append() {
	:
}

# Append new entry to the end of a newline-separated list
#
# #1: name of variable holding the newline-separated list
# $2: text to append
#
append_list() {
	:
}

# checking if shell understands var+=text

if (
	v1=y
	v2=z
	v1+=${v2}
	test x${v1} = xyz
) >/dev/null 2>&1; then
	append() {
		eval "$1+=\$2"
	}

	append_list() {
		eval "$1+=\$2\${nl}"
	}
else
	append() {
		eval "$1=\${$1}\$2"
	}

	append_list() {
		eval "$1=\${$1}\$2\${nl}"
	}
fi

# Operations on strings

# Compare two strings to be equal
#
# $1 and $2: string to compare
#
# Exit status:
#	0: strings are equal
#	1: strings are not equal
#
strcmp() {
	test "X$1" = "X$2"
}

# Compare string to value yes
#
# $1: string to compare
#
# Exit status:
#	0: string equals yes
#	1: string does not equal yes
#
str_is_yes() {
	strcmp "$1" yes
}

# Compare string to value no
#
# $1: string to compare
#
# Exit status:
#	0: string equals no
#	1: string does not equal no
#
str_is_no() {
	strcmp "$1" no
}

# Common tools

# Run sed on the contents of a variable
#
# $1: options to sed
#	use empty string if none
# $2: sed script
# $3: name of variable on which contents to run set
#
# Exit status is that of sed
#
run_sed() {
	eval "printf '%s\n' \"\${$3}\"" | sed $1 "$2"
}

# Run grep on the contents of a variable
#
# $1: options to grep
#	use empty string if none
# $2: regex
# $3: name of variable on which contents to run grep
#
# Exit status is that of grep
#
run_grep() {
	eval "printf '%s\n' \"\${$3}\"" | grep $1 "$2"
}

# escaping

# Escape string so that it can be used in extended regular expression to match
# itself
#
# $1: string to escape
#
sed_escape() {
	local _path=$1
	local __sed='s|[\/.{}()$+?*]|\\&|g'

	run_sed '' "${__sed}" _path
}

# Escape a windows-style filename so that it may be used within double quotes
#
# $1: string to escape
#
shell_escape_path() {
	local _path=$1
	local __sed='s|[\]|\\&|g'

	run_sed '' "${__sed}" _path
}

# Functions to replace missing tools

# Converts an absolute windows path into unix path
#
# $1: path to convert
#
path_win_to_unix() {
	:
}

# Converts an absolute unix path into windows path
#
# $1: path to convert
#
path_unix_to_win() {
	:
}

# use cygpath if we have it, emulate using sed otherwise

if type cygpath >/dev/null 2>&1; then
	has_cygpath=yes

	path_win_to_unix() {
		cygpath -u "$1"
	}

	path_unix_to_win() {
		cygpath -w "$1"
	}
else
	has_cygpath=no

	path_win_to_unix() {
		local _path=$1
		local _drive _drive_fixed

		local __sed

		__sed='s|^(.).*|\1|'
		_drive=$(run_sed -E "${__sed}" _path)

		_drive_fixed=$(printf '%s\n' "${_drive}" | tr '[[:upper:]]' '[[:lower:]]')

		__sed="s|^${_drive}|${_drive_fixed}|"
		_path=$(run_sed '' "${__sed}" _path)

		__sed='s|^([:alpha:]):[\/]*(.*)|/\1/\2| ; s|[\]|/|g'
		run_sed -E "${__sed}" _path
	}

	path_unix_to_win() {
		local _path=$1
		local _drive _drive_fixed

		local __sed

		__sed='s|^\/(.).*|\1|'
		_drive=$(run_sed -E "${__sed}" _path)

		_drive_fixed=$(printf '%s\n' "${_drive}" | tr '[[:lower:]]' '[[:upper:]]')

		__sed="s|^\\/${_drive}|\\/${_drive_fixed}|"
		_path=$(run_sed '' "${__sed}" _path)

		__sed='s|^/([[:alpha:]])[/]*(.*)|\1:\\\2| ; s|[/]|\\|g'
		run_sed -E "${__sed}" _path
	}
fi

#
# The environment files are expected to be written from cmd or powershell
# so they may have CRLF end-of-line sequences
# If the script is run on another OS that does not handle CRLF on input,
# it will casue troubles with sed and grep
#

# Converts file with CRLF end-of-line sequences into LF
#
# $1: file to convert
#
convert_crlf_to_lf() {
	:
}

# use dos2unix if we have it, emulate otherwise

if type dos2unix >/dev/null 2>&1; then
	convert_crlf_to_lf() {
		dos2unix "$1" >/dev/null 2>&1
	}
else
	_test_str='line1\r\nline2\r\n'
	_test_str_result="line1${nl}line2"

	if (strcmp "$(printf "${_test_str}" | sed 's|\r$||')" "${_test_str_result}") >/dev/null 2>&1; then
		convert_crlf_to_lf() {
			sed -i 's|\r$||' "$1" >/dev/null 2>&1
		}
	elif (strcmp "$(printf "${_test_str}" | tr -d '\r')" "${_test_str_result}") >/dev/null 2>&1; then
		convert_crlf_to_lf() {
			local _tmp_file=$(mktemp -p "${dir_tmp}")

			cat "$1" | tr -d '\r' >"${_tmp_file}"
			mv "${_tmp_file}" "$1"
		}
	elif (strcmp "$(printf "${_test_str}" | tr -d '\015')" "${_test_str_result}") >/dev/null 2>&1; then
		convert_crlf_to_lf() {
			local _tmp_file=$(mktemp -p "${dir_tmp}")

			cat "$1" | tr -d '\015' >"${_tmp_file}"
			mv "${_tmp_file}" "$1"
		}
	else
		die "cannot covert CRLF files into LF"
	fi

	unset _test_str _test_str_result
fi

#
# When writing PATH-like varialbes to the profile file, the value that appears
# the last in the list must appear first since we will prepend it to the
# variable rather than append
#

# Original MinGW lacks tac

if not type tac >/dev/null 2>&1; then
	tac() {
		local _text=$(cat)

		while strcmp "${_text:+y}" y; do
			run_sed '' "1q" _text
			_text=$(run_sed '' '1d' _text)
		done
	}
fi

# Original MinGW lacks realpath

if not type realpath >/dev/null 2>&1; then
	realpath() {
		printf '%s\n' "$1"
	}
fi

################################################################################

# Script initialization

# Holds filename of the temporary directory used by the script
#
dir_tmp=

# Checks for required programs and aborts execution if any is missing
#
_init_check() {
	local _prog

	for _prog in mktemp iconv; do
		type ${_prog} >/dev/null 2>&1 || die "cannot locate ${_prog}"
	done
}

# Create temporary directory and set dir_tmp variable
# Abort execution if failed to create temporary directory
#
_init_tmp_dir() {
	local _tmp

	for _tmp in "${TMPDIR}" "${TMP}" "${TEMP}" /tmp; do
		test -n "${_tmp}" && break
	done

	dir_tmp=$(mktemp -d -p "${_tmp}" vs2sh-XXXXXXXX)
	test $? -eq 0 || die "failed to create directory for temporary files"
}

# Initialize the script
#
init() {
	_init_check
	_init_tmp_dir
}

################################################################################

# Script finalization

# Remove temporary directory used by the script
#
_fini_cleanup() {
	test -d "${dir_tmp}" && rm -rf "${dir_tmp}"
}

# Exit from the script
#
# (optional) $1: exit status
#
# If no arguments given, exit with 127
#
fini() {
	_fini_cleanup
	exit ${1-127}
}

################################################################################

# Arguments parsing

# Holds name of development environemnt file
#
opt_file_env_devel=

# Holds name of default environemnt file
#
opt_file_env_user=

# Holds name of output profile file
#
opt_file_output=vs.sh

# Set to value passed with --sdk option
#
opt_sdk=

# Set to value passed with --vctools option
#
opt_vctools=

# Set to value passed with --vcredist option
#
opt_vcredist=

# Set to yes if --fast option has been passed
#
opt_fast=no

# Set to yes if --cygpath has been passed, or
# Set to no if --no-cygpath has been passed, or
# Set to value of has_cygpath otherwise
#
# specifies whether cygpath should be used in the output profile
#
opt_cygpath=

# Set to yes if --dump option has been passed
#
opt_dump=no

# Set ot yes if --dump-only options has been passed
#
opt_dump_only=no

# Holds name of the directory where to write auxiliary output files
#
opt_dump_dir=

msg_help="USAGE: $(basename "$0") -d FILENAME -u FILENAME [OPTIONS]

OPTIONS:

	-h | -help
		print this help massage and exit successfully

	-u FILENAME | --user-env=FILENAME
		specify filename of file containing variables from default environment

	-d FILENAME | --dev-env=FILENAME
		specify filename of file containing variables from development environment

	-o FILENAME | --output=FILENAME
		specify filename of generated profile file
			Default filename is vs.sh

	--sdk=VERSION
		generate profile to use specified VERSION of Winodws SDK

	--vctools=VERSION
		generate profile to use specified VERSION of Visual C tools

	--vcredist=VERSION
		generate profile to use specified VERSION of Visual C redistributables

	--[no-]cygpath
		whether to use cygpath in generated files
			Default is to use it if it was found on the system

	--fast
		do not perform variable substitution

Auxiliary output

	--dump
		produce auxiliary output in addition to normal output

	--dump-only
		produce auxiliary output only. Do not produce normal output

	-dump-dir=DIRNAME
		specify directory where to write auxiliary files
			Default is to write in the current directory
"

# Gets option's argument and assigns it to a variable
# If option's argument is missing or has an empty value, aborts execution
#
# $1: variable to assign option's argument
# $2: argument as passed to the script
# $*: remaining arguments to process
#
# Exit status:
#	0: value has been passed in the same argument, no shifting is required
#	1: value has been passed as a separate argument, shift is required
#
_arg_get_value() {
	local __var=$1
	shift
	local __opt=${1%%=*}
	local __arg=${1#*=}
	shift

	if strcmp "${__opt}" "${__arg}"; then
		if [ $# -gt 0 ]; then
			eval "${__var}=\$1"
			return 1
		else
			die "missing argument to ${__opt}"
		fi
	else
		if test -n "${__arg}"; then
			eval "${__var}=\${__arg}"
			return 0
		else
			die "empty value supplied with ${__opt} option"
		fi
	fi
}

# Check if file exists and assign its absolute filename to a variable
# If file does not exist or unreadable, aborts execution
#
# $1: varaible to assign
# $2: filename
#
_arg_process_file() {
	if test -r "$2"; then
		eval "$1=\$(realpath \"$2\")"
	elif test -f "$2"; then
		die "file '$2' cannot be read"
	else
		die "file '$2' does not exist"
	fi
}

# Check if directory exists and assign its absolute filename to a variable
# If directory does not exist, aborts execution
#
# $1: varaible to assign
# $2: dirname
#
_arg_process_dir() {
	if test -d "$2"; then
		eval "$1=\$(realpath \"$2\")"
	else
		die "directory '$2' does not exist"
	fi
}

# Parses arguments passed to the script
#
# $*: arguments passed to the script
#
args_parse() {
	local _arg _val

	while test $# -gt 0; do
		_arg=$1
		shift

		case ${_arg} in
		-h | --help)
			print '%s\n' "${msg_help}"
			fini 0
			;;
		-o | --output | --output=*)
			_arg_get_value opt_file_output "${_arg}" "$@" || shift
			;;
		-d | --dev-env | --dev-env=*)
			_arg_get_value _val "${_arg}" "$@" || shift
			_arg_process_file opt_file_env_devel "${_val}"
			;;
		-u | --user-env | --user-env=*)
			_arg_get_value _val "${_arg}" "$@" || shift
			_arg_process_file opt_file_env_user "${_val}"
			;;
		-l | --locale | --locale=*)
			_arg_get_value LC_ALL "${_arg}" "$@" || shift
			;;
		--sdk | --sdk=*)
			_arg_get_value opt_sdk "${_arg}" "$@" || shift
			;;
		--vctools | --vctools=*)
			_arg_get_value opt_vctools "${_arg}" "$@" || shift
			;;
		--vcredist | --vcredist=*)
			_arg_get_value opt_vcredist "${_arg}" "$@" || shift
			;;
		-f | --fast)
			opt_fast=yes
			;;
		--cygpath)
			opt_cygpath=yes
			;;
		--no-cygpath)
			opt_cygpath=no
			;;
		--dump)
			opt_dump=yes
			;;
		--dump-only)
			opt_dump=yes
			opt_dump_only=yes
			;;
		--dump-dir | --dump-dir=*)
			_arg_get_value _val "${_arg}" "$@" || shift
			_arg_process_dir opt_dump_dir "${_val}"
			;;
		*)
			die "unrecognized option ${_arg}"
			;;
		esac

		_val=
	done

	if test -z "${opt_file_env_user}"; then
		die "default environment file is not specified"
	fi

	if test -z "${opt_file_env_devel}"; then
		die "development environment file is not specified"
	fi

	if test -z "${opt_dump_dir}"; then
		opt_dump_dir=$(pwd)
	fi

	if test -z "${opt_cygpath}"; then
		opt_cygpath=${has_cygpath}
	fi
}

################################################################################

# Processing of environment files

# Following variables contain filenames of environment files to operate on
#
# We may need to convert them to different encoding and convert CRLF to LF
# To not mess up with original files we operate on their copies in the
# temporary directory

file_env_devel=
file_env_user=

# Following variables contain contents of environment files
#
# env_user* variables contain contents from user environemnt file
# env_devel* variables contain contents from user environemnt file
#
# env_NAME_vars contains names of variables present in corresponding env_NAME
# varialbe
#
# env_NAME contains variables with their values as in the environment file
#
# env_NAME_PATH contains newline-saparated list of PATH values form corresponding
# environment file

env_user=
env_user_vars=
env_user_PATH=

env_devel=
env_devel_vars=
env_devel_PATH=

# TODO

vars_literal=
vars_common=
vars_dotnet=
vars_vc=
vars_vc_lists=
vars_other=

# Following variables are similar to env_* variables above, but contain
# final values to be written to generated profile file
#
# If --fast option is not used, they will contain variable references
#
# If cygpath is to be used, env_final_PATH will contain windows-style filenames,
# and unix-style filenames otherwise

env_final=
env_final_vars=
env_final_PATH=

# Following variables used to perform variable substitution
#
# They contain variables that already has been added to env_final* variables,
# however their values will be escaped so that they can be used in extended
# regular expressions to match themselves
#
# The purpose in to escape every value only once, so we need not to esacpe
# them over and over again when attempting variable substitution

env_quoted=
env_quoted_vars=

#
# Following functions transform environment files so that they can be read and
# further processed
#

# Output from powershell is usually UTF-16 encoded, while output from cmd is
# UTF-8 encoded.
#
# We set LC_ALL to C and if user does not supply differnet locale with
# --locale option we will try to convert them to ASCII
#
# If user supplied locale other than C and POSIX, we will attempt to guess
# correct encoding

# Convert file to a supporting encoding
#
# $1: file to convert
#
# If convertion fails execution aborts
#
_env_iconv() {
	local _original=$1
	local _converted=$(mktemp -p "${dir_tmp}" env-XXXXXXXX)

	local _from _to

	case ${LC_ALL} in
	C | POSIX)
		_to=ascii
		;;
	*.*)
		_to=${LC_ALL##*.}
		;;
	*)
		_to=utf-8
		;;
	esac

	for _from in utf-8 utf-16 utf-16le utf-16be; do
		if iconv -f ${_from} -t ${_to} "${_original}" >"${_converted}" 2>/dev/null; then
			if grep '^PATH' "${_converted}" >/dev/null 2>&1; then
				mv "${_converted}" "${_original}"
				return 0
			fi
		fi
	done

	die "failed to convert input file(s) to a supported encoding"
}

# Removes environment variables whose name is not a valid shell identifier
#
# $1: environment file to operate on
#
_env_normalize() {
	local __sed='/^[[:alpha:]_][[:alnum:]_]+=/!d'
	sed -i -E "${__sed}" "$1"
}

# Performs operations on environemt files so that they can be read and further
# processed
#
env_prepare() {
	file_env_user=$(mktemp -p "${dir_tmp}" env-XXXXXXXX)
	cp "${opt_file_env_user}" "${file_env_user}"

	file_env_devel=$(mktemp -p "${dir_tmp}" env-XXXXXXXX)
	cp "${opt_file_env_devel}" "${file_env_devel}"

	_env_iconv "${file_env_user}"
	convert_crlf_to_lf "${file_env_user}"
	_env_normalize "${file_env_user}"

	_env_iconv "${file_env_devel}"
	convert_crlf_to_lf "${file_env_devel}"
	_env_normalize "${file_env_devel}"
}

#
# Following functions are used to read environment files and assign related
# env_* variables
#

# Reads environment files and assigns env_devel* and env_user* variables
#
env_read() {
	local __sed=

	env_user=$(cat "${file_env_user}")
	env_devel=$(cat "${file_env_devel}")

	__sed='/^PATH=/ { s|^PATH=(.*)$|\1| ; s|[:]|\n|g ; p ; q }'

	env_user_PATH=$(run_sed -En "${__sed}" env_user)
	env_user=$(run_sed '' '/^PATH=/d' env_user)

	env_devel_PATH=$(run_sed -En "${__sed}" env_devel)
	env_devel=$(run_sed '' '/^PATH=/d' env_devel)

	__sed='s|^([^=]+)=.*$|\1|'

	env_user_vars=$(run_sed -E "${__sed}" env_user)
	env_devel_vars=$(run_sed -E "${__sed}" env_devel)
}

#
# Following functions are used to remove variables and values (for PATH) from
# development environment that also appear in user environemnt
#

# Remove variables that appear in both user and development environments
# Note that PATH is handled in another function
#
_env_remove_common() {
	local __sed

	local __save_IFS=${IFS}
	local IFS=${nl}

	local _var

	for _var in ${env_user_vars}; do
		__sed="/^${_var}(=.*)?$/d"

		env_devel=$(run_sed -E "${__sed}" env_devel)
		env_devel_vars=$(run_sed -E "${__sed}" env_devel_vars)
	done

	IFS=${__save_IFS}
}

# Remove some known unused variables form the development environment
#
_env_remove_unused() {
	local __sed

	local __save_IFS=${IFS}
	local IFS=${nl}

	local _var

	for _var in '_.*' PROMPT; do
		__sed="/^${_var}(=.*)?$/d"

		env_devel=$(run_sed -E "${__sed}" env_devel)
		env_devel_vars=$(run_sed -E "${__sed}" env_devel_vars)
	done

	IFS=${__save_IFS}
}

# Remove PATH entries that appear in both user and developmnet environments
#
_env_remove_PATH() {
	local __sed

	local __save_IFS=${IFS}
	local IFS=${nl}

	local _dir

	for _dir in ${env_user_PATH}; do
		__sed="/^$(sed_escape "${_dir}")\$/d"
		env_devel_PATH=$(run_sed -E "${__sed}" env_devel_PATH)
	done

	IFS=${__save_IFS}
}

# Removes variables and PATH entries that appear in both user and development
# environments from the development environment
#
# This function also resets env_user* variables as they are no longer needed
#
env_remove_user_vars() {
	_env_remove_common
	_env_remove_unused
	_env_remove_PATH

	env_user_vars=
	env_user=
	env_user_PATH=
}

#
# Following function are used to sort variables in the development environment
#

# This function is subroutine of env_sort and relies on variables avaialble
# in env_sort's context
#
# DO NOT CALL FROM OTHER PLACES
#
# This function moves values from env_devel* variables to temporary _env_devel*
# variables
#
# The name of moved variable is also appended to list specified by $2
#
# $1: name of variable to move
# $2: list to which append name of moved variable
#
_env_move() {
	local _var=$1
	local _variables _value

	_variables=$(run_grep -E "^${_var}\$" env_devel_vars)
	_value=$(run_grep -E "^${_var}=" env_devel)

	__sed="/^${_var}(=.*)?\$/d"

	env_devel_vars=$(run_sed -E "${__sed}" env_devel_vars)
	env_devel=$(run_sed -E "${__sed}" env_devel)

	append_list $2 "${_variables}"
	append_list _env_devel_vars "${_variables}"
	append_list _env_devel "${_value}"
}

# Sorts variables to perform variable substitution and sets vars_* variables
#
# This function is called even if --fast option has been passed
#
env_sort() {
	local __sed
	local _env_devel _env_devel_vars

	local _var

	# following varialbes, if present, will be added to vars_literal
	# They will be written as is and will not be used in variable substitution

	for _var in \
		VSCMD_VER \
		VSCMD_ARG_app_plat \
		VSCMD_ARG_HOST_ARCH \
		VSCMD_ARG_TGT_ARCH \
		'VSCMD_.+' \
		CommandPromptType \
		Platform \
		is_x64_arch \
		PreferredToolArchitecture; do

		if run_grep '-E' "^${_var}\$" env_devel_vars >/dev/null 2>&1; then
			_env_move "${_var}" vars_literal
		fi
	done

	# follwing variables, if present, will be added to vars_common
	#
	# we want them before any other variables when performing variable substitution

	for _var in \
		VisualStudioVersion \
		VSINSTALLDIR \
		DevEnvDir \
		'VS.*'; do

		if run_grep '-E' "^${_var}\$" env_devel_vars >/dev/null 2>&1; then
			_env_move "${_var}" vars_common
		fi
	done

	# follwing variables, if present, will be added to vars_dotnet

	for _var in \
		'[Ff]ramework.+' \
		'NET.+' \
		'FSHARP.+'; do

		if run_grep '-E' "^${_var}\$" env_devel_vars >/dev/null 2>&1; then
			_env_move "${_var}" vars_dotnet
		fi
	done

	# follwing variables, if present, will be added to vars_vc

	for _var in \
		VCINSTALLDIR \
		VCIDEInstallDir \
		VCToolsVersion \
		VCToolsRedistDir \
		VCToolsInstallDir \
		UniversalCRTSdkDir \
		UCRTVersion \
		WindowsSDKVersion \
		WindowsSDKLibVersion \
		WindowsSdkDir \
		ExtensionSdkDir; do

		if run_grep '-E' "^${_var}\$" env_devel_vars >/dev/null 2>&1; then
			_env_move "${_var}" vars_vc
		fi
	done

	# follwing variables, if present, will be added to vars_vc_list
	#
	# they contain semicolon-separated list of directories and must be written
	# to generated profile differently

	for _var in \
		'Windows.*Path' \
		EXTERNAL_INCLUDE \
		INCLUDE \
		LIBPATH \
		LIB; do

		if run_grep '-E' "^${_var}\$" env_devel_vars >/dev/null 2>&1; then
			_env_move "${_var}" vars_vc_lists
		fi
	done

	# all remaining variables will be added to vars_other

	for _var in ${env_devel_vars}; do
		_env_move "${_var}" vars_other
	done

	env_devel_vars=${_env_devel_vars}
	env_devel=${_env_devel}
}

#
# Following functions are used to perform variable substituion on variables in
# the development environment
#

# Escape value of a named variable and append it to env_qouted* variables
#
# $1: name of varable whose value must be escaped
#
_env_subst_escape() {
	local _var=$1
	local _value _qvalue __sed

	local __sed="/^${_var}=/ { s|^${_var}=|| ; p ; q }"

	_value=$(run_sed -n "${__sed}" env_final)
	_qvalue=$(sed_escape "${_value}")

	append_list env_quoted_vars "${_var}"
	append_list env_quoted "${_var}=${_qvalue}"
}

# Attempt variable substitution on the value of a named varaible
# The resulting value is written to standard output
#
# $1: name of variable on which to attempt variable substitution
#
_env_subst() {
	local _var=$1
	local _val __sed

	__sed="/^${_var}=/ { s|^${_var}=|| ; p ; q }"
	_val=$(run_sed -n "${__sed}" env_devel)

	local __save_IFS=${IFS}
	local IFS=${nl}

	local _qvar _qval

	for _qvar in ${env_quoted_vars}; do
		__sed="/^${_qvar}=/ { s|^${_qvar}=|| ; p ; q }"
		_qval=$(run_sed -n "${__sed}" env_quoted)

		__sed="s|${_qval}|\${${_qvar}}|g"
		_val=$(run_sed -E "${__sed}" _val)
	done

	IFS=${__save_IFS}

	printf "%s" "${_val}"
}

# Attempt variable substitution on values of env_devel_PATH
#
# The resulted list is assigned to env_final_PATH
#
_env_subst_PATH() {
	local _item _list

	local __save_IFS=${IFS}
	local IFS=${nl}

	local _qvar _qval

	for _item in ${env_devel_PATH}; do
		_item=$(path_unix_to_win "${_item}")
		append_list _list "${_item}"
	done

	for _qvar in ${env_quoted_vars}; do
		__sed="/^${_qvar}=/ { s|^${_qvar}=|| ; p ; q }"
		_qval=$(run_sed -n "${__sed}" env_quoted)

		__sed="s|${_qval}|\${${_qvar}}|"
		_list=$(run_sed -E "${__sed}" _list)
	done

	IFS=${__save_IFS}

	env_final_PATH=${_list}
}

# Perform variable substitution
#
env_subst() {
	local _var _val __sed

	for _var in ${vars_literal}; do
		_val=$(run_grep '' "^${_var}=" env_devel)

		append_list env_final_vars "${_var}"
		append_list env_final "${_val}"
	done

	for _var in ${vars_common} ${vars_dotnet} ${vars_vc}; do
		_val=$(_env_subst "${_var}")

		append_list env_final_vars "${_var}"
		append_list env_final "${_var}=${_val}"

		_env_subst_escape "${_var}"
	done

	for _var in ${vars_vc_lists} ${vars_other}; do
		_val=$(_env_subst "${_var}")

		append_list env_final_vars "${_var}"
		append_list env_final "${_var}=${_val}"
	done

	if str_is_yes "${opt_cygpath}"; then
		_env_subst_PATH
	else
		env_final_PATH=${env_devel_PATH}
	fi

	return 0
}

#
#
#

# Convert all directories in the env_devel_PATH to windows-style
#
# The resulted list is stored in env_final_PATH
#
env_PATH_to_win() {
	local __save_IFS=${IFS}
	local IFS=${nl}

	local _dir

	for _dir in ${env_devel_PATH}; do
		append_list env_final_PATH "$(path_unix_to_win "${_dir}")"
	done

	IFS=${__save_IFS}
}

#
# Handling of --sdk. --vctools and --vcredist options
#

# Update value of UCRTVersion variable in env_final to that passed with
# --sdk option
#
_env_finalize_sdk() {
	local _var=UCRTVersion
	local __sed="/^${_var}=/ s|^(${_var}=).*\$|\1${opt_sdk}|"

	env_final=$(run_sed -E "${__sed}" env_final)
}

# Update value of VCToolsVersion variable in env_final to that passed with
# --vctools option
#
_env_finalize_vctools() {
	local _var=VCToolsVersion
	local __sed="/^${_var}=/ s|^(${_var}=).*\$|\1${opt_vctools}|"

	env_final=$(run_sed -E "${__sed}" env_final)
}

# Update value of VCToolsRedistDir variable in env_final to that passed with
# --vcredist option
#
_env_finalize_vcredist() {
	local _var=VCToolsRedistDir
	local __sed="/^${_var}=/ s|[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+|${opt_vcredist}|"

	env_final=$(run_sed -E "${__sed}" env_final)
}

# Update specific variables in env_final if --sdk, --vctools and/or --vcredist
# options has been used
#
env_finalize() {
	test -n "${opt_sdk}" && _env_finalize_sdk
	test -n "${opt_vctools}" && _env_finalize_vctools
	test -n "${opt_vcredist}" && _env_finalize_vcredist
}

#
# Following functions are used to write resulting profile
#

# Write named variable to profile file
#
# Value will be written within single or double quotes depending on its contents
#
# $1: name of variable to write
#
_env_write_var() {
	local _var=$1
	local _val
	local _format

	local __sed

	__sed="/^${_var}=/ { s|^${_var}=|| ; p ; q }"
	_val=$(run_sed -n "${__sed}" env_final)

	case ${_val} in
	*\$*)
		_val=$(shell_escape_path "${_val}")
		_format='"%s"'
		;;
	*)
		_format="'%s'"
		;;
	esac

	_format="export %s=${_format}\n"

	printf "${_format}" "${_var}" "${_val}" >>"${_output}"
}

# Write named variable to profile file
#
# The variable's value is expected to be a semicolon-separated list
# Value will be written within single or double quotes depending on its contents
#
# $1: name of variable to write
#
_env_write_list() {
	local _var=$1
	local _list _item
	local __sed

	__sed="/^${_var}=/ { s|^${_var}=|| ; p ; q }"
	_list=$(run_sed -n "${__sed}" env_final | sed 's|;|\n|g' | tac)

	local __save_IFS=${IFS}
	local IFS=${nl}

	local _format

	printf '# %s\n' "${_var}" >>"${_output}"

	for _item in ${_list}; do

		case ${_item} in
		*\$*)
			_item=$(shell_escape_path "${_item}")
			_format='"%s"'
			;;
		*)
			_format="'%s'"
			;;
		esac

		_format="%s=${_format}\${%s:+;}\${%s}\n"

		printf "${_format}" "${_var}" "${_item}" "${_var}" "${_var}" >>"${_output}"
	done

	printf 'export %s\n' "${_var}" >>"${_output}"

	IFS=${__save_IFS}
}

# Write PATH varaible to profile file
#
# The value will be written differently depending on value of opt_cygpath
#
_env_write_PATH() {
	local _var=PATH

	local _list=$(print '%s\n' "${env_final_PATH}" | tac)
	local _item

	local _format

	if str_is_yes "${opt_cygpath}"; then
		_format="%s=\$(cygpath -u \"%s\")\${%s:+':'}\${%s}\\n"
	else
		_format="%s=\"%s\"\${%s:+':'}\${%s}\\n"
	fi

	local __save_IFS=${IFS}
	local IFS=${nl}

	printf '# PATH\n' >>"${_output}"

	for _item in ${_list}; do
		_item=$(shell_escape_path "${_item}")
		printf "${_format}" "${_var}" "${_item}" "${_var}" "${_var}" >>"${_output}"
	done

	printf 'export PATH\n' >>"${_output}"

	IFS=${__save_IFS}
}

# Write the profile file
#
env_write() {
	local _output=$(mktemp -p "${dir_tmp}" output-XXXXXXXX)

	local _val

	for _var in ${vars_literal} ${vars_common} ${vars_dotnet} ${vars_vc} ${vars_other}; do
		_env_write_var "${_var}"
	done

	for _var in ${vars_vc_lists}; do
		_env_write_list "${_var}"
	done

	_env_write_PATH

	test -f "${opt_file_output}" && rm -f "${opt_file_output}"
	cp "${_output}" "${opt_file_output}"
}

################################################################################

# Handling of --dump option

# Writes SDK.list
#
_dump_sdk() {
	local _file_tmp=$(mktemp -p "${dir_tmp}" sdk-XXXXXXXX)
	local _file_sdk=${opt_dump_dir}/SDK.list

	local _var=WindowsSdkDir

	local __sed="/^${_var}=/ { s|^${_var}=|| ; p ; q }"
	local _dir=$(run_sed -n "${__sed}" env_devel)

	if test -z "${_dir}"; then
		warning "cannot dump SDK.list - variable ${_var} is not found in environment file"
		return 1
	fi

	_dir=$(path_win_to_unix "${_dir}")

	if test -d "${_dir}"; then
		local _dirname

		for _dirname in lib include bin; do
			if test -d "${_dir}/${_dirname}"; then
				_dir=${_dir}/${_dirname}
				break
			fi
		done

		local __save_IFS=${IFS}
		local IFS=${nl}

		for _name in $(ls -w 1 "${_dir}"); do
			if run_grep -E "[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]" _name >/dev/null; then
				printf '%s\n' "${_name}" >>"${_file_tmp}"
			fi
		done

		IFS=${__save_IFS}

		test -f "${_file_sdk}" && rm -f "${_file_sdk}"
		mv "${_file_tmp}" "${_file_sdk}"
	else
		warning "cannot dump SDK.list - directory '${_dir}' does not exist"
	fi
}

# Used to implement _dump_vctools and _dump_vcredist
#
__dump_vc() {
	local _filename=$1
	local _var=$2
	local _regex=$3

	local _file_tmp=$(mktemp -p "${dir_tmp}" dump-XXXXXXXX)
	local _file_dump=${opt_dump_dir}/${_filename}

	local __sed="/^${_var}=/ { s|^${_var}=|| ; p ; q }"
	local _dir=$(run_sed -n "${__sed}" env_devel)

	if test -z "${_dir}"; then
		warning "cannot dump ${_filename} - variable ${_var} is not found in environment file"
		return 1
	fi

	_dir=$(path_win_to_unix "${_dir}")
	_dir=$(dirname "${_dir}")

	if test -d "${_dir}"; then
		local __save_IFS=${IFS}
		local IFS=${nl}

		for _name in $(ls -w 1 "${_dir}"); do
			if run_grep -E "${_regex}" _name >/dev/null; then
				printf '%s\n' "${_name}" >>"${_file_tmp}"
			fi
		done

		IFS=${__save_IFS}

		test -f "${_file_dump}" && rm -f "${_file_dump}"
		cp "${_file_tmp}" "${_file_dump}"
	else
		warning "cannot dump ${_filename} - directory '${_dir}' does not exist"
	fi
}

# Writes VCTOOLS.list
#
_dump_vctools() {
	__dump_vc VCTOOLS.list VCToolsInstallDir '^[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$'
}

# Writes VCREDIST.list
#
_dump_vcredist() {
	__dump_vc VCREDIST.list VCToolsRedistDir '^[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$'
}

# Write auxiliary files
#
dump() {
	if strcmp "${OS}" Windows_NT; then
		_dump_sdk
		_dump_vctools
		_dump_vcredist
	else
		warning "ignoring --dump option - non-windows host"
	fi
}

################################################################################

trap fini ABRT INT KILL QUIT

init

args_parse "$@"

# after env_prepare returns, the file_env_* variables will be set to names of
# environment files in the temporary directory and they must have LF
# end-of-line sequence and be converted to a supported encoding

env_prepare

# after env_read returns, the env_devel* end env_user* variables will be set

env_read

# after env_remove_user_vars return, the env_devel* variables will have only
# variables and values (PATH) that do not appear in the user environment
#
# the env_user* variables will be reset

env_remove_user_vars

if str_is_no "${opt_dump_only}"; then
	env_sort

	if str_is_yes "${opt_fast}"; then
		env_final_vars=${env_devel_vars}
		env_final=${env_devel}

		if str_is_yes "${opt_cygpath}"; then
			env_PATH_to_win
		else
			env_final_PATH=${env_devel_PATH}
		fi
	else
		env_subst
		env_finalize
	fi

	env_write
fi

if str_is_yes "${opt_dump}"; then
	dump
fi

fini 0
