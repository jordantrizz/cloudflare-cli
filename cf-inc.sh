# =============================================================================
# -- cf-inc.sh - v2.2 - Cloudflare Includes
# =============================================================================

# ==================================
# -- Variables
# ==================================
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
# -- _check_cloudflare_creds_old $PRE_TAG
# -- Check for .cloudflare credentials
# =====================================
function _check_cloudflare_creds_old () {
    _debug "${FUNCNAME[0]} called with PRE_TAG: $1"
    _debug "API_PROFILE: $API_PROFILE"
    # -- PRE_TAG is the script, either CF_TS, CF_SPC or CF_
    local PRE_TAG=$1
    local CONFIG="$HOME/.cloudflare"

    # -- Check if $API_PROFILE is set, if so, use it
    if [[ -n $API_PROFILE ]]; then
        API_PROFILE=$(echo "$API_PROFILE" | tr '[:lower:]' '[:upper:]')
        _debug "Using API_PROFILE: $API_PROFILE"

        # Check if the profile exists in the .cloudflare file
        if [[ -f "$CONFIG" ]]; then
            _debug "Checking for profile $API_PROFILE in $CONFIG as ${PRE_TAG}ACCOUNT_${API_PROFILE}"
            if grep -q "^${PRE_TAG}ACCOUNT_${API_PROFILE}=" "$CONFIG"; then
                API_ACCOUNT=$(grep "^${PRE_TAG}ACCOUNT_${API_PROFILE}=" "$CONFIG" | cut -d= -f2-)
                API_APIKEY=$(grep "^${PRE_TAG}KEY_${API_PROFILE}=" "$CONFIG" | cut -d= -f2-)
                API_METHOD="account"
                _debug "Found profile $API_PROFILE: API_ACCOUNT = ${API_ACCOUNT} and API_APIKEY = ${API_APIKEY}"
            elif grep -q "^${PRE_TAG}TOKEN_${API_PROFILE}=" "$CONFIG"; then
                API_TOKEN=$(grep "^${PRE_TAG}TOKEN_${API_PROFILE}=" "$CONFIG" | cut -d= -f2-)
                API_METHOD="token"
                _debug "Found profile $API_PROFILE: API_TOKEN = ${API_TOKEN}"
            else
                _error "Profile $API_PROFILE not found in $CONFIG"
                exit 1
            fi
        fi
        return
    else
        _debug "No API_PROFILE:$API_PROFILE set, checking for credentials in .cloudflare file"
    fi


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

    # -- Final check
    if [[ -z $API_TOKEN && -z $API_ACCOUNT && -z $API_APIKEY ]]; then
        _error "No Cloudflare credentials found, please set via CLI or in \$HOME/.cloudflare"
        exit 1
    fi        
}

