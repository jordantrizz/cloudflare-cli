# =============================================================================
# -- cf-inc.sh - v2 - Cloudflare Includes
# =============================================================================

# =============================================================================
# -- Variables
# =============================================================================
REQUIRED_APPS=("jq" "column")

# ==================================
# -- Colors
# ==================================
NC=$(tput sgr0)
CRED='\e[0;31m'
CRED=$(tput setaf 1)
CYELLOW=$(tput setaf 3)
CGREEN=$(tput setaf 2)
CBLUEBG=$(tput setab 4)
CCYAN=$(tput setaf 6)
CGRAY=$(tput setaf 7)
CDARKGRAY=$(tput setaf 8)

# =============================================================================
# -- Core Functions
# =============================================================================

# =====================================
# -- messages
# =====================================
_error () { echo -e "${CRED}** ERROR ** - ${*} ${NC}" >&2; } # _error
_warning () { echo -e "${CYELLOW}** WARNING ** - ${*} ${NC}"; } # _warning
_success () { echo -e "${CGREEN}** SUCCESS ** - ${*} ${NC}"; } # _success
_running () { echo -e "${CBLUEBG}${*}${NC}"; } # _running
_running2 () { echo -e " * ${CGRAY}${*}${NC}"; } # _running
_running3 () { echo -e " ** ${CDARKGRAY}${*}${NC}"; } # _running
_creating () { echo -e "${CGRAY}${*}${NC}"; }
_separator () { echo -e "${CYELLOWBG}****************${NC}"; }
_dryrun () { echo -e "${CCYAN}** DRYRUN: ${*$}${NC}"; }

# =====================================
# -- _debug $*
# =====================================
_debug () {
    if [[ $DEBUG == "1" ]]; then
        # Print ti stderr
        echo -e "${CCYAN}** DEBUG ** - ${*}${NC}" >&2
    fi
}

# =====================================
# -- debug_all
# =====================================
function _debug_all () {
	_debug "DEBUG_ALL: ${*}"
}

# =====================================
# -- _debug_json $*
# =====================================
#  Print JSON debug to file
# TODO - Should be removed.
_debug_json () {
    if [ -f $SCRIPT_DIR/.debug ]; then
        echo "${*}" | jq
    fi
}

# =====================================
# -- _pre_flight_checkv2 $PRE_TAG
# -- Check for .cloudflare credentials based on script
# =====================================
function _pre_flight_checkv2 () {
    # -- PRE_TAG is the script, either CF_TS, CF_SPC or CF_
    local PRE_TAG=$1
    [[ -z $PRE_TAG ]] && "CF_"

    # -- Check cloudflare creds
    _debug "Checking for Cloudflare credentials"
    _check_cloudflare_creds $PRE_TAG

    # -- Check required
    _debug "Checking for required apps"
    _check_required_apps

    # -- Check bash
    _debug "Checking for bash version"
    _check_bash

    # -- Check debug
    _debug "Checking for debug"
    _check_debug
}

# =====================================
# -- pre_flight_check
# -- Check for .cloudflare credentials
# =====================================
function pre_flight_check () {
    if [[ -n $API_TOKEN ]]; then
        _running "Found \$API_TOKEN via CLI using for authentication/."        
        API_TOKEN=$CF_SPC_TOKEN
    elif [[ -n $API_ACCOUNT ]]; then
        _running "Found \$API_ACCOUNT via CLI using as authentication."                
        if [[ -n $API_APIKEY ]]; then
            _running "Found \$API_APIKEY via CLI using as authentication."                        
        else
            _error "Found API Account via CLI, but no API Key found, use -ak...exiting"
            exit 1
        fi
    elif [[ -f "$HOME/.cloudflare" ]]; then
            _debug "Found .cloudflare file."
            # shellcheck source=$HOME/.cloudflare
            source "$HOME/.cloudflare"
            
            # If $CF_SPC_ACCOUNT and $CF_SPC_KEY are set, use them.
            if [[ $CF_SPC_TOKEN ]]; then
                _debug "Found \$CF_SPC_TOKEN in \$HOME/.cloudflare"
                API_TOKEN=$CF_SPC_TOKEN
            elif [[ $CF_SPC_ACCOUNT && $CF_SPC_KEY ]]; then
                _debug "Found \$CF_SPC_ACCOUNT and \$CF_SPC_KEY in \$HOME/.cloudflare"
                API_ACCOUNT=$CF_SPC_ACCOUNT
                API_APIKEY=$CF_SPC_KEY
            else
                _error "No \$CF_SPC_TOKEN exiting"
                exit 1
            fi 
    else
        _error "Can't find \$HOME/.cloudflare, and no CLI options provided."
    fi
}

