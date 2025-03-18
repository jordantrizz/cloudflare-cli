#!/usr/bin/env bash
# =================================================================================================
# cf-api-inc v1.0
# =================================================================================================

# =====================================
# -- Variables
# =====================================
API_URL="https://api.cloudflare.com"

# =====================================
# -- debug_jsons
# =====================================
_debug_json () {
    if [[ $DEBUG_JSON == "1" ]]; then
        echo -e "${CCYAN}** Outputting JSON ${*}${NC}"
        echo "${@}" | jq
    fi
}

# =====================================
# -- cf_api <$REQUEST> <$API_PATH>
# -- Run cf_api request and return output via $API_OUTPUT
# -- Run cf_api request and return exit code via $CURL_EXIT_CODE
# =====================================
function cf_api() {
    # -- Run cf_api with tokens
    _debug "function:${FUNCNAME[0]}"
    _debug "Running cf_api() with ${*}"

    if [[ -n $API_TOKEN ]]; then
        CURL_HEADERS=("-H" "Authorization: Bearer ${API_TOKEN}")
        _debug "Using \$API_TOKEN as 'Authorization: Bearer'. \$CURL_HEADERS: ${CURL_HEADERS[*]}"
        REQUEST="$1"
        API_PATH="$2"
        CURL_OUTPUT=$(mktemp)
    elif [[ -n $API_ACCOUNT ]]; then
            CURL_HEADERS=("-H" "X-Auth-Key: ${API_APIKEY}" -H "X-Auth-Email: ${API_ACCOUNT}")
            _debug "Using \$API_APIKEY as X-Auth-Key. \$CURL_HEADERS: ${CURL_HEADERS[*]}"
            REQUEST="$1"
            API_PATH="$2"
            CURL_OUTPUT=$(mktemp)
    else
        _error "No API Token or API Key found...major error...exiting"
        exit 1
    fi

    _debug "Running curl -s --request $REQUEST --url "${API_URL}${API_PATH}" "${CURL_HEADERS[*]}""
    [[ $DEBUG == "1" ]] && set -x
    CURL_EXIT_CODE=$(curl -s -w "%{http_code}" --request "$REQUEST" \
        --url "${API_URL}${API_PATH}" \
        "${CURL_HEADERS[@]}" \
        --output "$CURL_OUTPUT" "${EXTRA[@]}")
    [[ $DEBUG == "1" ]] && set +x
    API_OUTPUT=$(<"$CURL_OUTPUT")
    _debug_json "$API_OUTPUT"
    rm "$CURL_OUTPUT"


	if [[ $CURL_EXIT_CODE == "200" ]]; then
	    MESG="Success from API: $CURL_EXIT_CODE"
        _debug "$MESG"
        _debug "$API_OUTPUT"
	else
        MESG="Error from API: $CURL_EXIT_CODE"
        _error "$MESG"
        parse_cf_error "$API_OUTPUT"
        exit 1
    fi
}

# =====================================
# -- test_creds $ACCOUNT $API_KEY
# =====================================
function test_creds () {
    if [[ -n $API_TOKEN ]]; then
        _debug "function:${FUNCNAME[0]}"
        _running "Testing credentials via CLI"
        cf_api GET /client/v4/user/tokens/verify
        API_OUTPUT=$(echo $API_OUTPUT | jq '.messages[0].message' )
        [[ $CURL_EXIT_CODE == "200" ]] && _success "Success from API: $CURL_EXIT_CODE - $API_OUTPUT"
    elif [[ -n $API_APIKEY ]]; then
        _debug "function:${FUNCNAME[0]}"
        _running "Testing credentials via CLI"
        cf_api GET /client/v4/user
        API_OUTPUT=$(echo $API_OUTPUT | jq '.messages[0].message' )
        [[ $CURL_EXIT_CODE == "200" ]] && _success "Success from API: $CURL_EXIT_CODE - $API_OUTPUT"
    else
        _error "No API Token or API Key found, exiting"
        exit 1
    fi
}

# =====================================
# -- test_api_token $TOKEN
# =====================================
function test-token () {
    _debug "function:${FUNCNAME[0]}"
    _running "Testing token via CLI"
    cf_api GET /client/v4/user/tokens/verify
    API_OUTPUT=$(echo $API_OUTPUT | jq '.messages[0].message' )
    [[ $CURL_EXIT_CODE == "200" ]] && _success "Success from API: $CURL_EXIT_CODE - $API_OUTPUT"
}

# =====================================
# -- get_zone_id $DOMAIN_NAME
# -- Returns: message
# -- Get domain zoneid
# =====================================
function get_zone_id () {
    _debug "function:${FUNCNAME[0]}"
    _running "Getting zone_id for ${DOMAIN_NAME}"
    cf_api GET /client/v4/zones?name=${DOMAIN_NAME}
    if [[ $CURL_EXIT_CODE == "200" ]]; then
        ZONE_ID=$(echo $API_OUTPUT | jq -r '.result[0].id' )
        if [[ $ZONE_ID != "null" ]]; then
            _success "Got ZoneID ${ZONE_ID} for ${DOMAIN_NAME}"
        else
            _error "Couldn't get ZoneID, using -z to provide ZoneID or give access read:zone access to your token"
            echo "$MESG - $AP_OUTPUT"
            exit 1
        fi
    else
        _error "Couldn't get ZoneID, curl exited with $CURL_EXIT_CODE, check your \$CF_TOKEN or -t to provide a token"
        echo "$MESG - $AP_OUTPUT"
        exit 1
    fi
}

