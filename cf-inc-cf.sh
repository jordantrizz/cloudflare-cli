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
    --details, -d       Display detailed info where possible
    --debug, -D         Display API debugging info
    --debug-curl, -DC   Display API debugging info and curl output
    --quiet, -q         Less verbose
    -E <email>          Cloudflare Email
    -T <api_token>      Cloudflare API Token
    -p, --profile NAME  Use credentials profile NAME from ~/.cloudflare (or DEFAULT)

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

    json        - Test json_decode function
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
    delete      zone, record, listing
    change      zone, record
    clear       cache
    invalidate  url
    template    list, apply
    search      zone, record

Additional Commands:
--------------------
    check       - Activate check
    json        - Test json_decode function
    ishex       - Check if string is hex
    pass        - Pass through queries to CF API
    help        - Full help
    examples    - Show Examples"

# -----------------------------------------------
# -- HELP_CMDS_SHORT
# -----------------------------------------------
HELP_CMDS_SHORT="Commands: list, add, delete, change, clear, check, json, help, examples"

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
$ cloudflare -f zones.txt --continue-on-error clear cache"

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
    [ttl]       Time To Live, 1 = auto
    
    = MX records:
    [prio]      required only by MX and SRV records, enter \"10\" if unsure
    
    = A or CNAME records:
    [proxied]   Proxied, true or false. For A or CNAME records only.
    
    = SRV records:
    [service]   service name, eg. \"sip\"
    [protocol]  tcp, udp, tls
    [weight]    relative weight for records with the same priority
    [port]      layer-4 port number

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
				record)
				
				echo "$HELP_ADD_RECORD"
				;;
				*)
				echo "$HELP_CMDS"
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
# -- json_decode - php code to decode json
# -----------------------------------------------
json_decode() {
	# Parameter Synatx
	#
	# .key1.key11.key111
	#    dive into array
	# %format
	#    set output formatting
	# table
	#    display as a table
	# ,mod1,mod2,...
	#    see modifiers
	# &mod1&mod2&...
	#    modifiers per line
	#
	#
	# Modifier Synatx
	#
	# ?modCondition?modTrue?modFalse
	#    tenary expression
	# ||key1||key2||key3||...
	#    find a true-ish value
	# key.subkey.subsubkey
	#    dive into array
	# !key
	#    implode non-zero elements of key
	# !!key1 key2 key3 ...
	#    implode values of keys if they are not false
	# <code
	#    evaluate code, keyN are in $keyN
	# "string"
	#    literal
	# @suffixKey@stringKey
	#    trim suffix from string
	# key
	#    represent the value
	_debug "json_decode: ${*}"

	# shellcheck disable=SC2016
	php -d "error_reporting=E_ALL & ~E_WARNING" -r '
		function notzero($e)
		{
			return $e!=0;
		}
		function repr_array($a, $brackets=false)
		{
			if(is_array($a))
			{
				$o = array();
				foreach($a as $k => $v)
				{
					$o[] = (is_int($k) ? "" : "$k=") . repr_array($v, true);
				}
				if(count($o) > 1 and $brackets)
					return "[" . implode(",", $o) . "]";
				else
					return implode(",", $o);
			}
			else
				return $a;
		}
		function pfmt($fmt, &$array, $care_null=1)
		{
			if(preg_match("/^\?(.*?)\?(.*?)\?(.*)/", $fmt, $grp))
			{
				$out = pfmt($grp[1], $array, 0) ? pfmt($grp[2], $array) : pfmt($grp[3], $array);
			}
			elseif(preg_match("/^!!(.*)/", $fmt, $grp))
			{
				$out = implode(",", array_filter(preg_split("/\s+/", $grp[1]), function($k) use($array){ return !!$array[$k]; }));
			}
			elseif(preg_match("/^!(.*)/", $fmt, $grp))
			{
				$out = implode(",", array_keys(array_filter($array[$grp[1]], "notzero")));
			}
			elseif(preg_match("/^<(.*)/", $fmt, $grp))
			{
				$code = $grp[1];
				extract($array, EXTR_SKIP);
				$out = eval("return $code;");
			}
			elseif(preg_match("/^\x22(.*?)\x22/", $fmt, $grp))
			{
				$out = $grp[1];
			}
			elseif(preg_match("/^@(.*?)@(.*)/", $fmt, $grp))
			{
				$out = substr($array[$grp[2]], 0, -strlen(".".$array[$grp[1]]));
				if($out == "") $out = "@";
			}
			elseif(preg_match("/^\|\|/", $fmt))
			{
				while(preg_match("/^\|\|(.*?)(\|\|.*|$)/", $fmt, $grp))
				{
					if(pfmt($grp[1], $array, 0) != false or !preg_match("/^\|\|/", $grp[2]))
					{
						$out = pfmt($grp[1], $array, $care_null);
						break;
					}
					$fmt = $grp[2];
				}
			}
			elseif(preg_match("/(.+?)\.(.+)/", $fmt, $grp))
			{
				if(is_array(@$array[$grp[1]]))
					$out = pfmt($grp[2], $array[$grp[1]], $care_null);
				else
					$out = NULL;
			}
			else
			{
				/* Fix Cludflare´s DNS notation.
				   We must use FQDN with the trailing dot if no $ORIGIN declared. */
				if(in_array(@$array["type"], explode(",", "CNAME,MX,NS,SRV")) and isset($array["content"]) and substr($array["content"], -1) != ".")
				{
					$array["content"] .= ".";
				}
				if(is_array(@$array[$fmt]))
				{
					$out = repr_array($array[$fmt]);
				}
				else
				{
					$out = $care_null ? (array_key_exists($fmt, $array) ? (isset($array[$fmt]) ? $array[$fmt] : "NULL" ) : "NA") : @$array[$fmt];
				}
			}
			return $out;
		}
		
		$data0 = json_decode(file_get_contents("php://stdin"), true);
		if('$DEBUG') file_put_contents("php://stderr", var_export($data0, 1));
		if(@$data0["result"] == "error")
		{
			echo $data0["msg"] . "\n";
			exit(2);
		}
		if(array_key_exists("success", $data0) and !$data0["success"])
		{
			function prnt_error($e)
			{
				printf("E%s: %s\n", $e["code"], $e["message"]);
				foreach((array)@$e["error_chain"] as $e) prnt_error($e);
			}
			foreach($data0["errors"] as $e) prnt_error($e);
			exit(2);
		}
		
		if(isset($data0["result_info"]["page"]) and $data0["result_info"]["page"] < $data0["result_info"]["total_pages"])
		{
			echo "!has_more\n";
		}
		
		array_shift($argv);
		$data = $data0;
		foreach($argv as $param)
		{
			if($param == "")
			{
				continue;
			}
			if(substr($param, 0, 1) == ".")
			{
				$data = $data0;
				foreach(explode(".", $param) as $p)
				{
					if($p != "")
					{
						if(array_key_exists($p, $data))
						{
							if($p == "objs" and @$data["has_more"])
							{
								echo "!has_more\n";
								echo "!count=", $data["count"], "\n";
							}
							$data = $data[$p];
						}
						else
						{
							$data = array();
							break;
						}
					}
				}
			}
			if(substr($param, 0, 1) == "%")
			{
				$outfmt = substr($param, 1);
			}
			if($param == "table")
			{
				ksort($data);
				$maxlength = 0;
				foreach($data as $key=>$elem)
				{
					if(strlen($key) > $maxlength)
					{
						$maxlength = strlen($key);
					}
				}
				foreach($data as $key=>$elem)
				{
					printf("%-".$maxlength."s\t%s\n", $key, (string)$elem);
				}
			}
			if(substr($param, 0, 1) == ",")
			{
				foreach($data as $key=>$elem)
				{
					$out = array();
					foreach(preg_split("/(?<!,),(?!,)/", $param) as $p)
					{
						$p = str_replace(",,", ",", $p);
						if($p != "")
						{
							$out[] = pfmt($p, $elem);
						}
					}
					if(isset($outfmt))
					{
						vprintf($outfmt, $out);
					}
					else
					{
						echo implode("\t", $out), "\n";
					}
				}
			}
			if(substr($param, 0, 1) == "&")
			{
				foreach(explode("&", $param) as $p)
				{
					if($p!="")
					{
						echo pfmt($p, $data), "\n";
					}
				}
			}
		}
	' "$@"
}

