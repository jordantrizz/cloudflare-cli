#!/usr/bin/env bash

# =================================================================================================
# cloudflare-cli v1.0.1
# =================================================================================================

# ===============================================
# -- Variables
# ===============================================
VERSION="$(cat "$SCRIPT_DIR"/VERSION 2>/dev/null || echo "unknown")"
DEBUG=0
DEBUG_FILE_PATH="$HOME/cloudflare-cli-debug.log"
# Clear debug log
echo "" > $DEBUG_FILE_PATH
QUIET=0
NL=$'\n'
TA=$'\t'
CF_API_ENDPOINT=https://api.cloudflare.com/client/v4
APIv4_ENDPOINT=$CF_API_ENDPOINT # Remove eventually

# ===============================================
# -- Help Files
# ===============================================
# -- HELP_VERSION
HELP_VERSION="Version: $VERSION"

# -----------------------------------------------
# -- HELP_OPTIONS
# -----------------------------------------------
HELP_OPTIONS="Options:
---------
	--details, -d          Display detailed info where possible
	--debug, -D            Display API debugging info
	--debug-curl, -DC      Display API debugging info and curl output
	--quiet, -q            Less verbose
	-y, --yes, --force     Skip confirmation prompts (e.g. when an existing record is found)
	-E <email>             Cloudflare Email
	-T <api_token>         Cloudflare API Token
	-p, --profile NAME     Use credentials profile NAME from ~/.cloudflare (or DEFAULT)
	-A, --account-id ID    Default account id for commands that create resources (e.g. bulk add zone)

