#!/bin/bash

# =====================================
# -- Common functions and variables for cf-cli scripts
# =====================================

# -- Colors
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"
BLUEBG="\e[44m"
YELLOWBG="\e[43m"
GREENBG="\e[42m"
DARKGREYBG="\e[100m"
ECOL="\e[0m"

# ----------------------
# -- Messaging Functions
# ----------------------
_error () {
    echo -e "${RED}** ERROR ** - $1 ${ECOL}"
}

_success () {
    echo -e "${GREEN}** SUCCESS ** - $@ ${ECOL}"
}

_running () {
    echo -e "${BLUEBG}${@}${ECOL}"
}

_creating () {
    echo -e "${DARKGREYBG}${@}${ECOL}"
}

_separator () {
    echo -e "${YELLOWBG}****************${ECOL}"
}

_debug () {
    if [ $DEBUG == "1" ]; then
		# Echo to stderr
		echo -e "${CYAN}DEBUG: $@${ECOL}" >&2		
    fi
}

# -- die
_die() {
	if [ -n "$1" ];	then
		_error "$1"
	fi
	exit ${2:-1}
}

# -- check_bash - check version of bash
check_bash () {
	# - Check bash version and die if not at least 4.0
	if [ $BASH_VERSINFO -lt 4 ]; then
		_die "Sorry, you need at least bash 4.0 to run this script." 1
	fi
}

# -- is_* functions
is_debug() { [ "$DEBUG" = 1 ]; }
is_quiet() { [ "$quiet" = 1 ]; }
is_integer() { expr "$1" : '[0-9]\+$' >/dev/null; }
is_hex() { expr "$1" : '[0-9a-fA-F]\+$' >/dev/null; }

# -- credential masking functions
# Function to mask sensitive data for debug output (show only last 4 chars)
_mask_credential() {
	local credential="$1"
	local length=${#credential}
	if [ "$length" -le 4 ]; then
		echo "****"
	else
		local masked_part=$(printf '%*s' $((length - 4)) '' | tr ' ' '*')
		echo "${masked_part}${credential: -4}"
	fi
}

# Function to get masked email for debug (show first char + last 4 of domain)
_mask_email() {
	local email="$1"
	if [[ "$email" =~ ^([^@]+)@(.+)$ ]]; then
		local user="${BASH_REMATCH[1]}"
		local domain="${BASH_REMATCH[2]}"
		local user_masked="${user:0:1}***"
		local domain_masked="***${domain: -4}"
		echo "${user_masked}@${domain_masked}"
	else
		echo "***@***.***"
	fi
}