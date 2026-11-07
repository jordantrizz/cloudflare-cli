#!/bin/bash
# -- A simple script to search for domains in your Cloudflare account
# -- Requires jq (https://stedolan.github.io/jq/)
# -- Usage: ./domain-search.sh <domain>
# -- Example: ./domain-search.sh example.com or ./domain-search.sh -f domains.txt

# -- Variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # -- Get current script directory
CACHE_FILE="$HOME/.cf-domain-search.cache"

# ==================================
# -- bash-ui (vendored)
# ==================================
# Human output goes through ui_* on stderr; result lines stay on stdout.
# Set BASH_UI to a checkout's ui.sh to develop against a working copy.
_cf_ui_dir="$SCRIPT_DIR"
_CF_UI_LIB=""
if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 2) )); then
	for _cf_ui_candidate in "${BASH_UI:-}" "$_cf_ui_dir/vendor/bash-ui/ui.sh" "$PWD/vendor/bash-ui/ui.sh"; do
		if [[ -n $_cf_ui_candidate && -r $_cf_ui_candidate ]]; then
			_CF_UI_LIB=$_cf_ui_candidate
			break
		fi
	done
fi
if [[ -n $_CF_UI_LIB ]]; then
	# shellcheck source=/dev/null
	source "$_CF_UI_LIB"
fi
unset _cf_ui_candidate

# Plain printf stubs keep a partial checkout (or bash 4.0/4.1) working.
if ! command -v ui_ok >/dev/null 2>&1; then
	ui_header()  { printf '== %s ==\n' "${1:-}" >&2; }
	ui_section() { printf '\n== %s ==\n' "${1:-}" >&2; }
	ui_step()    { printf '> %s\n' "$*" >&2; }
	ui_ok()      { printf 'OK: %s\n' "$*" >&2; }
	ui_warn()    { printf 'WARN: %s\n' "$*" >&2; }
	ui_err()     { printf 'ERR: %s\n' "$*" >&2; }
	ui_info()    { printf '%s\n' "$*" >&2; }
	ui_debug()   { [[ ${UI_VERBOSE:-0} == 1 ]] && printf 'DEBUG: %s\n' "$*" >&2; return 0; }
	ui_die()     { ui_err "${1:-}"; exit "${2:-1}"; }
	ui_kv()      { printf '  %-14s %s\n' "${1:-}" "${2:-}" >&2; }
	ui_list()    { printf '  - %s\n' "$@" >&2; }
	ui_hr()      { printf '%s\n' '----------------------------------------' >&2; }
	ui_style()   { shift; printf '%s' "$*"; }
	ui_confirm() { [[ ${UI_YES:-0} == 1 || ${2:-n} == y ]]; }
	ui_spin() { local _m=${1:-}; shift; if [[ ${1:-} == -- ]]; then shift; fi
		if "$@" >&2; then ui_ok "$_m"; else local _rc=$?; ui_err "$_m (exit $_rc)"; return "$_rc"; fi; }
	ui_table()   { cat >&2; }
	ui_summary() { :; }
fi

# -- Check if jq is installed
if ! [ -x "$(command -v jq)" ]; then
  ui_die "jq is not installed."
fi

# -- usage
usage() {
    USAGE=\
"Usage: ./domain-search.sh (-f file.txt|<domain>) [-h] [-t] [-d]

    Example: ./domain-search.sh example.com or ./domain-search.sh -f domains.txt

    Options
        -h, --help      Display this help and exit
        -f, --file      File containing list of domains to search for
        -t, --test      Test file containing list of domains to search for
        -d, --debug     Enable debug mode
        -c, --cache     Enable cache mode

"
    echo "$USAGE"
}

# -- Debug
_debug () {
    ui_debug "$1"
}

# -- All args
ALL_ARGS="${*}"