# =====================================
# -- get_zone_idv2 $DOMAIN_NAME
# -- Returns: var($ZONE_ID)
# -- Get domain zoneid
# =====================================
function get_zone_idv2 () {    
    DOMAIN_NAME=$1
    [[ -z $DOMAIN_NAME ]] && _error "Missing domain name" && exit 1
    _debug "function:${FUNCNAME[0]}"
    _debug "Getting zone_id for ${DOMAIN_NAME}"
    cf_api GET /client/v4/zones?name=${DOMAIN_NAME}
    if [[ $CURL_EXIT_CODE == "200" ]]; then
        ZONE_ID=$(echo $API_OUTPUT | jq -r '.result[0].id' )
        if [[ $ZONE_ID != "null" ]]; then
            echo $ZONE_ID
        else
            _debug "Couldn't get ZoneID, using -z to provide ZoneID or give access read:zone access to your token"
            _debug "$MESG - $AP_OUTPUT"
            exit 1
        fi
    else
        _debug "Couldn't get ZoneID, curl exited with $CURL_EXIT_CODE, check your \$CF_TOKEN or -t to provide a token"
        _debug "$MESG - $AP_OUTPUT"
        exit 1
    fi
}

# TODO Replace with get_zone_idv2
# ==================================
# -- CF_GET_ZONEID $CF_ZONE
# -- Get domain zoneid
# ==================================
CF_GET_ZONEID () {
    ZONE=$1
    CF_ZONEID_CURL=$(curl -s -X GET 'https://api.cloudflare.com/client/v4/zones/?per_page=500' \
    -H "X-Auth-Email: ${CF_ACCOUNT}" \
    -H "X-Auth-Key: ${CF_TOKEN}" \
    -H "Content-Type: application/json")
    CF_ZONEID_RESULT=$( echo $CF_ZONEID_CURL | jq -r '.success')
	if [[ $CF_ZONEID_RESULT == "false" ]]; then
		_error "Error getting Cloudflare Zone ID"
		echo $CF_ZONEID_CURL
		exit 1
	else
		CF_ZONEID=$( echo $CF_ZONEID_CURL | jq -r '.result[] | "\(.id) \(.name)"'| grep "$ZONE" | awk {' print $1 '})
		if [[ -z $CF_ZONEID ]]; then
			_error "Couldn't find domain $ZONE"
			exit 1
		else
			# Check to see if two ids are in CF_ZONEID, zones are separated by newlines
			ZONES_RETURNED=$(echo "$CF_ZONEID" | wc -l)
			if [[ ZONES_RETURNED -gt 1 ]]; then
				_warning "Found multiple zones for $ZONE"
				# List each zone with a number, zoneid and account email
				i=1
				echo "$CF_ZONEID" | while read -r ZONE; do
					ZONE_ID=$(echo "$ZONE" | awk '{print $1}')
					ZONE_NAME=$(_cf_zone_account_email $ZONE_ID)
					echo "$i - Zone ID: $ZONE_ID - $ZONE_NAME"
					i=$((i+1))
				done
				echo

				# Ask user to select the correct zone
				read -p "Please select the correct zone id: " SELECTED_ZONE
				# Make sure the selected zone is a number
				if [[ ! $SELECTED_ZONE =~ ^[0-9]+$ ]]; then
					_error "Invalid selection"
					exit 1
				fi
				# Confirm selected zone is in the list
				if [[ $SELECTED_ZONE -gt $ZONES_RETURNED ]]; then
					_error "Invalid selection"
					exit 1
				fi
				echo

				# Set CF_ZONEID to the selected zone based on number
				CF_ZONEID=$(echo "$CF_ZONEID" | awk -v SELECTED_ZONE=$SELECTED_ZONE 'NR==SELECTED_ZONE {print $1}')
			else
				_success "Found Zone ID $CF_ZONEID for $ZONE"
			fi
		fi
	fi
}

# =====================================
# -- _get_account_id_from_creds
# -- Get account ID from credentials
# =====================================
_get_account_id_from_creds () {
    _debug "function:${FUNCNAME[0]}"
    _debug "Getting account id from credentials"    
    cf_api GET /client/v4/user
    ACCOUNT_ID=$(echo $API_OUTPUT | jq -r '.result.id')
    if [[ $? -ne 0 ]]; then
        _debug "Return error from API: $CURL_EXIT_CODE - $API_OUTPUT"
        return 1
    elif [[ -z $ACCOUNT_ID ]]; then
        _debug "Account ID empty: $CURL_EXIT_CODE - $API_OUTPUT"
        return 1
    else
        echo $ACCOUNT_ID
    fi
}


# =====================================
# -- get_account_id_from_domain $DOMAIN
# =====================================
get_account_id_from_domain() {
    local DOMAIN_NAME=$1
     cf_api GET /client/v4/zones?name=${DOMAIN_NAME}
    ACCOUNT_ID=$(echo $API_OUTPUT | jq -r '.result[0].account.id')
    if [[ $ACCOUNT_ID == "null" ]]; then
        _error "No account id found for ${DOMAIN_NAME}"
        return 1
    else
        echo $ACCOUNT_ID
    fi
}

