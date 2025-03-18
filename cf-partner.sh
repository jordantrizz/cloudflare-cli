#!/usr/bin/env bash

# =================================================================================================
# cloudflare-cli v1.0.1
# =================================================================================================
# shellcheck source=./cf-inc.sh
source cf-inc.sh

# ==============================================================================================
# -- Start Script
# ==============================================================================================

# -- Check functions
_check_bash
_check_quiet
_check_debug
_check_cloudflare_credentials
_check_required

# ==============================================================================================
# -- Functions
# ==============================================================================================
# -- Help
function _cf_partner_help () {
    echo "Usage: cf-partner [OPTIONS] -c <command>"
    echo
    echo "Cloudflare Partner API"
    echo
    echo "Commands:"
    echo "  -c, --command <command>  Command to execute"
    echo
    echo "Options:"
    echo "  -h, --help             Show this help message and exit"
    echo "  -q, --quiet            Suppress output"
    echo "  -d, --debug            Show debug output"
}

# ==============================================================================================
# -- Main
# ==============================================================================================