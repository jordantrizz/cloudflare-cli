# =============================================================================
# -- cf-inc.sh - v2.2 - Cloudflare Includes
# =============================================================================

# ==================================
# -- Variables
# ==================================
REQUIRED_APPS=("jq" "column")
API_METHOD=""

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

_error () { [[ $QUIET == "0" ]] && echo -e "${CRED}** ERROR ** - ${*} ${NC}" >&2; } 
_warning () { [[ $QUIET == "0" ]] && echo -e "${CYELLOW}** WARNING ** - ${*} ${NC}" >&2; }
_success () { [[ $QUIET == "0" ]] && echo -e "${CGREEN}** SUCCESS ** - ${*} ${NC}"; }
_running () { [[ $QUIET == "0" ]] && echo -e "${CBLUEBG}${*}${NC}"; }
_running2 () { [[ $QUIET == "0" ]] && echo -e " * ${CGRAY}${*}${NC}"; }
_running3 () { [[ $QUIET == "0" ]] && echo -e " ** ${CDARKGRAY}${*}${NC}"; }
_creating () { [[ $QUIET == "0" ]] && echo -e "${CGRAY}${*}${NC}"; }
_separator () { [[ $QUIET == "0" ]] && echo -e "${CYELLOWBG}****************${NC}"; }
_dryrun () { [[ $QUIET == "0" ]] && echo -e "${CCYAN}** DRYRUN: ${*$}${NC}"; }
_quiet () { [[ $QUIET == "1" ]] && echo -e "${*}"; }

# =====================================
# -- debug - ( $MESSAGE, $LEVEL)
# =====================================
function _debug () {
    local DEBUG_MSG DEBUG_MSG_OUTPUT PREV_CALLER PREV_CALLER_NAME		
	DEBUG_MSG="${*}"

	# Get previous calling function
	PREV_CALLER=$(caller 1)
	PREV_CALLER_NAME=$(echo "$PREV_CALLER" | awk '{print $2}')

	if [ "$DEBUG" = "1" ]; then
		if [[ $DEBUG_CURL_OUTPUT = "1" ]]; then
			DEBUG_MSG_OUTPUT+="CURL_OUTPUT: $CURL_OUTPUT_GLOBAL"
		fi
		# -- Check if DEBUG_MSG is an array
        if [[ "$(declare -p "$arg" 2>/dev/null)" =~ "declare -a" ]]; then
			DEBUG_MSG_OUTPUT+="Array contents:"
			for item in "${arg[@]}"; do
			    DEBUG_MSG_OUTPUT+="${item}"
			done               
            echo -e "${CCYAN}** DEBUG: ${PREV_CALLER_NAME}: ARRAY: ${DEBUG_MSG_OUTPUT}${NC}" >&2    
		else
		    echo -e "${CCYAN}** DEBUG: ${PREV_CALLER_NAME}: ${DEBUG_MSG}${NC}" >&2
        fi
	fi

	if [[ $DEBUG_FILE == "1" ]]; then
		DEBUG_FILE_PATH="$HOME/cloudflare-cli-debug.log"
		echo -e "${PREV_CALLER_NAME}:${DEBUG_MSG_OUTPUT}" >> "$DEBUG_FILE_PATH"
	fi
}

# =====================================
# -- _pre_flight_check
# -- Check for .cloudflare credentials based on script
# =====================================
function _pre_flight_check () {
    # -- PRE_TAG is the script, either CF_TS, CF_SPC or CF_
    local PRE_TAG=$1
    [[ -z $PRE_TAG ]] && PRE_TAG="CF_"

    # -- Check cloudflare creds
    _debug "Checking for Cloudflare credentials"
    _check_cloudflare_creds $PRE_TAG

    # -- Check required
    _debug "Checking for required apps"
    _check_required_apps

    # -- Check bash
    _debug "Checking for bash version"
    _check_bash
}