# =====================================
# -- get_account_id_from_zone $ZONE_ID
# =====================================
function get_account_id_from_zone () {
    ZONE_ID=$1
    _debug "function:${FUNCNAME[0]}"
    _debug "Getting account_id for ${ZONE_ID}"
    cf_api GET /client/v4/zones/${ZONE_ID}
    if [[ $CURL_EXIT_CODE == "200" ]]; then
        ACCOUNT_ID=$(echo $API_OUTPUT | jq -r '.result.account.id' )
        _debug "Account ID: $ACCOUNT_ID"
        if [[ $ACCOUNT_ID != "null" ]]; then
            echo $ACCOUNT_ID
        else
            _debug "Couldn't get AccountID, using -a to provide AccountID or give access read:account access to your token"
            _debug "$MESG - $AP_OUTPUT"
            exit 1
        fi
    else
        _debug "Couldn't get AccountID, curl exited with $CURL_EXIT_CODE, check your \$CF_TOKEN or -t to provide a token"
        _debug "$MESG - $AP_OUTPUT"
        exit 1
    fi
}

# =====================================
# -- get_permissions
# =====================================
get_permissions () {
    _debug "Running get_permissions"
    cf_api GET /client/v4/user/tokens/permission_groups
}


# =====================================
# -- parse_cf_error $API_OUTPUT
# =====================================
parse_cf_error () {
    API_OUTPUT=$1
    _debug "Running parse_cf_error"
    ERROR_CODE=$(echo $API_OUTPUT | jq -r '.errors[0].code')
    ERROR_MESSAGE=$(echo $API_OUTPUT | jq -r '.errors[0].message')
    _error "Error: $ERROR_CODE - $ERROR_MESSAGE"
}

# =============================================================================
# -- Cloudflare WAF Rule Functions
# =============================================================================

# ==================================
# -- cf_create_filter_json $ZONE_ID $JSON
# -- Create filter
# ==================================
function cf_create_filter_json() {
    local ZONE_ID=$1
    local JSON=$2
    _debug "Creating Filter - ZONE_ID: $ZONE_ID - JSON: $JSON"
    # -- Create JSON
    EXTRA=(-H "Content-Type: application/json" \
    -d "[$JSON]")

    if [[ $DRYRUN == "1" ]]; then
        _dryrun "URL = ${CF_API_ENDPOINT}"
        _dryrun "${EXTRA}"
    else
        # -- Create filter via cf_api
        cf_api POST /client/v4/zones/${ZONE_ID}/filters $EXTRA
        if [[ $CURL_EXIT_CODE == "200" ]]; then
            NEW_FILTER_ID=$(echo $API_OUTPUT | jq -r '.result[].id')
            _debug "New Filter Created -- JSON: ${JSON} ID: ${NEW_FILTER}"
            echo $NEW_FILTER_ID
        else
            # -- Grabbing error message.
            CF_CREATE_FILTER_ERROR=$( echo "$API_OUTPUT" | jq -r '.errors[] | "\(.message)"')

            # -- Duplicate filter found
            if [[ $CF_CREATE_FILTER_ERROR == "config duplicates an already existing config" ]]; then
                CF_DUPLICATE_FILTER_ID=$( echo $CF_CREATE_FILTER_CURL | jq -r '.errors[] | "\(.meta.id)"')
                _error "Duplicate ID: $CF_DUPLICATE_FILTER_ID. Please delete this ID first."
                return 1
            else
                _error "$MESG - $API_OUTPUT"
                parse_cf_error "$API_OUTPUT"
                return 1
            fi
        fi
    fi
}


# ==================================
# -- CF_CREATE_FILTER $ZONE_ID $CF_EXPRESSION
# -- Create filter
# ==================================
function CF_CREATE_FILTER() {
	local ZONE_ID=$1
	local CF_EXPRESSION=$2
	_debug "Creating Filter - ZONE_ID: $ZONE_ID - CF_EXPRESSION: $CF_EXPRESSION"
	# -- Create JSON
	EXTRA=(-H "Content-Type: application/json" \
	-d '[
  {
    "expression": "'"$CF_EXPRESSION"'"
  }
  ]')


	if [[ $DRYRUN == "1" ]];then
		_dryrun " ** DRYRUN: URL = ${CF_API_ENDPOINT}"
		_dryrun " ** DRYRUN: expression = ${CF_EXPRESSION}"
	else
		# -- Create filter via cf_api
		cf_api POST /client/v4/zones/${ZONE_ID}/filters $EXTRA
		if [[ $CURL_EXIT_CODE == "200" ]]; then
			NEW_FILTER_ID=$(echo $API_OUTPUT | jq -r '.result[].id')
			_debug "New Filter Created -- Expression: ${CF_EXPRESSION} ID: ${NEW_FILTER}"
			echo $NEW_FILTER_ID
		else
			# -- Grabbing error message.
			CF_CREATE_FILTER_ERROR=$( echo "$API_OUTPUT" | jq -r '.errors[] | "\(.message)"')

			# -- Duplicate filter found
			if [[ $CF_CREATE_FILTER_ERROR == "config duplicates an already existing config" ]]; then
				CF_DUPLICATE_FILTER_ID=$( echo $CF_CREATE_FILTER_CURL | jq -r '.errors[] | "\(.meta.id)"')
            	_error "Duplicate ID: $CF_DUPLICATE_FILTER_ID. Please delete this ID first."
				return 1
			else
				_error "$MESG - $API_OUTPUT"
				parse_cf_error "$API_OUTPUT"
		        return 1
		    fi
	    fi
    fi
}