# ==============================================================================================
# -- General Functions
# ==============================================================================================


# -----------------------------------------------
# -- jq_decode - jq code to decode json
# -----------------------------------------------
# TODO - Add jq_decode function that utilizes jq versus PHP

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
# -- Invocation: call_cf_v4 <METHOD> <URL_PATH> [PARAMETERS] [-- JSON-DECODER-ARGS]
# --
# -- Example: call_cf_v4 GET /zones name="$zone" -- .result ,id
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
		set -- '&?success?"Successfully Completed!"?"failed"'
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
			# TODO: Replace json_decode with jq for better reliability and performance
			# See: https://github.com/cloudflare/cloudflare-cli/issues/XXX
			PROCESSED_OUTPUT=$(echo "$CURL_OUTPUT" | json_decode "$@" 2>/dev/null)
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
	local zname_zid
	local zid
	local test_record
	declare -g zone_id=''
	declare -g zone=''
	declare -g record_id=''
	declare -g record_ttl=''
	declare -g record_content=''
	echo -n "Searching zone ... "

	for zname_zid in $(call_cf_v4 GET /zones -- .result %"%s:%s$NL" ,name,id);	do
		zone=${zname_zid%%:*}
		zone=${zone,,}
		zid=${zname_zid##*:}
		if [[ "$record_name" =~ ^((.*)\.|)$zone$ ]]; then
			# TODO why is subdomain never used?
			subdomain=${BASH_REMATCH[2]}
			zone_id=$zid
			break
		fi
	done
	[ -z "$zone_id" ] && { echo >&2; return 2; }
	echo -n "$zone, searching record ... "

	rec_found=0
	oldIFS=$IFS
	IFS=$NL
	for test_record in $(call_cf_v4 GET /zones/${zone_id}/dns_records -- .result ,name,type,id,ttl,content); do
		IFS=$oldIFS
		set -- "$test_record"
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
# -- zone_search - search for zone based on query
# --
# -- Arguments:	$1 - query
# ===============================================
function zone_search () {
	_debug "function:${FUNCNAME[0]} - ${*}"
	local QUERY="$1" SUCCESS="0" ZONES_FOUND="" ZONE_IDS_FOUND=""

	# Get a list of all zones using jq for parsing
	_debug "Calling API: GET /zones"
	
	# Build curl command to get zones - bypass json_decode
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