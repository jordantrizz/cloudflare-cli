#!/usr/bin/env bash
# =================================================================================================
# cf-partner
# =================================================================================================
# Cloudflare CLI is a command line tool for Cloudflare Partner API.
# =================================================================================================
# ==================================
# -- Variables
# ==================================
SCRIPT_NAME="cf-partner"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
VERSION=$(cat "${SCRIPT_DIR}/VERSION")
DEBUG="0"
DRYRUN="0"

# ==================================
# -- Include cf-inc.sh and cf-api-inc.sh
# ==================================
source "$SCRIPT_DIR/cf-inc.sh"
source "$SCRIPT_DIR/cf-inc-api.sh"

# ==============================================================================================
# -- Start Script
# ==============================================================================================

# ==============================================================================================
# -- Functions
# ==============================================================================================
# -- Help
function _cf_partner_help () {
    echo "Usage: cf-partner [OPTIONS] -c <command>"
    echo
    echo "Cloudflare Partner API"
    echo
    echo "Commands: -c, --command"
    echo "  create <name>                                - Create a new tenant"
    echo "  create-access <tenant-id> <account_id>       - Create a new tenant with access"
    echo "  list                                         - List all tenants"
    echo "  get <id>                                     - Get tenant details"
    echo "  delete <id>                                  - Delete tenant"
    echo
    echo "  add-access <tenant-id> <email> <role>        - Create a new access for tenant"
    echo "  get-access <tenant-id> <account_id>          - Get access for tenant"
    echo "  delete-access <tenant-id> <member-id>        - Get all roles"
    echo "  get-roles <tenant-id>                        - Get all roles"
    echo
    echo "Options:"
    echo "  -h, --help             Show this help message and exit"
    echo "  -q, --quiet            Suppress output"
    echo "  -d, --debug            Show debug output"
}

# ==============================================================================================
# -- Main
# ==============================================================================================
# -- Commands
_debug "ALL_ARGS: ${*}@"

# -- Parse options
    POSITIONAL=()
    while [[ $# -gt 0 ]]
    do
    key="$1"

    case $key in
		-c|--command)
		CMD="$2"
		shift # past argument
		shift # past variable
		;;
        -d|--debug)
        DEBUG="1"
        shift # past argument
        ;;
        -h|--help)
        _cf_partner_help
        exit 0
        ;;
        -q|--quiet)
        QUIET="1"
        shift # past argument
        ;;
        *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
    done
set -- "${POSITIONAL[@]}" # restore positional parameters

# -- Commands
_debug "PARSE_ARGS: ${*}@"

# -- pre-flight check
_debug "Pre-flight_check"
[[ $CMD != "test-token" ]] && _pre_flight_checkv2 "CF_TENANT_"

# -- Command: create
# ==================================
_debug "Command: $CMD"
if [[ $CMD == "create" ]]; then
    _debug "Command: create"
    NAME=$1
    [[ -z $NAME ]] && { _error "Missing tenant name"; exit 1; }
    _running "Creating tenant $NAME"
    _cf_tenant_create $NAME
# -- Command: create-access
# ==================================
elif [[ $CMD == "create-access" ]]; then
    _debug "Command: create-access"
    TENANT_ID=$1
    ACCOUNT_ID=$2
    [[ -z $TENANT_ID ]] && { _error "Missing tenant ID"; exit 1; }
    [[ -z $ACCOUNT_ID ]] && { _error "Missing account ID"; exit 1; }
    _running "Creating access for tenant $TENANT_ID"
    _cf_tenant_create_access $TENANT_ID $ACCOUNT_ID
# -- Command: list
# ==================================
elif [[ $CMD == "list" ]]; then    
    _debug "Command: list"
    ACCOUNT_ID=$(_get_account_id_from_creds)
    [[ $? -ne 0 ]] && { _error "Failed to get account id"; exit 1; }
    _debug "Account ID: $ACCOUNT_ID"
    _running "Fetching tenants for account $ACCOUNT_ID"
    _cf_tenant_list_all