# ==================================
# -- CF_CREATE_RULE $ZONE_ID $FILTER_ID $ACTION $PRIORITY $DESCRIPTION
# -- Create rule
# ==================================
function CF_CREATE_RULE () {
	local ZONE_ID=$1
	local FILTER_ID=$2
	local ACTION=$3
	local PRIORITY=$4
	local DESCRIPTION=$5

	_debug "Creating Rule - ZONE_ID: $ZONE_ID - FILTER_ID: $FILTER_ID - ACTION: $ACTION - PRIORITY: $PRIORITY - DESCRIPTION: $DESCRIPTION"
	# -- Create JSON
	EXTRA=(-H "Content-Type: application/json" \
	-d '[
  {
    "filter": {
      "id": "'"${FILTER_ID}"'"
    },
    "action": "'"${ACTION}"'",
    "priority": '"${PRIORITY}"',
    "description": "'"${DESCRIPTION}"'"
  }
]')


    if [[ $DRYRUN == "1" ]]; then
        _dryrun "URL = ${CF_API_ENDPOINT}"
		_dryrun "${EXTRA}"
    else
		# -- Create filter via cf_api
		cf_api POST /client/v4/zones/${ZONE_ID}/firewall/rules $EXTRA
		if [[ $CURL_EXIT_CODE == "200" ]]; then
			CF_CREATE_RULE_RESULT=$( echo $API_OUTPUT | jq -r '.success')
			NEW_RULE=$(echo $API_OUTPUT | jq '.result[].value')
			_debug "New Rule -- ${DESCRIPTION}: ${NEW_RULE}"
			echo $NEW_RULE
		else
			_error "ERROR: $MESG - $API_OUTPUT"
			exit 1
		fi
	fi
}

# =====================================
# -- cf_list_rules_action $DOMAIN $ZONE_ID
# =====================================
function cf_list_rules_action () {
    local DOMAIN_NAME=$1 ZONE_ID=$2
    _debug "function:${FUNCNAME[0]}"
    _running "Listing all rules for ${DOMAIN}/${ZONE_ID}"
    cf_api GET /client/v4/zones/${ZONE_ID}/firewall/rules
    if [[ $CURL_EXIT_CODE == "200" ]]; then
        _success "Success from API: $CURL_EXIT_CODE"
        # -- Get Total Rules
        TOTAL_RULES=$(echo $API_OUTPUT | jq -r '.result_info.total_count')
        if [[ $TOTAL_RULES == "0" ]]; then
            _warning "No rules found for ${DOMAIN}/${ZONE_ID}"
        else
            _success "Found Rules for ${DOMAIN}/${ZONE_ID} - Total Rules: $TOTAL_RULES"
            echo
            # -- Go through each rule and print out in numbered order
            echo $API_OUTPUT | jq -r '.result[] | "\(.id) \(.description)"' | awk '{print "#" NR, $0}'

        fi
    else
        _error "Error from API: $CURL_EXIT_CODE"
        parse_cf_error "$API_OUTPUT"
        exit 1
    fi
}

# =====================================
# -- cf_list_rules $ZONE_ID
# -- Get Rules
# =====================================
function cf_list_rules() {
    local ZONE_ID=$1
    _debug "Getting rules on $ZONE_ID"
    cf_api GET /client/v4/zones/${ZONE_ID}/firewall/rules
    if [[ $CURL_EXIT_CODE == "200" ]]; then
        echo $API_OUTPUT
    else
        _error "ERROR: $MESG - $API_OUTPUT"
        exit 1
    fi
}

# =====================================
# -- cf_get_rule $ZONE_ID $RULE_ID
# -- Get Rule
# =====================================
function cf_get_rule() {
    local ZONE_ID=$1
    local RULE_ID=$2
    _debug "Getting rule $RULE_ID on $ZONE_ID"
    cf_api GET /client/v4/zones/${ZONE_ID}/firewall/rules/${RULE_ID}
    if [[ $CURL_EXIT_CODE == "200" ]]; then
        # Print out each item and separate with an
        echo $API_OUTPUT
    else
        _error "ERROR: $MESG - $API_OUTPUT"
        exit 1
    fi
}