# =====================================
# -- _check_cloudflare_creds $PRE_TAG
# -- Check for .cloudflare credentials
# =====================================
function _check_cloudflare_creds () {
    # -- PRE_TAG is the script, either CF_TS, CF_SPC or CF_
    local PRE_TAG=$1    

    if [[ -n $API_TOKEN ]]; then
        _running "Found \$API_TOKEN via CLI using for authentication/."        
        API_TOKEN=$CF_SPC_TOKEN
    elif [[ -n $API_ACCOUNT ]]; then
        _running "Found \$API_ACCOUNT via CLI using as authentication."                
        if [[ -n $API_APIKEY ]]; then
            _running "Found \$API_APIKEY via CLI using as authentication."                        
        else
            _error "Found API Account via CLI, but no API Key found, use -ak...exiting"
            exit 1
        fi
    elif [[ -f "$HOME/.cloudflare" ]]; then
        _debug "Found .cloudflare file."
        # shellcheck source=$HOME/.cloudflare
        source "$HOME/.cloudflare"
    
        # -- Check first if we have _ACCOUNT
        CHECK_CF_ACCOUNT="${PRE_TAG}ACCOUNT"    
        CHECK_CF_TOKEN="${PRE_TAG}TOKEN"
        if [[ ${!CHECK_CF_ACCOUNT} ]]; then            
            API_ACCOUNT=${!CHECK_CF_ACCOUNT}
            _debug "Found ${PRE_TAG}ACCOUNT = ${API_ACCOUNT} in \$HOME/.cloudflare"            
            CHECK_CF_KEY="${PRE_TAG}KEY"
            if [[ ${!CHECK_CF_KEY} ]]; then
                API_APIKEY=${!CHECK_CF_KEY}
                _debug "Found ${PRE_TAG}KEY = ${API_APIKEY} in \$HOME/.cloudflare"
            else
                _error "No ${PRE_TAG}KEY found in \$HOME/.cloudflare, required for ${PRE_TAG}ACCOUNT"
                exit 1
            fi
        elif [[ ${!CHECK_CF_TOKEN} ]]; then
            API_TOKEN=${!CHECK_CF_TOKEN}
            _debug "Found ${PRE_TAG}TOKEN = ${API_TOKEN} in \$HOME/.cloudflare"
        else
            _error "No ${PRE_TAG}TOKEN or ${PRE_TAG}KEY found in \$HOME/.cloudflare"
            exit 1
        fi
    fi
}

# =====================================
# -- _check_required_apps $REQUIRED_APPS
# -- Check for required apps
# =====================================
function _check_required_apps () {
    for app in "${REQUIRED_APPS[@]}"; do
        if ! command -v $app &> /dev/null; then
            _error "$app could not be found, please install it."
            exit 1
        fi
    done

    _debug "All required apps found."
}

# ===============================================
# -- _check_bash - check version of bash
# ===============================================
function _check_bash () {
	# - Check bash version and _die if not at least 4.0
	if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
		_die "Sorry, you need at least bash 4.0 to run this script." 1
	fi
}

# ===============================================
# -- _check_debug
# ===============================================
function _check_debug () {
	if [[ $DEBUG == "1" ]]; then
		echo -e "${CYAN}** DEBUG: Debugging is on${ECOL}"
	elif [[ $DEBUG_CURL_OUTPUT == "2" ]]; then
		echo -e "${CYAN}** DEBUG: Debugging is on + CURL OUTPUT${ECOL}"	
	fi
}

# =====================================
# -- json2keyval $JSON
# =====================================
function json2_keyval_array () {
    JSON="$1"
    echo "$JSON" | jq -r '
    .result[] |
    (["Key", "Value"],
    ["----", "-----"],
    (to_entries[] | [.key, (.value | tostring)]) | @tsv),
    "----------------------------"' | awk 'NR==1{print; next} /^$/{print "\n"; next} {print}' | column -t
}

# =====================================
# -- json2_keyval $JSON
# =====================================
function json2_keyval () {
    JSON="$1"
    echo "$JSON" | jq -r '
    def to_table:
        (["Key", "Value"],
        ["----", "-----"],
        (to_entries[] | [.key, (.value | tostring)]) | @tsv);

    if .result | type == "array" then
        .result[] | to_table, ""
    else
        .result | to_table
    end
    ' | awk 'NR==1{print; next} /^$/{print "\n"; next} {print}' | column -t
}
