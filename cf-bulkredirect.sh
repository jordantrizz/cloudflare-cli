#!/usr/bin/env bash

# =================================================================================================
# cf-bulkredirect v0.0.1
# =================================================================================================

# ===============================================
# -- Source
# ===============================================
# shellcheck source=cloudflare.sh
source cf-inc.sh

# -- Debug
CMD_ALL="${*}"

HELP_BULKREDIRECT="Usage: cf-bulkredirect (import|export|add) [OPTIONS] [DOMAIN]

Commands:
    import                   Import redirects from a CSV file.
    export                   Export redirects to a CSV file.
    add                      Add a redirect.    
    get-lists <account>      Get all lists.
    get-list  <account>      Get a list items.
    get-account              Get account details.

Options:
    -h --help          Show this screen.
    -v --version       Show version.
    -d --debug         Debug mode.
"

# ===============================================
# -- Functions
# ===============================================

# -- Help
function _cf_bulkredirect_help() {
    echo "${HELP_BULKREDIRECT}"
}

# -- Export
function _cf_bulkredirect_export() {
    local FILE="${1}.csv" DOMAIN="${1}"
    _running "Exporting redirects to CSV file for Domain: ${DOMAIN} to ${FILE}"
    ZONE_ID=$(get_zone_id "${DOMAIN}")
    _running "Getting all redirects..."
    call_cf_v4 "zones/${ZONE_ID}/pagerules" > "${FILE}"

    # -- Export to CSV
    _running "Exporting to CSV..."
    _success "Done!"
}

# -- Import
function _import() {
    echo "Not completed"
}

# -- Add
function _add() {
    echo "Not completed"
}

# -- Get Lists
function _cf_bulkredirect_get_lists() {
    local ACCOUNT="${1}" OUTPUT    
    _running "Getting all lists for account: ${ACCOUNT}"
    OUTPUT="ID\tName\tKind\tItems\n"
    OUTPUT+="--\t----\t----\t-----\n"
    OUTPUT+=$(call_cf_v4 GET /accounts/${ACCOUNT}/rules/lists -- .result ,id,name,kind,num_items)
    echo -e "$OUTPUT" | column -t
}

# -- Get List
function _cf_bulkredirect_get_list() {
    local ACCOUNT="${1}" LIST_ID="${2}" OUTPUT
    _running "Getting list: ${LIST_ID} for account: ${ACCOUNT}"
    #OUTPUT="ID\tName\tKind\tItems\n"
    #OUTPUT+="--\t----\t----\t-----\n"
    OUTPUT+=$(call_cf_v4 GET /accounts/${ACCOUNT}/rules/lists/${LIST_ID}/items -- .result .redirect ,source_url)
    echo -e "$OUTPUT" | column -t
}

# -- Get Account ID from API Token
function _cf_bulkredirect_get_account() {    
    _running "Getting account details..."
    call_cf_v4 GET /accounts -- .result ,id,name %"%s$TA%s$TA#%s$TA%s$TA%s$NL"
}

# ==============================================================================================
# -- Start Script
# ==============================================================================================
_check_bash
_check_quiet
_check_debug
_check_cloudflare_credentials

_debug "Checking for options"
while [ -n "$1" ]
do
	case "$1" in
		-E)	shift
			CF_ACCOUNT=$1;;
		-T)	shift
			CF_TOKEN=$1;;
		--test) shift
			TEST=$1;;
		-D|--debug)
            _running "Debug mode enabled"
			DEBUG=1;;
		-DC|--debug-curl)
			DEBUG=1
			DEBUG_CURL_OUTPUT=2;;
		-d|--detail|--detailed|--details)
			details=1;;
		-q|--quiet)
			# TODO needs  to be re-implemmented
			QUIET=1;;
		-h|--help)
			_cf_bulkredirect_help
			_die
			;;
		--)	shift
			break;;
		-*)	false;;
		*)	break;;
	esac
	shift
done

# -- Check for arguments
if [ -z "$1" ]; then
	_cf_bulkredirect_help
	_die "Missing arguments" 1
fi

# -- Debug
CMD_ALL="${*}"
_running "Running: ${CMD_ALL}"

# ===============================================
# -- Main
# ===============================================
CMD1=$1
shift
case "$CMD1" in
    import)
        _import
        ;;
    export)
        if [[ -z "$1" ]]; then
            _cf_bulkredirect_help
            _die "Missing domain name" 1
        fi
        _cf_bulkredirect_export ${1}
        ;;
    add)
        _add
        ;;
    get-lists)
        if [[ -z "$1" ]]; then
            _cf_bulkredirect_help
            _die "Missing account name" 1
        fi
        _cf_bulkredirect_get_lists ${1}
        ;;
    get-list)
        if [[ -z "$1" ]]; then
            _cf_bulkredirect_help
            _die "Missing account name" 1
        elif [[ -z "$2" ]]; then
            _cf_bulkredirect_help
            _die "Missing list ID" 1
        fi
        _cf_bulkredirect_get_list ${1} ${2}
        ;;
    get-account)
        _cf_bulkredirect_get_account
        ;;
    *)
        _cf_bulkredirect_help
        _die "Invalid command! Use 'cf-bulkredirect --help' for more information." 1
        exit 1
        ;;
esac