# =====================================
# -- _check_cloudflare_creds_old $PRE_TAG
# -- Check for .cloudflare credentials
# =====================================
function _check_cloudflare_creds_old () {
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
# -- _check_cloudflare_creds $PRE_TAG
# -- Check for .cloudflare credentials
# =====================================
function _check_cloudflare_creds () {
    # -- PRE_TAG is the script, either CF_TS, CF_SPC or CF_
    local PRE_TAG=$1
    local CONFIG="$HOME/.cloudflare"

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
    elif [[ -f "$CONFIG" ]]; then
        _debug "Found .cloudflare file."
        # shellcheck source=$HOME/.cloudflare
        source "$CONFIG"

        # Gather all ${PRE_TAG}_ACCOUNT and ${PRE_TAG}_TOKEN variables from the file
        _debug "Gathering all ${PRE_TAG}ACCOUNT and ${PRE_TAG}TOKEN variables from $CONFIG"
        ACCOUNT_PROFILES=$(cat $CONFIG | grep -E "^${PRE_TAG}(ACCOUNT|TOKEN)_" | awk -F= '{print $1}' | sort -u)
        if [[ -z $ACCOUNT_PROFILES ]]; then
            _error "No ${PRE_TAG}ACCOUNT or ${PRE_TAG}TOKEN found in \$HOME/.cloudflare"
            exit 1
        fi

        # If we only have one profile, use it
        if [[ $(echo "$ACCOUNT_PROFILES" | wc -l) -eq 1 ]]; then
            # Check if ACCOUNT or TOKEN
            if [[ $ACCOUNT_PROFILES == *"ACCOUNT"* ]]; then
                API_ACCOUNT=$(grep "^${PRE_TAG}ACCOUNT=" "$CONFIG" | cut -d= -f2-)
                PROFILE_NAME=$(echo "$ACCOUNT_PROFILES" | grep "^${PRE_TAG}ACCOUNT")
                API_METHOD="account"
                if [[ $ACCOUNT_PROFILES == *"KEY"* ]]; then
                    API_APIKEY=$(grep "^${PRE_TAG}KEY=" "$CONFIG" | cut -d= -f2-)
                    _debug "Selected profile: $PROFILE_NAME with API_ACCOUNT = ${API_ACCOUNT} and API_KEY = ${API_APIKEY} and API_METHOD = ${API_METHOD} from $CONFIG"
                else
                    _error "No ${PRE_TAG}KEY found in $CONFIG, required for ${PRE_TAG}ACCOUNT"
                    exit 1
                fi
            elif [[ $ACCOUNT_PROFILES == *"TOKEN"* ]]; then
                API_APIKEY=$(grep "^${PRE_TAG}TOKEN=" "$CONFIG" | cut -d= -f2-)
                PROFILE_NAME=$(echo "$ACCOUNT_PROFILES" | grep "^${PRE_TAG}ACCOUNT")
                API_METHOD="token"
                _debug "Selected profile: $PROFILE_NAME with API_APIKEY = ${API_APIKEY} and API_METHOD = ${API_METHOD} from $CONFIG"
            else
                _error "No ${PRE_TAG}ACCOUNT or ${PRE_TAG}TOKEN found in $CONFIG"
                exit 1
            fi
        else
            # If we have multiple profiles, prompt user to select one
            echo "Multiple Cloudflare profiles found in $CONFIG:"
            select profile in $ACCOUNT_PROFILES; do
                if [[ -n $profile ]]; then
                _debug "Selected profile: $profile"
                PROFILE_NAME=$(echo "$profile" | sed "s/^${PRE_TAG}ACCOUNT_//")
                    if [[ $profile == *"ACCOUNT"* ]]; then
                        API_ACCOUNT=$(grep "^${profile}=" "$CONFIG" | cut -d= -f2-)
                        API_APIKEY=$(grep "^${PRE_TAG}KEY_${PROFILE_NAME}=" "$CONFIG" | cut -d= -f2-)
                        if [[ -n $API_APIKEY ]]; then
                            API_METHOD="account"
                            _debug "Selected ${PROFILE_NAME} = API_ACCOUNT: ${API_ACCOUNT} and API_APIKEY: ${API_APIKEY} and API_METHOD: ${API_METHOD} from $CONFIG"
                        else
                            _error "No ${PRE_TAG}KEY_${PROFILE_NAME} found in $CONFIG, required for ${profile}ACCOUNT"
                            exit 1
                        fi
                    elif [[ $profile == *"TOKEN"* ]]; then
                        API_TOKEN=$(grep "^${profile}=" "$CONFIG" | cut -d= -f2-)
                        API_METHOD="token"
                        _debug "Selected ${PROFILE_NAME} = API_APIKEY: ${API_APIKEY} and API_METHOD: ${API_METHOD} from $CONFIG"
                    else
                        _error "No ${profile}ACCOUNT or ${profile}TOKEN found in $CONFIG"
                        exit 1
                    fi
                    break
                else
                    _error "Invalid selection, please try again."
                fi
            done
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