# -- Process arguments
    POSITIONAL=()
    while [[ $# -gt 0 ]]
    do
    key="$1"

    case $key in
        -h|--help)
        HELP=YES
        shift # past argument
        ;;
        -t|--test)
        TEST="1"
        shift # past argument
        ;;
        -f|--file)
        DOMAIN_FILE="$2"
        shift # past argument
        shift # past value
        ;;
        -c|--cache)
        CACHE=1
        shift # past argument
        ;;
        -d|--debug)
        DEBUG="1"
        UI_VERBOSE=1
        shift # past argument        
        ;;
        *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
    done
    set -- "${POSITIONAL[@]}" # restore positional parameters


# -- All args
_debug "ALL_ARGS: $ALL_ARGS"
_debug "\$1: $1"
_debug "TEST: $TEST"
_debug "DOMAIN_FILE: $DOMAIN_FILE"
_debug "DEBUG: $DEBUG"
[[ -n $1 ]] && DOMAIN="$1"

# -- Check if argument is passed
if [[ -z "$DOMAIN" && -z $DOMAIN_FILE ]]; then    
    usage
    ui_err "No domain specified"
    exit 1
elif [[ $HELP ]]; then
    usage
    exit 1
fi


# --------------------
# -- Main
# --------------------

ui_step "Getting list of domains using ./cloudflare"
if [[ $TEST ]]; then
    CF_DOMAINS=$(cat $SCRIPT_DIR/tests/domains.txt)
    _debug "CF_DOMAINS: $CF_DOMAINS"
else
    if [[ $CACHE ]]; then
        if [[ -f $CACHE_FILE ]]; then
            # -- Check if cache file is older than an hour
            if [[ $(find $CACHE_FILE -mmin +60) ]]; then
                ui_info "Cache file is older than an hour, deleting cache file and pulling in fresh cache"
                rm $CACHE_FILE
                CF_DOMAINS=$($SCRIPT_DIR/cloudflare list zones | awk '{print $1}')
                ui_info "Caching domains to $CACHE_FILE"
                echo "$CF_DOMAINS" > $HOME/.cf-domain-search.cache
            else
                ui_info "Cache file is not older than an hour, using cache file"
                CF_DOMAINS=$(cat $CACHE_FILE)
            fi
        else
            ui_info "Cache file does not exist, pulling in fresh cache"
            CF_DOMAINS=$($SCRIPT_DIR/cloudflare list zones | awk '{print $1}')
            ui_info "Caching domains to $CACHE_FILE"
            echo "$CF_DOMAINS" > $HOME/.cf-domain-search.cache
        fi
    else
        ui_step "Grabbing domains from Cloudflare API"
        CF_DOMAINS=$($SCRIPT_DIR/cloudflare list zones | awk '{print $1}')
    fi
fi
echo ""

if [[ $DOMAIN_FILE ]]; then
    if [[ -f $DOMAIN_FILE ]]; then
        # -- Search for matching domains from $FILE in Cloudflare account
        ui_step "Searching $DOMAIN_FILE for matching domains in the Cloudflare account"
        for domain in $(cat $DOMAIN_FILE); do
            SEARCH=$(grep '^'$domain'$' <<< "${CF_DOMAINS[@]}")
            if [[ $? == 0 ]]; then
                ui_style ok "$domain - FOUND"; printf '\n'
            else
                 ui_style err "$domain - NOTFOUND"; printf '\n'
            fi
        done
    else
        ui_err "$DOMAIN_FILE does not exist"
        exit 1
    fi
else
    # -- Search for matching domain from stdin in Cloudflare account
    ui_step "Searching for matching domain $DOMAIN in the Cloudflare account"
    SEARCH=$(echo "${CF_DOMAINS[@]}" | grep "$DOMAIN")
    if [[ $? == 0 ]]; then        
        ui_style ok "$DOMAIN - FOUND"; printf '\n'
    else
        ui_style err "$DOMAIN - NOTFOUND"; printf '\n'
    fi
fi