# -- Command: get
# ==================================
elif [[ $CMD == "get" ]]; then
    _debug "Command: get"
    TENANT_ID=$1
    [[ -z $TENANT_ID ]] && { _error "Missing tenant ID"; exit 1; }
    _running "Fetching tenant $TENANT_ID"    
    _cf_tenant_get $TENANT_ID
# -- Command: delete
# ==================================
elif [[ $CMD == "delete" ]]; then
    _debug "Command: delete"
    TENANT_ID=$1
    [[ -z $TENANT_ID ]] && { _error "Missing tenant ID"; exit 1; }
    _running "Deleting tenant $TENANT_ID"
    # -- Confirm
    echo "Are you sure you want to delete tenant $TENANT_ID?"
    read -p "Continue (y/n)? " choice
    case "$choice" in
    y|Y ) _running "Deleting tenant $TENANT_ID";;
    n|N ) _error "Aborted"; exit 1;;
    * ) _error "Invalid"; exit 1;;
    esac
    _cf_delete_tenant $TENANT_ID
# -- Command: add-access
# ==================================
elif [[ $CMD == "add-access" ]]; then
    _debug "Command: access"
    TENANT_ID=$1
    EMAIL=$2
    ROLE=$3
    [[ -z $TENANT_ID ]] && { _error "Missing tenant ID"; exit 1; }
    [[ -z $EMAIL ]] && { _error "Missing email"; exit 1; }
    [[ -z $ROLE ]] && { _error "Missing role"; exit 1; }
    _running "Creating access for tenant $TENANT_ID with account $EMAIL and role $ROLE"
    _cf_tenant_access_add $TENANT_ID $EMAIL $ROLE
# -- Command: get-access
# ==================================
elif [[ $CMD == "get-access" ]]; then
    _debug "Command: get-access"
    TENANT_ID=$1
    [[ -z $TENANT_ID ]] && { _error "Missing tenant ID"; exit 1; }
    _running "Fetching access for tenant $TENANT_ID"
    _cf_tenant_access_get $TENANT_ID
# -- Command: delete-access
# ==================================
elif [[ $CMD == "delete-access" ]]; then
    _debug "Command: delete-access"
    TENANT_ID=$1
    MEMBER_EMAIL=$2
    [[ -z $TENANT_ID ]] && { _error "Missing tenant ID"; exit 1; }
    [[ -z $MEMBER_EMAIL ]] && { _error "Missing member ID"; exit 1; }
    _running "Deleting access for tenant $TENANT_ID with member $MEMBER_EMAIL"

    # -- Get Member ID from email
    MEMBER_ID=$(_cf_get_member_id_from_email $TENANT_ID $MEMBER_EMAIL)
    [[ $? -ne 0 ]] && { _error "Failed to get member id"; exit 1; }
    _debug "Member ID: $MEMBER_ID"
    
    # -- Confirm
    echo "Are you sure you want to delete access for tenant $TENANT_ID with member $MEMBER_EMAIL / $MEMBER_ID?"
    read -p "Continue (y/n)? " choice
    case "$choice" in
    y|Y ) _running "Deleting access for tenant $TENANT_ID with member $MEMBER_ID";;
    n|N ) _error "Aborted"; exit 1;;
    * ) _error "Invalid"; exit 1;;
    esac    

    _cf_tenant_access_delete $TENANT_ID $MEMBER_ID
# -- Command: get-roles
# ==================================
elif [[ $CMD == "get-roles" ]]; then
    _debug "Command: get-roles"
    TENANT_ID=$1
    [[ -z $TENANT_ID ]] && { _error "Missing tenant ID"; exit 1; }    
    _running "Fetching roles for account $TENANT_ID"
    _cf_tenant_roles_get $TENANT_ID
else
    _cf_partner_help
    exit 1
fi