Multi-Zone Options:
    -z, --zone <zone>   Specify zone (can be repeated for multiple zones)
    -f, --zones-file    Read zones from file (one per line, # comments)
    --continue-on-error Continue processing despite individual zone failures"


# -----------------------------------------------
# -- HELP_FULL
# -----------------------------------------------
HELP_FULL="Usage: cloudflare [Options] <command> <parameters>

Main Commands:
---------
    account    - Show account information
                list
                details <account_id>
                zones <account_id>
    list        - Show information about an object
                    zone <zone>
                    zones
                    settings <zone>
                    records <zone>
                    access-lists <zone>

    add         - Create Object
                    zone
                    record
                    whitelist
                    blacklist
                    challenge

    delete      - Delete Objects
                    zone
                    record
                    listing

    change      - Change Object
                    zone
                    record

    template    - Apply template to zone
                    list
                    apply <zone> <template>

    search	    - Search for object
                    zone <query> (Return one zone)
                    zones <query> (Return all zones that match)
                    record <query>

    clear       - Clear cache
                    cache <zone>
                    invalidate <url>

    invalidate  - Invalidate cache
                    <url> url to invalidate

Additional Commands:
--------------------
    profiles   - List profiles

    check       - Activate check
                    zone <zone>

    json        - Test jq_decode function
                PIPE| json <format>

    pass        - Pass through queries to CF API
                <method> <url> [parameters]
                Example: cloudflare pass GET /zones

    help        - Full help

    examples - Show Examples

Environment variables:
    CF_ACCOUNT       - email address (as -E option)
    CF_KEY           - global API key for account auth
    CF_TOKEN         - API token (as -T option)
    CF_PROFILE       - default profile name (same as --profile)

Configuration file for credentials (~/.cloudflare):
    # Default credentials
    CF_ACCOUNT=example@example.com
    CF_KEY=global-api-key
    CF_TOKEN=default-token

    # Named profiles
    CF_ACCOUNT_WORK=work@example.com
    CF_KEY_WORK=work-global-key
    CF_TOKEN_PROD=long-production-token

Examples:
    cloudflare --profile work show zones
    cloudflare --profile prod add record example.com A www 203.0.113.10

${HELP_EXAMPLES}
${HELP_VERSION}

Enter \"cloudflare help\" to list available commands."

# -----------------------------------------------
# -- HELP_CMDS
# -----------------------------------------------
HELP_CMDS="Commands:
----------
	account     list,details,zones
	list        zone, zones, settings, records, listing
	add         zone, record, whitelist, blacklist, challenge
	bulk        zone add
	delete      zone, record, listing
	change      zone, record
	clear       cache
	invalidate  url
	template    list, apply
	search      zone, record

Additional Commands:
--------------------
    check       - Activate check
    json        - Test jq_decode function
    ishex       - Check if string is hex
    pass        - Pass through queries to CF API
    help        - Full help
    examples    - Show Examples"

# -----------------------------------------------
# -- HELP_CMDS_SHORT
# -----------------------------------------------
HELP_CMDS_SHORT="Commands: list, add, bulk, delete, change, clear, check, json, help, examples"

# -----------------------------------------------
# -- HELP_EXAMPLES
# -----------------------------------------------
HELP_EXAMPLES="Examples:

$ cloudflare show settings example.net
advanced_ddos                  off
always_online                  on
automatic_https_rewrites       off
...

$ cloudflare show records example.net
www     auto CNAME     example.net.       ; proxiable,proxied #IDSTRING
@       auto A         198.51.100.1       ; proxiable,proxied #IDSTRING
*       3600 A         198.51.100.2       ;  #IDSTRING
...

Multi-Zone Examples:

# Process multiple zones specified on command line
$ cloudflare -z example.com -z example.org clear cache

# Process zones from a file
$ cloudflare -f zones.txt clear cache

# Combine both methods
$ cloudflare -z extra.com -f zones.txt clear cache

# Continue despite errors
$ cloudflare -f zones.txt --continue-on-error clear cache

Zone Creation Examples:

# Create one zone (prints assigned nameservers)
$ cloudflare add zone example.com

# Create one zone under a specific account id
$ cloudflare --account-id <account_id> add zone example.com

# Bulk create zones from file under a specific account id (one zone per line)
$ cloudflare -f zones.txt --account-id <account_id> add zone

# Alternate bulk form (account id provided after command)
$ cloudflare -f zones.txt add zone <account_id>"

HELP_BULK_ZONE_ADD="${HELP_CMDS_SHORT}

Usage: cloudflare [Options] (-f <zones-file> | -z <zone> [-z <zone> ...]) bulk zone add [account_id]

Bulk create zones under a specific account id.

Examples:
	cloudflare -f zones.txt --account-id <account_id> bulk zone add
	cloudflare -f zones.txt bulk zone add <account_id>
	cloudflare -z example.com -z example.org --account-id <account_id> bulk zone add

Notes:
	- The output includes the nameservers you must set at your registrar.
	- Use --continue-on-error to keep going after failures.

${HELP_VERSION}"

# Rebuild HELP_FULL now that HELP_EXAMPLES is defined.
# Bash expands ${HELP_EXAMPLES} at assignment time, so defining HELP_FULL earlier
# would embed an empty value.
HELP_FULL="Usage: cloudflare [Options] <command> <parameters>

Main Commands:
---------
	account    - Show account information
				list
				details <account_id>
				zones <account_id>
	list        - Show information about an object
					zone <zone>
					zones
					settings <zone>
					records <zone>
					access-lists <zone>

	add         - Create Object
					zone
					record
					whitelist
					blacklist
					challenge

	bulk        - Bulk operations
					zone add

	delete      - Delete Objects
					zone
					record
					listing

	change      - Change Object
					zone
					record

	template    - Apply template to zone
					list
					apply <zone> <template>

	search     - Search for object
					zone <query> (Return one zone)
					zones <query> (Return all zones that match)
					record <query>

	clear       - Clear cache
					cache <zone>
					invalidate <url>

	invalidate  - Invalidate cache
					<url> url to invalidate

Additional Commands:
--------------------
	profiles   - List profiles

	check       - Activate check
					zone <zone>

	json        - Test jq_decode function
				PIPE| json <format>

	pass        - Pass through queries to CF API
				<method> <url> [parameters]
				Example: cloudflare pass GET /zones

	help        - Full help

	examples - Show Examples

Environment variables:
	CF_ACCOUNT       - email address (as -E option)
	CF_KEY           - global API key for account auth
	CF_TOKEN         - API token (as -T option)
	CF_PROFILE       - default profile name (same as --profile)

Configuration file for credentials (~/.cloudflare):
	# Default credentials
	CF_ACCOUNT=example@example.com
	CF_KEY=global-api-key
	CF_TOKEN=default-token

	# Named profiles
	CF_ACCOUNT_WORK=work@example.com
	CF_KEY_WORK=work-global-key
	CF_TOKEN_PROD=long-production-token

Examples:
	cloudflare --profile work show zones
	cloudflare --profile prod add record example.com A www 203.0.113.10

${HELP_OPTIONS}

${HELP_EXAMPLES}
${HELP_VERSION}

Enter \"cloudflare help\" to list available commands."

# -----------------------------------------------
# -- HELP_ADD_ZONE
# -----------------------------------------------
HELP_ADD_ZONE="${HELP_CMDS_SHORT}

Usage: cloudflare [Options] add zone [<zone>] [account-id]

Create a Cloudflare zone.

Single-zone:
	cloudflare add zone example.com
	cloudflare add zone example.com <account_id>
	cloudflare --account-id <account_id> add zone example.com

Bulk create zones (use -z/-f):
	cloudflare -f zones.txt --account-id <account_id> add zone
	cloudflare -z example.com -z example.org --account-id <account_id> add zone
	cloudflare -f zones.txt add zone <account_id>

Notes:
	- Bulk mode uses one zone per line in zones.txt (comments with # allowed).
	- The output includes the nameservers you must set at your registrar.
	- Use --continue-on-error to keep going after failures.

${HELP_VERSION}"

# -----------------------------------------------
# -- HELP_USAGE
# -----------------------------------------------
HELP_USAGE="Usage: cloudflare [Options] <command> <parameters>

${HELP_CMDS}

${HELP_OPTIONS}

${HELP_VERSION}

Enter \"cloudflare help\" to list available commands."

# =================================================================================================
# -- Help sub commands
# =================================================================================================

# -----------------------------------------------
# -- HELP_SHOW
# -----------------------------------------------
HELP_SHOW="${HELP_CMDS_SHORT}

Usage: cloudflare show [zones|zone <zone>|settings <zone>|records <zone>|access-lists <zone>]

    Commands:
        zones            -List all zones under account.
        zone             -List basic information for <zone>.
        settings         -List settings for <zone>
        records          -List records for <zone>
        access-lists     -List access lists for <zone>
        email-routing    -List email routing for <zone>

    Options:
        <zone> domain zone to register the record in, see 'show zones' command

${HELP_VERSION}"

# -----------------------------------------------
# -- HELP_ADD_RECORD
# -----------------------------------------------
HELP_ADD_RECORD="${HELP_CMDS_SHORT}

Usage: cloudflare add record <zone> <type> <name> <content> [ttl] [prio | proxied] [service] [protocol] [weight] [port]
    <zone>      domain zone to register the record in, see 'show zones' command
    <type>      one of: A, AAAA, CNAME, MX, NS, SRV, TXT (Contain in double quotes \"\"), SPF, LOC
    <name>      subdomain name, or \"@\" to refer to the domain's root
    <content>   IP address for A, AAAA
            FQDN for CNAME, MX, NS, SRV
                    any text for TXT, spf definition text for SPF
                    coordinates for LOC (see RFC 1876 section 3)
Options
	[ttl]       Time To Live, numeric value or auto (1 = auto)
    
    = MX records:
    [prio]      required only by MX and SRV records, enter \"10\" if unsure
    
    = A or CNAME records:
    [proxied]   Proxied, true or false. For A or CNAME records only.
    
    = SRV records:
    [service]   service name, eg. \"sip\"
    [protocol]  tcp, udp, tls
    [weight]    relative weight for records with the same priority
    [port]      layer-4 port number

    -y, --yes, --force   Skip the prompt when an existing record is found.

Note: If a record with the same name and type already exists, you will be prompted
      to confirm before creating a duplicate. Use -y/--force to skip this prompt.

${HELP_VERSION}
"

# -----------------------------------------------
# -- HELP_CLEAR
# -----------------------------------------------
HELP_CLEAR="${HELP_CMDS_SHORT}

Usage: cloudflare clear cache <zone>

    Commands:
    ---------
        cache            -Clear cache for <zone>

    Options:
    --------
        <zone> domain zone to clear cache for, see 'show zones' command

${HELP_VERSION}
"

# -----------------------------------------------
# -- HELP_CHANGE
# -----------------------------------------------
HELP_CHANGE="${HELP_CMDS_SHORT}

Usage: cloudflare change

    zone <zone> <setting> <value> [<setting> <value> [ ... ]]
    record <name> [type <type> | first | oldcontent <content>] <setting> <value> [<setting> <value> [ ... ]]]

    Commands:
    ---------
    zone    - Change settings for <zone>	
        
       zone <zone> <setting> <value> [<setting> <value> [ ... ]]	
                security_level [under_attack | high | medium | low | essentially_off]
                cache_level [aggressive | basic | simplified]
                rocket_loader [on | off | manual]
                minify <any variation of css, html, js delimited by comma>
                development_mode [on | off]
                mirage [on | off]
                ipv6 [on | off]                

    record  - Change settings for <record>
            
            You must enter \"type\" and the record type (A, MX, ...) when the record name is ambiguous, 
            or enter \"first\" to modify the first matching record in the zone,
            or enter \"oldcontent\" and the exact content of the record you want to modify if there are more records with the same name and type.
        
        record <name> [type <type> | first | oldcontent <content>] <setting> <value> [<setting> <value> [ ... ]]
                newname        Rename the record
                newtype        Change type
                content        See description in 'add record' command
                ttl            See description in 'add record' command
                proxied        Turn CF proxying on/off

${HELP_VERSION}
"

HELP_TEMPLATE="${HELP_CMDS_SHORT}

Usage: cloudflare template [list|apply <template> -v <variable1=value1> -v <variable2=value2> ...]

	Commands:
	---------
	list    - List available templates
	apply   - Apply template

	Options:
	--------
	<template> template to apply, see 'template list' command
	-v        variable to replace in template, see 'apply' command -v <variable1=value1> -v <variable2=value2> ...

	Notes:
	------
	When you create your template, you can use any variables.
	For instance, no zone is specified on the command line, it needs to be a variable in the template and you need to specify it when applying the template.
	eg - cloudflare template apply mytemplate --variableDOMAIN_NAME=example.net
"

# -----------------------------------------------
# -- help
# -----------------------------------------------
function help () {
cmd1=$1
shift
	case "$cmd1" in
		# -- usage
		usage|USAGE)
		echo "$HELP_USAGE"
		;;
		# -- help
		help|HELP|full)
		echo "$HELP_FULL"
		;;

		# -- add
		add)
			cmd2="$1"					
			case "$cmd2" in
				zone)
				echo "$HELP_ADD_ZONE"
				;;
				record)
				
				echo "$HELP_ADD_RECORD"
				;;
				*)
				echo "$HELP_CMDS"
			esac
		;;
		bulk)
			cmd2="$1"
			shift || true
			case "$cmd2" in
				zone|zones)
					cmd3="$1"
					case "$cmd3" in
						add)
						echo "$HELP_BULK_ZONE_ADD"
						;;
						*)
						echo "$HELP_BULK_ZONE_ADD"
						;;
					esac
					;;
				*)
				echo "$HELP_BULK_ZONE_ADD"
				;;
			esac
		;;
		clear)
			cmd2="$1"
			case "$cmd2" in
				cache)
				echo "$HELP_CLEAR"
				;;
				*)
				echo "$HELP_CLEAR"
				;;
			esac
		;;
		show)
			echo "$HELP_SHOW"
		;;
		change)
			echo "$HELP_CHANGE"
		;;
		template)
			echo "$HELP_TEMPLATE"
		;;
		*)
		echo "$HELP_USAGE"
		;;