# =====================================
# -- cf_delete_rules_action $DOMAIN_NAME $ZONE_ID
# -- Delete all rules
# =====================================
function cf_delete_rules_action () {
	DOMAIN_NAME=$1
    ZONE_ID=$2
    OBJECT="${DOMAIN_NAME}/${ZONE_ID}"
	_running2 "Deleting all rules on ${OBJECT}"
	
    # -- Get a list of all rules
	ZONE_RULES=$(cf_list_rules $ZONE_ID)

	# -- Loop through all rules and delete
	ZONE_RULES_COUNT=$(echo $ZONE_RULES | jq -r '.result_info.count')
	if [[ $ZONE_RULES_COUNT == "0" ]]; then
		_error "No rules found for ${OBJECT}"
		exit 1
	else
		# -- Print out rules
		_running2 "Looping rules $ZONE_RULES_COUNT on ${OBJECT} to delete"
		echo ""
		echo "$ZONE_RULES" | jq -r '.result[] | "\(.id) \(.description)"' | awk '{print "#" NR, $0}'
		echo ""
        
        # -- Ask user if they want to delete all rules at once
        read -p "Do you want to delete all rules at once? (y|n) " delete_all
        if [[ $delete_all == [Yy]* ]]; then
            for RULE_ID in $(echo $ZONE_RULES | jq -r '.result[].id'); do
                cf_delete_rule $ZONE_ID $RULE_ID
                FILTER_ID=$(echo $ZONE_RULES | jq -r --arg RULE_ID "$RULE_ID" '.result[] | select(.id == $RULE_ID) | .filter.id')
                cf_delete_filter $ZONE_ID $FILTER_ID
            done
            _success "All rules deleted."
		else
            # -- Loop through all rules
            _debug "Looping through rules to get filter ID's"
            for RULE_ID in $(echo $ZONE_RULES | jq -r '.result[].id'); do
                _debug "Rule ID: $RULE_ID"
                RULE_OUTPUT=$(cf_get_rule $ZONE_ID $RULE_ID | jq -r '.result | [.id, .description, .filter.id] | join("|")')
                _debug "Rule Output: $RULE_OUTPUT"
                # Get Rule Data, each on new line
                while IFS='|' read -r RULE_ID2 DESCRIPTION FILTER_ID; do
                    _debug "Rule ID: $RULE_ID2 - Description: $DESCRIPTION - Filter ID: $FILTER_ID"
                    FILTER_ID_DELETE=$FILTER_ID
                    FILTER_DESCRIPTION=$DESCRIPTION
                done <<< "$RULE_OUTPUT"
                _running3 "Rule: $RULE_ID Filter: $FILTER_ID_DELETE Description: $FILTER_DESCRIPTION"
                read -p "  - Delete rule? $RULE_ID (y|n)" yn
                case $yn in
                    [Yy]* )
                    cf_delete_rule $ZONE_ID $RULE_ID
                    cf_delete_filter $ZONE_ID $FILTER_ID_DELETE
                    echo
                    ;;
                    [Nn]* ) exit;;
                    * ) echo "Please answer yes or no.";;
                esac
            done
        fi
	fi
}

# =====================================
# -- cf_delete_rule_action $DOMAIN_NAME $ZONE_ID $RULE_ID
# -- Delete rule
# =====================================
function cf_delete_rule_action () {
	local DOMAIN_NAME=$1
    local ZONE_ID=$2
    local RULE_ID=$3
    OBJECT="${DOMAIN_NAME}/${ZONE_ID}"

    # -- Check if rule exists
    RULE_EXISTS=$(cf_get_rule $ZONE_ID $RULE_ID)
    if [[ $? -ne 0 ]]; then
        _error "Rule $RULE_ID doesn't exist on $OBJECT"
        return 1
    else
        # -- Get Rule Data, print and set variables
        while IFS='|' read -r RULE_ID2 DESCRIPTION FILTER_ID; do
            _debug "Rule ID: $RULE_ID2 - Description: $DESCRIPTION - Filter ID: $FILTER_ID"
            FILTER_ID_DELETE=$FILTER_ID
            FILTER_DESCRIPTION=$DESCRIPTION
        done <<< "$RULE_EXISTS"
        _running2 "Rule: $RULE_ID Filter: $FILTER_ID_DELETE Description: $FILTER_DESCRIPTION"
        read -p "  - Delete rule? (y|n)" yn
        case $yn in
            [Yy]* )
            cf_delete_rule $ZONE_ID $RULE_ID
            CF_DELETE_FILTER $ZONE_ID $FILTER_ID_DELETE
            ;;
            [Nn]* ) exit;;
            * ) echo "Please answer yes or no.";;
        esac
    fi
}

# =====================================
# -- cf_delete_rule $ZONE_ID $RULE_ID
# -- Delete rule
# =====================================
function cf_delete_rule () {
    local ZONE_ID=$1
    local RULE_ID=$2
    OBJECT="${DOMAIN_NAME}/${ZONE_ID}"

	_debug "Deleting rule $RULE_ID on $OBJECT"

	cf_api DELETE /client/v4/zones/${ZONE_ID}/firewall/rules/${RULE_ID}

    if [[ $CURL_EXIT_CODE == "200" ]]; then
		_success "Rule $RULE_ID deleted"
	else
		_error "ERROR: $MESG - $API_OUTPUT"
		exit 1
	fi
}

# ==================================
# cf_list_filters_action $DOMAIN $ZONE_ID
# -- Get Filters
# ==================================
function cf_list_filters_action () {
    local DOMAIN_NAME=$1
    local ZONE_ID=$2

    OBJECT="${DOMAIN_NAME}/${ZONE_ID}"
    _running2 "Listing all filters for ${OBJECT}"

    cf_api GET /client/v4/zones/${ZONE_ID}/filters
    if [[ $CURL_EXIT_CODE == "200" ]]; then
        _success "Success from API: $CURL_EXIT_CODE"
        # -- Get Total Filters
        TOTAL_FILTERS=$(echo $API_OUTPUT | jq -r '.result_info.total_count')
        if [[ $TOTAL_FILTERS == "0" ]]; then
            _warning "No filters found for ${DOMAIN_NAME}/${ZONE_ID}"
        else
            _success "Found Filters for ${DOMAIN_NAME}/${ZONE_ID} - Total Filters: $TOTAL_FILTERS"
            echo
            # -- Go through each filter and print out in numbered order
        echo $API_OUTPUT | jq -r '.result[] | "\(.id) \(.expression) \(.paused)"' | \
        awk '{print "#" NR, $0"\n----------------------------------------"}'
        fi
    else
        _error "Error from API: $CURL_EXIT_CODE"
        parse_cf_error "$API_OUTPUT"
        exit 1
    fi
}