# =====================================
# -- _check_cloudflare_creds $PRE_TAG
# =====================================
function _check_cloudflare_creds () {
    _debug "${FUNCNAME[0]} called with PRE_TAG: $1"
    local PRE_TAG=$1
    local CONFIG="$HOME/.cloudflare"
    local -a available_profiles=()
    local -a profile_descriptions=()
    
    # Check if .cloudflare file exists
    if [[ ! -f "$CONFIG" ]]; then
        _error "No .cloudflare file found at $CONFIG"
        exit 1
    fi
    
    _debug "Processing .cloudflare file: $CONFIG"
    
    # Source the config file
    # shellcheck source=/dev/null
    source "$CONFIG"
    
    # Check for default CF_ACCOUNT and CF_KEY
    if [[ -n ${CF_ACCOUNT:-} ]]; then
        if [[ -n ${CF_KEY:-} ]]; then
            available_profiles+=("DEFAULT_ACCOUNT")
            profile_descriptions+=("Default - Account API (${CF_ACCOUNT})")
            _debug "Found default account: CF_ACCOUNT=${CF_ACCOUNT} CF_KEY=${CF_KEY}"
        else
            available_profiles+=("DEFAULT_ACCOUNT_INCOMPLETE")
            profile_descriptions+=("Default - Account API (${CF_ACCOUNT}) - (_KEY Missing)")
            _debug "Found incomplete default account: CF_ACCOUNT=${CF_ACCOUNT} but no CF_KEY"
        fi
    elif [[ -n ${CF_KEY:-} ]]; then
        available_profiles+=("DEFAULT_ACCOUNT_INCOMPLETE")
        profile_descriptions+=("Default - Account API - (_ACCOUNT Missing)")
        _debug "Found CF_KEY but no CF_ACCOUNT"
    fi
    
    # Check for default CF_TOKEN
    if [[ -n ${CF_TOKEN:-} ]]; then
        available_profiles+=("DEFAULT_TOKEN")
        profile_descriptions+=("Default - Token API")
        _debug "Found default token: CF_TOKEN=${CF_TOKEN}"
    fi
    
    # Find all profile-based configurations
    local profiles
    profiles=$(grep -E "^CF_[A-Z0-9_]+_(ACCOUNT|TOKEN|KEY)=" "$CONFIG" | sed -E 's/^CF_([A-Z0-9_]+)_(ACCOUNT|TOKEN|KEY)=.*/\1/' | sort -u)
    
    for profile in $profiles; do
        local account_var="CF_${profile}_ACCOUNT"
        local key_var="CF_${profile}_KEY"
        local token_var="CF_${profile}_TOKEN"
        
        # Check for profile account/key combination
        if [[ -n ${!account_var:-} ]]; then
            if [[ -n ${!key_var:-} ]]; then
                available_profiles+=("${profile}_ACCOUNT")
                profile_descriptions+=("${profile} - Account API (${!account_var})")
                _debug "Found profile account: ${account_var}=${!account_var} ${key_var}=${!key_var}"
            else
                available_profiles+=("${profile}_ACCOUNT_INCOMPLETE")
                profile_descriptions+=("${profile} - Account API (${!account_var}) - (_KEY Missing)")
                _debug "Found incomplete profile account: ${account_var}=${!account_var} but no ${key_var}"
            fi
        elif [[ -n ${!key_var:-} ]]; then
            available_profiles+=("${profile}_ACCOUNT_INCOMPLETE")
            profile_descriptions+=("${profile} - Account API - (_ACCOUNT Missing)")
            _debug "Found ${key_var} but no ${account_var}"
        fi
        
        # Check for profile token
        if [[ -n ${!token_var:-} ]]; then
            available_profiles+=("${profile}_TOKEN")
            profile_descriptions+=("${profile} - Token API")
            _debug "Found profile token: ${token_var}=${!token_var}"
        fi
    done
    
    # Check if we found any profiles
    if [[ ${#available_profiles[@]} -eq 0 ]]; then
        _error "No valid Cloudflare credentials found in $CONFIG"
        exit 1
    fi
    
    # If only one profile, use it automatically
    if [[ ${#available_profiles[@]} -eq 1 ]]; then
        local selected_profile="${available_profiles[0]}"
        _debug "Only one profile found, using: $selected_profile"
        _set_credentials_from_profile "$selected_profile"
        return
    fi
    
    # Multiple profiles found, prompt user to select
    echo "Multiple Cloudflare profiles found in $CONFIG:"
    echo
    for i in "${!available_profiles[@]}"; do
        echo "$((i+1)). ${profile_descriptions[i]}"
    done
    echo
    
    while true; do
        read -p "Select a profile (1-${#available_profiles[@]}): " selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#available_profiles[@]} ]]; then
            local selected_profile="${available_profiles[$((selection-1))]}"
            _debug "User selected profile: $selected_profile"
            _set_credentials_from_profile "$selected_profile"
            break
        else
            echo "Invalid selection. Please enter a number between 1 and ${#available_profiles[@]}."
        fi
    done
}

# =====================================
# -- _set_credentials_from_profile
# =====================================
function _set_credentials_from_profile() {
    local profile="$1"
    
    case "$profile" in
        "DEFAULT_ACCOUNT")
            API_ACCOUNT="$CF_ACCOUNT"
            API_APIKEY="$CF_KEY"
            API_METHOD="account"
            _debug "Set credentials: API_ACCOUNT=${API_ACCOUNT}, API_METHOD=${API_METHOD}"
            ;;
        "DEFAULT_TOKEN")
            API_TOKEN="$CF_TOKEN"
            API_METHOD="token"
            _debug "Set credentials: API_TOKEN=${API_TOKEN}, API_METHOD=${API_METHOD}"
            ;;
        *"_ACCOUNT")
            local profile_name="${profile%_ACCOUNT}"
            local account_var="CF_${profile_name}_ACCOUNT"
            local key_var="CF_${profile_name}_KEY"
            API_ACCOUNT="${!account_var}"
            API_APIKEY="${!key_var}"
            API_METHOD="account"
            _debug "Set credentials: API_ACCOUNT=${API_ACCOUNT}, API_METHOD=${API_METHOD}"
            ;;
        *"_TOKEN")
            local profile_name="${profile%_TOKEN}"
            local token_var="CF_${profile_name}_TOKEN"
            API_TOKEN="${!token_var}"
            API_METHOD="token"
            _debug "Set credentials: API_TOKEN=${API_TOKEN}, API_METHOD=${API_METHOD}"
            ;;
        *"_INCOMPLETE")
            _error "Selected profile is incomplete and cannot be used"
            exit 1
            ;;
        *)
            _error "Unknown profile type: $profile"
            exit 1
            ;;
    esac
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