esac
}

# =================================================================================================
# -- Functions
# =================================================================================================

# -----------------------------------------------
# -- jq_decode - jq-based JSON decoder
# -- Accepts one or more jq filters as arguments.
# -----------------------------------------------
jq_decode() {
	_debug "jq_decode: ${*}"
	local input
	input=$(cat)

	# -- Check for old-style error format
	if echo "$input" | jq -e '.result == "error"' >/dev/null 2>&1; then
		echo "$input" | jq -r '.msg // "Unknown error"' 2>/dev/null
		return 2
	fi

	# -- Check for Cloudflare API error
	if echo "$input" | jq -e '.success == false' >/dev/null 2>&1; then
		echo "$input" | jq -r '.errors[]? | "E\(.code): \(.message)"' 2>/dev/null
		return 2
	fi

	# -- Pagination check
	local page total_pages
	page=$(echo "$input" | jq -r '.result_info.page // 0' 2>/dev/null)
	total_pages=$(echo "$input" | jq -r '.result_info.total_pages // 0' 2>/dev/null)
	if [[ "$page" -gt 0 && "$page" -lt "$total_pages" ]] 2>/dev/null; then
		echo "!has_more"
	fi

	if [[ $# -eq 0 ]]; then
		echo "$input" | jq -r 'if type == "array" then .[] | tostring elif type == "object" then tostring else tostring end' 2>/dev/null
		return 0
	fi

	local filter
	for filter in "$@"; do
		echo "$input" | jq -r "$filter" 2>/dev/null || return 1
	done
}

# -----------------------------------------------
# -- _die
# -----------------------------------------------
function _die () {
	if [ -n "$1" ];	then
		_error "$1"
	fi
	exit "${2:-1}"
}

# -----------------------------------------------
# -- is_hex
# -----------------------------------------------
is_hex() { expr "$1" : '[0-9a-fA-F]\+$' >/dev/null; }

# -----------------------------------------------
# -- _escape_string
# -- Escape json with slashes for curl
# -----------------------------------------------
function _escape_string () {
	echo "$1" | sed 's/"/\\"/g'
}

function _cf_normalize_record_ttl () {
	local ttl="$1"
	if [[ -z "$ttl" || "$ttl" == "auto" ]]; then
		echo 1
		return 0
	fi
	if [[ "$ttl" =~ ^[0-9]+$ ]]; then
		echo "$ttl"
		return 0
	fi
	return 1
}

function _cf_is_boolean () {
	local value="${1,,}"
	[[ "$value" == "true" || "$value" == "false" ]]
}

function _cf_validate_record_priority () {
	local prio="$1"
	[[ -z "$prio" || "$prio" =~ ^[0-9]+$ ]]
}

# ==============================================================================================
# -- Check Functions
# ==============================================================================================

# ===============================================
# -- _check_quiet
# ===============================================
function _check_quiet () {
    if [[ $QUIET == "1" ]]; then
        echo -e "${CYAN}** DEBUG: Quiet is on${NC}"
    fi
}

# ==============================================================================================
# -- Core Functions
# ==============================================================================================

# ===============================================
# -- call_cf_v4 - Main call to cloudflare using curl
# --
# -- Invocation: call_cf_v4 <METHOD> <URL_PATH> [PARAMETERS] [-- JQ-FILTERS]
# --
# -- Example: call_cf_v4 GET /zones name="$zone" -- '.result[] | .id'
# ===============================================
function call_cf_v4 () {
	_debug "function:${FUNCNAME[0]} - ${*}"
	local METHOD="${1^^}"
	shift	
	local URL_PATH="$1"
	shift

	local FORMTYPE
	local QUERY_STRING CURL_OUTPUT PROCESSED_OUTPUT CURL_EXIT_CODE RESULT_PAGE RESULTS_PER_PAGE CURL_OUTPUT_GLOBAL
	local DEBUG_CURL
	[[ -n $OVERRIDE_RESULT_PAGE ]] && RESULT_PAGE=$OVERRIDE_RESULT_PAGE || RESULT_PAGE=1
	[[ -n $OVERRIDE_RESULTS_PER_PAGE ]] && RESULTS_PER_PAGE=$OVERRIDE_RESULTS_PER_PAGE || RESULTS_PER_PAGE=50
	declare -a CURL_OPTS
	CURL_OPTS=()	

	# -- Ensure we got all variables
	_debug "func call_cf-v4 variables: METHOD:$METHOD URL_PATH:$URL_PATH Remaing ARGS:${*}"

	# -- Check if PARAMETERS is a JSON string
	if [ "$METHOD" != POST -o "${1:0:1}" = '{' ]; then
		_debug "Detected JSON / GET - Setting Content-Type to application/json and FORMTYPE to data"
		CURL_OPTS+=("-H 'Content-Type: application/json'")
		FORMTYPE=data
	else
		_debug "Setting FORMTYPE to form"
		CURL_OPTS+=("-H 'Content-Type: multipart/form-data'")
		FORMTYPE=form
	fi

	# -- set method to --get if GET
    if [ "$METHOD" = GET ]
    then
        CURL_OPTS+=("--get")
    fi


	# -- Process parameters
	while [ -n "$1" ]; do
		if [ ."$1" = .-- ]; then
			shift
			_debug "Parameters: ${*}"
			break
		else
			CURL_OPTS+=("--$FORMTYPE '"$1"'")
		fi
		shift
	done

	# -- Check for zero parameters
	if [ -z "$1" ]; then
		set -- 'if .success then "Successfully Completed!" else "failed" end'
	fi

	# -- Testing check
	if [[ $TEST == "true" ]]; then
		_debug "TEST: curl -sS -H \"X-Auth-Email: $CF_ACCOUNT\" -H \"X-Auth-Key: [MASKED]\" -X $METHOD ${CURL_OPTS[*]} $APIv4_ENDPOINT$URL_PATH"
		echo "TEST: curl -sS -H \"X-Auth-Email: $CF_ACCOUNT\" -H \"X-Auth-Key: [MASKED]\" -X $METHOD ${CURL_OPTS[*]} $APIv4_ENDPOINT$URL_PATH"
		CURL_OUTPUT_GLOBAL='{"success": true,"message": "Operation completed successfully"}'
		return "$CURL_EXIT_CODE"
	else
		# -- Go through pages of results
		while true; do
			# Set starting page and per page options
			QUERY_STRING="?page=$RESULT_PAGE&per_page=$RESULTS_PER_PAGE"

			# Run curl command			
			if [[ $DEBUG_CURL == "1" ]]; then
				set -x
			fi				
			if [[ -n $API_TOKEN ]]; then
				CURL_CMD="curl -sS \"${APIv4_ENDPOINT}${URL_PATH}${QUERY_STRING}\" -H \"Authorization: Bearer ${API_TOKEN}\" -X \"$METHOD\""
			elif [[ -n $API_ACCOUNT && -n $API_APIKEY ]]; then
				CURL_CMD="curl -sS \"${APIv4_ENDPOINT}${URL_PATH}${QUERY_STRING}\" -H \"X-Auth-Email: ${API_ACCOUNT}\" -H \"X-Auth-Key: ${API_APIKEY}\" -X \"$METHOD\""
			else
				_error "No authentication credentials found"
				return 1
			fi
				# Grab each CURL_OPTS and add to CURL_CMD
				for i in "${CURL_OPTS[@]}"; do
					CURL_CMD+=" $i"
				done
			# Create masked version for debugging (hide sensitive keys)
			CURL_CMD_MASKED="$CURL_CMD"
			CURL_CMD_MASKED="${CURL_CMD_MASKED//${API_APIKEY}/[MASKED]}"
			CURL_CMD_MASKED="${CURL_CMD_MASKED//${API_TOKEN}/[MASKED]}"
			_debug "CURL_CMD: $CURL_CMD_MASKED"
			CURL_OUTPUT=$(eval $CURL_CMD)		
			CURL_EXIT_CODE=$?
			_debug "CURL_OUTPUT: $CURL_OUTPUT" 2
			_debug "CURL_EXIT_CODE: $CURL_EXIT_CODE"

			# -- Check if curl failed
			if [[ $CURL_EXIT_CODE -gt 0 ]]; then				
				_error "curl failed - OUTPUT: $CURL_OUTPUT EXITCODE: $CURL_EXIT_CODE"
				echo "$CURL_OUTPUT"				
				exit 1
			fi

			# -- Check if Cloudflare returned an error
			if [[ $(grep '^{"success":false' <<<"$CURL_OUTPUT") ]]; then
				_error "Cloudflare returned an error"
				_error "$CURL_OUTPUT"
				return 1
			fi

			_debug "json-filter: ${*}"
			PROCESSED_OUTPUT=$(echo "$CURL_OUTPUT" | jq_decode "$@" 2>/dev/null)
			local JQ_DECODE_EXIT=$?
			if [[ $JQ_DECODE_EXIT -eq 2 ]]; then
				_debug "API returned an error (jq_decode exit 2)"
				return 1
			fi
			_debug "PROCESSED_OUTPUT: $PROCESSED_OUTPUT"
            _debug "\$@ == $@"
			sed -e '/^!/d' <<<"$PROCESSED_OUTPUT"

			if grep -qE '^!has_more' <<<"$PROCESSED_OUTPUT"; then				
				_debug "More results available"
				(( RESULT_PAGE++ )) || true				
			else
				_debug "No more results"
				break
			fi
		done
		CURL_OUTPUT_GLOBAL="$PROCESSED_OUTPUT"
		return $CURL_EXIT_CODE
	fi
}

# ==============================================================================================
# -- Zone helpers (cloudflare.sh keeps logic thin)
# ==============================================================================================

# -----------------------------------------------
# -- _cf_zone_create_v4 <zone_name> [account_id]
# -- Create a zone via the v4 API and print a single tab-separated line:
# --   <zone>\t<zone_id>\t<name_servers>
# -- Returns non-zero on failure.
# -----------------------------------------------
function _cf_zone_create_v4 () {
	local DOMAIN="$1"
	local ACCOUNT_ID="$2"
	local JSON
	local CREATE_ZONE_OUTPUT_CMD
	local ZONE_ID
	local NAME_SERVERS

	[[ -z "$DOMAIN" ]] && _error "Missing zone name" && return 1

	if [[ -n "$ACCOUNT_ID" ]]; then
		JSON="{\"account\":{\"id\":\"$ACCOUNT_ID\"},\"name\":\"$DOMAIN\",\"jump_start\":true}"
	else
		JSON="{\"name\":\"$DOMAIN\",\"jump_start\":true}"
	fi

	CREATE_ZONE_OUTPUT_CMD=$(call_cf_v4 POST /zones "$JSON" -- '.result | [.name, .status, .type, .id, (.name_servers // [] | join(","))] | @tsv') || return 1

	ZONE_ID=$(echo "$CREATE_ZONE_OUTPUT_CMD" | awk -F'\t' '{print $4}')
	NAME_SERVERS=$(echo "$CREATE_ZONE_OUTPUT_CMD" | awk -F'\t' '{print $5}')

	echo -e "${DOMAIN}\t${ZONE_ID}\t${NAME_SERVERS}"
	return 0
}

# ===============================================
# -- findout_record
#
# Arguments:
#   $1 - record name (eg: sub.example.com)
#  $2 - record type, optional (eg: CNAME)
#  $3 - 0/1, stop searching at first match, optional
#  $4 - record content to match to
#  writes global variables: zone, zone_id, record_id, record_type, record_ttl, record_content
#
# Return code:
#  0 - zone and record are found and stored in zone, zone_id, record_id, record_type, record_ttl, record_content
#  2 - no suitable zone found
#  3 - no matching record found
#  4 - more than 1 matching record found
# ===============================================
findout_record() {
	local record_name=${1,,}
	declare -g record_type=${2^^}
	local first_match=$3
	local record_oldcontent=$4
	local try_zone
	local zid
	local test_record
	declare -g zone_id=''
	declare -g zone=''
	declare -g record_id=''
	declare -g record_ttl=''
	declare -g record_content=''
	echo -n "Searching zone ... "

	try_zone="$record_name"
	while [[ "$try_zone" == *.* ]]; do
		zid=$(_cf_zone_id "$try_zone")
		if [[ -n "$zid" && "$zid" != "null" ]]; then
			zone="$try_zone"
			zone_id="$zid"
			break
		fi
		try_zone=${try_zone#*.}
	done
	[ -z "$zone_id" ] && { echo >&2; return 2; }
	echo -n "$zone, searching record ... "

	rec_found=0
	oldIFS=$IFS
	IFS=$NL
	for test_record in $(call_cf_v4 GET /zones/${zone_id}/dns_records -- '.result[] | [.name, .type, .id, .ttl, .content] | @tsv'); do
		IFS=$oldIFS
		# shellcheck disable=SC2086
		set -- $test_record
		test_record_name=$1
		shift

		if [ "$test_record_name" = "$record_name" ]
		then
			test_record_type=$1
			shift
			test_record_id=$1
			shift
			test_record_ttl=$1
			shift
			test_record_content=$*

			if [ \( -z "$record_type" -o "$test_record_type" = "$record_type" \) -a \( -z "$record_oldcontent" -o "$test_record_content" = "$record_oldcontent" \) ]
			then				
				(( rec_found++ )) || true
				[ $rec_found -gt 1 ] && { echo >&2; return 4; }

				record_type=$test_record_type
				record_id=$test_record_id
				record_ttl=$test_record_ttl
				record_content=$test_record_content
				if [ "$first_match" = 1 ]
				then
					# accept first matching record
					break
				fi
			fi
		fi
		IFS=$NL
	done
	IFS=$oldIFS

	echo "$record_id" >&2
	[ -z "$record_id" ] && return 3

	return 0
}

# ===============================================
# -- _cf_check_record_exists $ZONE_ID $NAME $TYPE
# -- Check if a DNS record with the given name and type already exists in the zone.
# -- Outputs existing records to stdout when found.
# -- Returns: 0 if one or more records exist, 1 if none found
# -- Arguments: $1 - zone_id, $2 - record name, $3 - record type
# ===============================================
function _cf_check_record_exists () {
	local ZONE_ID="$1"
	local RECORD_NAME="$2"
	local RECORD_TYPE="$3"

	[[ -z "$ZONE_ID" || -z "$RECORD_NAME" || -z "$RECORD_TYPE" ]] && { _error "_cf_check_record_exists: missing arguments"; return 1; }

	_debug "Checking for existing ${RECORD_TYPE} record named ${RECORD_NAME} in zone ${ZONE_ID}"
	cf_api GET "/client/v4/zones/${ZONE_ID}/dns_records?name=${RECORD_NAME}&type=${RECORD_TYPE}"

	if [[ $CURL_EXIT_CODE != "200" ]]; then
		_debug "API call failed with exit code: $CURL_EXIT_CODE"
		return 1
	fi

	local MATCH_COUNT
	MATCH_COUNT=$(echo "$API_OUTPUT" | jq '.result | length')

	if [[ $MATCH_COUNT -eq 0 ]]; then
		_debug "No existing ${RECORD_TYPE} record found for ${RECORD_NAME}"
		return 1
	fi

	_warning "Found ${MATCH_COUNT} existing ${RECORD_TYPE} record(s) for ${RECORD_NAME}:"
	printf "%-6s %-45s %-45s %-8s %-8s %-36s\n" "Type" "Name" "Content" "TTL" "Proxied" "Record ID"
	printf "%s\n" "$(printf '%0.s-' {1..155})"
	echo "$API_OUTPUT" | jq -r '.result[] | "\(.type)\t\(.name)\t\(.content)\t\(.ttl)\t\(.proxied)\t\(.id)"' | while IFS=$'\t' read -r TYPE NAME CONTENT TTL PROXIED RID; do
		[[ "$TTL" == "1" ]] && TTL="auto"
		printf "%-6s %-45s %-45s %-8s %-8s %-36s\n" "$TYPE" "$NAME" "${CONTENT:0:45}" "$TTL" "$PROXIED" "$RID"
	done

	return 0
}



# ===============================================
# -- zone_search - search for zone based on query
# --
# -- Arguments:	$1 - query
# ===============================================
function zone_search () {
	_debug "function:${FUNCNAME[0]} - ${*}"
	local QUERY="$1" SUCCESS="0" ZONES_FOUND="" ZONE_IDS_FOUND=""

	# Get a list of all zones using jq for parsing
	_debug "Calling API: GET /zones"
	
	# Build curl command to get zones
	local QUERY_STRING="?page=1&per_page=100"
	local CURL_OUTPUT
	
	if [[ -n $API_TOKEN ]]; then
		CURL_OUTPUT=$(curl -sS "${APIv4_ENDPOINT}/zones${QUERY_STRING}" -H "Authorization: Bearer ${API_TOKEN}" -X GET)
	elif [[ -n $API_ACCOUNT && -n $API_APIKEY ]]; then
		CURL_OUTPUT=$(curl -sS "${APIv4_ENDPOINT}/zones${QUERY_STRING}" -H "X-Auth-Email: ${API_ACCOUNT}" -H "X-Auth-Key: ${API_APIKEY}" -X GET)
	else
		_error "No authentication credentials found"
		return 1
	fi
	
	_debug "Raw JSON received, length: ${#CURL_OUTPUT}"
	
	# Use jq to extract zone id and name as TSV (tab-separated values)
	# This outputs: id<TAB>name for each zone
	local JQ_OUTPUT
	JQ_OUTPUT=$(echo "$CURL_OUTPUT" | jq -r '.result[] | "\(.id)\t\(.name)"' 2>/dev/null)
	_debug "JQ output received, length: ${#JQ_OUTPUT}"
	
	# Count zones from API
	local zone_count=0
	zone_count=$(echo "$JQ_OUTPUT" | grep -c . 2>/dev/null || echo 0)
	_debug "Total zones returned from API: $zone_count"
	
	# Parse TSV output and search for matching zones
	_debug "Searching for zones containing: $QUERY"
	
	while IFS=$'\t' read -r zone_id zone_name; do
		[[ -z "$zone_id" ]] && continue
		_debug "Processing - zone_id: '$zone_id', zone_name: '$zone_name'"
		if [[ -n "$zone_name" ]] && [[ $zone_name == *"$QUERY"* ]]; then
			_debug "  Match found!"
			SUCCESS="1"
			ZONES_FOUND+="$zone_name\n"
			ZONE_IDS_FOUND+="$zone_id\n"			
		fi
	done <<< "$JQ_OUTPUT"

	_debug "Final SUCCESS: $SUCCESS"
	local found_count=0
	found_count=$(echo -e "$ZONES_FOUND" | grep -c . 2>/dev/null || echo 0)
	_debug "Zones found count: $found_count"
	
	if [[ $SUCCESS == "1" ]]; then
		_success "Found the following zones:"
		printf "%-40s | %-40s\n" "DomainID" "Domain"
		printf "%s-+-%s\n" "$(printf '%0.s-' {1..40})" "$(printf '%0.s-' {1..40})"
		paste <(echo -e "$ZONE_IDS_FOUND") <(echo -e "$ZONES_FOUND") | column -t -s $'\t' | awk '{printf "%-40s | %-40s\n", $1, $2}'
	else
		_error "Zone not found - $QUERY"
	fi
}