# =====================================
# cf_list_filters $ZONE_ID
# -- Get Filters
# ==================================
function CF_GET_FILTERS() {
	local ZONE_ID=$1
	_debug "Getting filters on $ZONE_ID"
	cf_api GET /client/v4/zones/${ZONE_ID}/filters
	if [[ $CURL_EXIT_CODE == "200" ]]; then
		echo $API_OUTPUT
	else
		_error "ERROR: $MESG - $API_OUTPUT"
		exit 1
	fi
}

# =====================================
# -- cf_list_filter $ZONE_ID $FILTER_ID
# -- Get Filter
# =====================================
function cf_list_filter () {
    local ZONE_ID=$1
    local FILTER_ID=$2
    _debug "Getting filter $FILTER_ID on $ZONE_ID"
    cf_api GET /client/v4/zones/${ZONE_ID}/filters/${FILTER_ID}
    if [[ $CURL_EXIT_CODE == "200" ]]; then
        echo $API_OUTPUT
    else
        _error "ERROR: $MESG - $API_OUTPUT"
        exit 1
    fi
}

# =====================================
# -- cf_delete_filter_action $DOMAIN_NAME $ZONE_ID $FILTER_ID
# -- Delete filter
# =====================================
function cf_delete_filter_action () {
    local DOMAIN_NAME=$1
    local ZONE_ID=$2
    local FILTER_ID=$3
    OBJECT="${DOMAIN_NAME}/${ZONE_ID}"
    _running2 "Deleting filter $FILTER_ID on $OBJECT"
    cf_delete_filter $ZONE_ID $FILTER_ID
    if [[ $? -eq 0 ]]; then
        _success "Filter $FILTER_ID deleted"
    else
        _error "ERROR: $MESG - $API_OUTPUT"
        exit 1
    fi
}

# =====================================
# -- cf_delete_filters_action $DOMAIN_NAME $ZONE_ID
# -- Delete all filters
# =====================================
function cf_delete_filters_action () {
    local DOMAIN_NAME=$1
    local ZONE_ID=$2

    OBJECT="${DOMAIN_NAME}/${ZONE_ID}"
    _running2 "Deleting all filters on $OBJECT"

    # -- Get a list of all filters
    ZONE_FILTERS=$(CF_GET_FILTERS $ZONE_ID)

    # -- Loop through all filters and delete
    ZONE_FILTERS_COUNT=$(echo $ZONE_FILTERS | jq -r '.result_info.count')
    if [[ $ZONE_FILTERS_COUNT == "0" ]]; then
        _error "No filters found for $OBJECT"
        exit 1
    else
        # -- Print out filters
        _running2 "Looping filters $ZONE_FILTERS_COUNT on $OBJECT to delete"
        echo ""
        echo "$ZONE_FILTERS" | jq -r '.result[] | "\(.id) \(.expression) \(.paused)"' | \
        awk '{print "#" NR, $0"\n----------------------------------------"}'
        echo ""
        # -- Loop through all filters
        _debug "Looping through filters to get filter ID's"
        for FILTER_ID in $(echo $ZONE_FILTERS | jq -r '.result[] | "\(.id)"'); do
            # -- Print out filter seperate by |
            FILTER_OUTPUT=$(cf_list_filter $ZONE_ID $FILTER_ID | jq -r '.result | [.id, .expression, .paused] | join("|")')
            # Get Filter Data, print and set variables
            while IFS='|' read -r FILTER_ID2 EXPRESSION PAUSED; do
                _debug "Filter ID: $FILTER_ID2 - Expression: $EXPRESSION - Paused: $PAUSED"
                FILTER_ID_DELETE=$FILTER_ID2
                FILTER_EXPRESSION=$EXPRESSION
                FILTER_PAUSED=$PAUSED
            done <<< "$FILTER_OUTPUT"
            _running3 "Filter: $FILTER_ID_DELETE Expression: $FILTER_EXPRESSION Paused: $FILTER_PAUSED"
            read -p " - Delete filter $FILTER_ID_DELETE? (y|n)" yn
            case $yn in
                [Yy]* )
                DELETE_OUTPUT=$(cf_delete_filter $ZONE_ID $FILTER_ID_DELETE)
                [[ $? -eq 0 ]] && _success "Filter $FILTER_ID_DELETE deleted"
                ;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
}

# =====================================
# -- cf_delete_filter $ZONE_ID $FILTER_ID
# -- Delete filter
# =====================================
function cf_delete_filter () {
	local ZONE_ID=$1
	local FILTER_ID=$2

	_debug "Deleting filter $FILTER_ID on zone $ZONE_ID"

	cf_api DELETE /client/v4/zones/${ZONE_ID}/filters/${FILTER_ID}
    if [[ $CURL_EXIT_CODE == "200" ]]; then
		_success "Filter $RULE_ID deleted"
	else
		_error "ERROR: $MESG - $API_OUTPUT"
		exit 1
	fi
}

# =============================================================================
# -- Cloudflare Tenant Commands
# =============================================================================

# ===============================================
# -- _cf_tenant_create $TENANT_NAME $ACCOUNT_ID
# -- Create a tenant
# ===============================================
function _cf_tenant_create () {
	_debug_all "func : ${*}"
	local TENANT_NAME="$1" ACCOUNT_ID="$2"

	# -- Create Tenant
	_debug "Creating tenant - $TENANT_NAME"
    EXTRA=(-H "Content-Type: application/json" \
    -d '{
        "name": "'"${TENANT_NAME}"'"
    }')

	cf_api POST /client/v4/accounts $EXTRA
    
    if [[ $CURL_EXIT_CODE == "200" ]]; then
        NEW_TENANT_ID=$(echo $API_OUTPUT | jq -r '.result.id')
        _debug "New Tenant Created -- Name: ${TENANT_NAME} ID: ${NEW_TENANT_ID}"
        _success "Created Tenant: $NEW_TENANT_ID"
    else
        _error "ERROR: $MESG - $API_OUTPUT"
        exit 1
    fi

    _running2 "Getting tenant $NEW_TENANT_ID"
    CONFIRM_TENANT="$(_cf_get_tenant $NEW_TENANT_ID)"
    [[ $? -ne 0 ]] && _error "Couldn't get tenant" && exit 1
    _success "Tenant: $CONFIRM_TENANT"

}

# ===============================================
# -- _cf_tenant_get $TENANT_ID
# -- List a tenant
# ===============================================
function _cf_tenant_get () {
    _debug_all "func : ${*}"
    local TENANT_ID="$1"
    [[ -z $TENANT_ID ]] && _error "Missing tenant ID" && exit 1

    # -- List Tenant
    _debug "Listing tenant"
    cf_api GET /client/v4/accounts/$TENANT_ID
    if [[ $CURL_EXIT_CODE == "200" ]]; then
        echo $API_OUTPUT | jq -r '.result | "\(.id) \(.name)"'
    else
        _error "ERROR: $MESG - $API_OUTPUT"
        exit 1
    fi
}

# ===============================================
# -- _cf_tenant_list_all $ACCOUNT_ID
# -- List all tenants
# ===============================================
function _cf_tenant_list_all () {
    _debug_all "func : ${*}"
    local ACCOUNT_ID="$1"

    # -- List Tenants
    _debug "Listing tenants for $ACCOUNT_ID"
    cf_api GET /client/v4/accounts
    if [[ $CURL_EXIT_CODE == "200" ]]; then
        echo $API_OUTPUT | jq -r '.result[] | "\(.id) \(.name)"' | awk '{print "#" NR, $0}'        
    else
        _error "ERROR: $MESG - $API_OUTPUT"
        exit 1
    fi
}

# ===============================================
# -- _cf_tenant_delete $TENANT_ID
# -- Delete a tenant
# ===============================================
function _cf_tenant_delete () {
    _debug_all "func : ${*}"
    local TENANT_ID="$1"
    [[ -z $TENANT_ID ]] && _error "Missing tenant ID" && exit 1

    # -- Delete Tenant
    _debug "Deleting tenant"
    cf_api DELETE /client/v4/accounts/$TENANT_ID
    if [[ $CURL_EXIT_CODE == "200" ]]; then
        _success "Deleted Tenant: $TENANT_ID"
    else
        _error "ERROR: $MESG - $API_OUTPUT"
        exit 1
    fi
}

# ===============================================
# -- _cf_tenant_roles_get $TENANT_ID
# -- Get tenant roles
# ===============================================
function _cf_tenant_roles_get () {
    _debug_all "func : ${*}"
    local TENANT_ID="$1"
    [[ -z $TENANT_ID ]] && _error "Missing tenant ID" && exit 1

    # -- Get Tenant Roles
    _debug "Getting tenant roles"
    cf_api GET /client/v4/accounts/$TENANT_ID/roles
    if [[ $CURL_EXIT_CODE == "200" ]]; then
        echo $API_OUTPUT | jq -r '.result[] | "\(.id) \(.name)"' | awk '{print "#" NR, $0}'
    else
        _error "ERROR: $MESG - $API_OUTPUT"
        exit 1
    fi
}

# ===============================================
# -- _cf_tenant_access_add $TENANT_ID $EMAIL $ROLE
# -- Create a tenant access
# ===============================================
function _cf_tenant_access_add () {
    _debug_all "func : ${*}"
    local TENANT_ID="$1" EMAIL="$2" ROLE="$3"
    [[ -z $TENANT_ID ]] && _error "Missing tenant ID" && exit 1
    [[ -z $EMAIL ]] && _error "Missing email" && exit 1
    [[ -z $ROLE ]] && _error "Missing role" && exit 1

    # -- Role Mapping
    # 05784afa30c1afe1440e79d9351c7430 - Administrator

    if [[ $ROLE == "administrator" ]]; then
        ROLE_ID="05784afa30c1afe1440e79d9351c7430"
    else
        _error "Invalid role"
        exit 1
    fi

    # -- Create Tenant Access
    _debug "Creating tenant access - $EMAIL - $ROLE_ID"
    EXTRA=(-H "Content-Type: application/json" \
    -d '{
        "email": "'"${EMAIL}"'",
        "roles": ["'"${ROLE_ID}"'"]
    }')

    cf_api POST /client/v4/accounts/$TENANT_ID/members $EXTRA
    if [[ $CURL_EXIT_CODE == "200" ]]; then
        _success "New Tenant Access Created"
        echo $API_OUTPUT | jq -r '.result | "ID: \(.user.id) First Name: \(.user.first_name) Last Name: \(.user.last_name) Email: \(.user.email) 2FA: \(.two_factor_authentication_enabled) Status: \(.status)"'
    else
        _error "ERROR: $MESG - $API_OUTPUT"
        exit 1
    fi
}

# ===============================================
# -- _cf_tenant_access_get $TENANT_ID
# -- Get a tenant access
# ===============================================
function _cf_tenant_access_get () {
    _debug_all "func : ${*}"
    local $TENANT_ID="$1"
    [[ -z $TENANT_ID ]] && _error "Missing tenant access ID" && exit 1

    # -- Get Tenant Access
    _debug "Getting tenant access"
    cf_api GET /client/v4/accounts/${TENANT_ID}/members
    if [[ $CURL_EXIT_CODE == "200" ]]; then      
        # -- Figure out how many members
        TOTAL_MEMBERS=$(echo $API_OUTPUT | jq -r '.result_info.total_count')
        if [[ $TOTAL_MEMBERS == "0" ]]; then
            _warning "No members found for $TENANT_ID"
        else
            _success "Found Members for $TENANT_ID - Total Members: $TOTAL_MEMBERS"
            echo
            # -- Go through each member and print out in numbered order
            # -- Get a list of ID's into an array
            MEMBER_IDS=($(echo $API_OUTPUT | jq -r '.result[] | "\(.id)"'))
            # -- Loop through each member and get the details
            for MEMBER_ID in "${MEMBER_IDS[@]}"; do                
                # -- Get the member details via jq
                MEMBER=$(echo $API_OUTPUT | jq -r --arg MEMBER_ID "$MEMBER_ID" '.result[] | select(.id == $MEMBER_ID)')
                _debug "member: $MEMBER"
                echo "Member ID: $MEMBER_ID"
                echo "----------------------------------------"
                # -- Output the member details each item on a new line
                echo $MEMBER | jq -r '"ID: \( .id )\nID2: \(.user.id) \nEmail: \(.user.email) \n2FA: \(.two_factor_authentication_enabled) \nStatus: \(.status) \nRole: \(.roles[].name)"'
                #echo $MEMBER #| jq -r '"STATUS\tROLE" + "\t" + .status + "\t" + .role' | column -t -s $'\t'
                echo
            done
        fi
    else
        _error "ERROR: $MESG - $API_OUTPUT"
        exit 1
    fi
}

# ===============================================
# -- _cf_tenant_access_get_member $TENANT_ID $MEMBER_ID
# -- Get a tenant access
# ===============================================
function _cf_tenant_access_get_member () {
    _debug_all "func : ${*}"
    local $TENANT_ID="$1" MEMBER_ID="$2"
    [[ -z $TENANT_ID ]] && _error "Missing tenant ID" && exit 1
    [[ -z $MEMBER_ID ]] && _error "Missing member ID" && exit 1

    # -- Get Tenant Access
    _debug "Getting tenant access"
    cf_api GET /client/v4/accounts/${TENANT_ID}/members/$MEMBER_ID
    if [[ $CURL_EXIT_CODE == "200" ]]; then
        _running2 "Member ID: $MEMBER_ID"
        echo "========================================"
        echo $API_OUTPUT | jq -r '.result | "ID: \(.user.id)\n First Name: \(.user.first_name)\n Last Name: \(.user.last_name)\n Email: \(.user.email)\n 2FA: \(.two_factor_authentication_enabled)\n Status: \(.status)"'
    else
        _error "ERROR: $MESG - $API_OUTPUT"
        exit 1
    fi
}

# ===============================================
# -- _cf_tenant_access_delete $TENANT_ID $MEMBER_ID
# -- Delete a tenant access
# ===============================================
function _cf_tenant_access_delete () {
    _debug_all "func : ${*}"
    local TENANT_ID="$1" MEMBER_ID="$2"
    [[ -z $TENANT_ID ]] && _error "Missing tenant ID" && exit 1
    [[ -z $MEMBER_ID ]] && _error "Missing member ID" && exit 1

    # -- Delete Tenant Access
    _debug "Deleting tenant access"
    cf_api DELETE /client/v4/accounts/$TENANT_ID/members/$MEMBER_ID
    if [[ $CURL_EXIT_CODE == "200" ]]; then
        _success "Deleted Tenant Access: $MEMBER_ID"
    else
        _error "ERROR: $MESG - $API_OUTPUT"
        exit 1
    fi
}

# =====================================
# -- _cf_get_member_id_from_email $TENANT_ID $EMAIL 
# -- Get member ID from email
# =====================================
function _cf_get_member_id_from_email () {
    _debug_all "func : ${*}"
    local TENANT_ID="$1" EMAIL="$2"
    [[ -z $TENANT_ID ]] && _error "Missing tenant ID" && exit 1
    [[ -z $EMAIL ]] && _error "Missing email" && exit 1

    # -- Get Tenant Access
    _debug "Getting tenant access"
    cf_api GET /client/v4/accounts/${TENANT_ID}/members
    if [[ $CURL_EXIT_CODE == "200" ]]; then
        # -- Get member ID from email
        MEMBER_ID=$(echo $API_OUTPUT | jq -r --arg EMAIL "$EMAIL" '.result[] | select(.user.email == $EMAIL) | .id')
        if [[ -z $MEMBER_ID ]]; then
            _error "No member found for $EMAIL"
            exit 1
        else
            echo $MEMBER_ID
        fi
    else
        _error "ERROR: $MESG - $API_OUTPUT"
        exit
    fi
}