#!/usr/bin/env bash

# =================================================================================================
# cloudflare-cli v1.0.1
# =================================================================================================

# ===============================================
# -- Variables
# ===============================================
VERSION=1.1.2-alpha
DEBUG=0
details=0
QUIET=0
NL=$'\n'
TA=$'\t'
CF_API_ENDPOINT=https://api.cloudflare.com/client/v4
APIv4_ENDPOINT=$CF_API_ENDPOINT # Remove eventually

# -- Colors
RED="\e[31m"
GREEN="\e[32m"
CYAN="\e[36m"
BLUEBG="\e[44m"
YELLOWBG="\e[43m"
DARKGREYBG="\e[100m"
DARKGRAYFG="\e[90m"
ECOL="\e[0m"

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
   -T <api_token>      Cloudflare API Token"

# -----------------------------------------------
# -- HELP_FULL
# -----------------------------------------------
HELP_FULL="Usage: cloudflare [Options] <command> <parameters>

Commands:
---------
   list     - Show information about an object
            zone <zone>
            zones
            settings <zone>
            records <zone>
            access-lists <zone>

    add      - Create Object
            zone
            record
            whitelist
            blacklist
            challenge

    delete   - Delete Objects
            zone
            record
            listing

    change   - Change Object
            zone
            record

    clear       - Clear cache
                cache <zone>
                invalidate <url>

	invalidate  - Invalidate cache
	            <url> url to invalidate
	
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
	CF_ACCOUNT  -  email address (as -E option)
	CF_TOKEN    -  API token (as -T option)

Configuration file for credentials:
	Create a file in \$HOME/.cloudflare with both CF_ACCOUNT and CF_TOKEN defined.

	CF_ACCOUNT=example@example.com
	CF_TOKEN=<token>

${HELP_EXAMPLES}

${HELP_VERSION}

Enter \"cloudflare help\" to list available commands."

# -----------------------------------------------
# -- HELP_CMDS
# -----------------------------------------------
HELP_CMDS="Commands:
----------
    list        zone, zones, settings, records, listing
    add         zone, record, whitelist, blacklist, challenge
    delete      zone, record, listing
    change      zone, record
    clear       cache
    check
    json
	pass
    help
    examples"

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

$ cloudflare show records example.net
www     auto CNAME     example.net.       ; proxiable,proxied #IDSTRING
@       auto A         198.51.100.1       ; proxiable,proxied #IDSTRING
*       3600 A         198.51.100.2       ;  #IDSTRING
..."

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
function json_decode () {
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
	
	# shellcheck disable=SC2016
	php -r '
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
# -- Messaging Functions
# -----------------------------------------------
_error () { echo -e "${RED}** ERROR ** - $1 ${ECOL}"; }
_success () { echo -e "${GREEN}** SUCCESS ** - ${*} ${ECOL}"; }
_running () { echo -e "${BLUEBG}${*}${ECOL}"; }
_running2 () { echo -e "${DARKGRAYFG}${*}${ECOL}"; }
_creating () {  echo -e "${DARKGREYBG}${*}${ECOL}"; }
_separator () {  echo -e "${YELLOWBG}****************${ECOL}"; }

# -----------------------------------------------
# -- debug - ( $MESSAGE, $LEVEL)
# -----------------------------------------------
function _debug () {
	local DEBUG_MSG
	if [ "$DEBUG" = "1" ]; then
		if [[ $DEBUG_CURL_OUTPUT = "1" ]]; then
			DEBUG_MSG+="CURL_OUTPUT: $CURL_OUTPUT_GLOBAL"
		fi
		for arg in "$@"; do
			if [[ "$(declare -p "$arg" 2>/dev/null)" =~ "declare -a" ]]; then
				DEBUG_MSG+="Array contents:"
				for item in "${arg[@]}"; do
				DEBUG_MSG+="${item}"
				done
			else
				DEBUG_MSG+="${arg}"
			fi
		done
		echo -e "${CYAN}** DEBUG: ${DEBUG_MSG}${ECOL}" >&2
	fi
}

# -----------------------------------------------
# -- debug_all
# -----------------------------------------------
function _debug_all () {
	_debug "DEBUG_ALL: ${*}"
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
# -- check_bash - check version of bash
# -----------------------------------------------
function check_bash () {
	# - Check bash version and _die if not at least 4.0
	if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
		_die "Sorry, you need at least bash 4.0 to run this script." 1
	fi
}

# -----------------------------------------------
# -- is_hex
# -----------------------------------------------
is_hex() { expr "$1" : '[0-9a-fA-F]\+$' >/dev/null; }


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
	_debug_all "call_cf_v4: ${*} EOF"
	local METHOD="${1^^}"
	shift	
	local URL_PATH="$1"
	shift

	local FORMTYPE
	local QUERY_STRING
	local RESULT_PAGE=1 RESULTS_PER_PAGE=50
	local CURL_EXIT_CODE CURL_OUTPUT 
	declare -a CURL_OPTS
	CURL_OPTS=()	

	# -- Ensure we got all variables
	_debug "func call_cf-v4 variables: METHOD:$METHOD URL_PATH:$URL_PATH Remaing ARGS:${*}"

	# -- Check if PARAMETERS is a JSON string
	if [ "$METHOD" != POST -o "${1:0:1}" = '{' ]; then
		_debug "Detected JSON / GET - Setting Content-Type to application/json and FORMTYPE to data"
		CURL_OPTS+=(-H "Content-Type: application/json")
		FORMTYPE=data
	else
		_debug "Setting FORMTYPE to form"
		CURL_OPTS+=(-H "Content-Type: multipart/form-data")
		FORMTYPE=form
	fi

	# -- set method to --get if GET
    if [ "$METHOD" = GET ]
    then
        CURL_OPTS+=(--get)
    fi


	# -- Process parameters
	while [ -n "$1" ]; do
		if [ ."$1" = .-- ]; then
			shift
			_debug "Parameters: ${*}"
			break
		else
			CURL_OPTS+=(--"$FORMTYPE" $1)
		fi
		shift
	done

	# -- Check for zero parameters
	if [ -z "$1" ]; then
		set -- '&?success?"Successfully Completed!"?"failed"'
	fi

	# -- Testing check
	if [[ $TEST == "true" ]]; then
		echo "TEST: curl -sS -H \"X-Auth-Email: $CF_ACCOUNT\" -H \"X-Auth-Key: $CF_TOKEN\" -X $METHOD ${CURL_OPTS[*]} $APIv4_ENDPOINT$URL_PATH"
		CURL_OUTPUT_GLOBAL='{"success": true,"message": "Operation completed successfully"}'
		return "$CURL_EXIT_CODE"
	else
		# -- Go through pages of results
		while true; do
			# Set starting page and per page options
			QUERY_STRING="?page=$RESULT_PAGE&per_page=$RESULTS_PER_PAGE"

			# Run curl command
			_debug "CMD: curl -X $METHOD ${CURL_OPTS[*]} ${APIv4_ENDPOINT}${URL_PATH}${QUERY_STRING}"
			CURL_OUTPUT="$(curl -sS -H "X-Auth-Email: $CF_ACCOUNT" -H "X-Auth-Key: $CF_TOKEN" \
				-X "$METHOD" "${CURL_OPTS[@]}" "${APIv4_ENDPOINT}${URL_PATH}${QUERY_STRING}")"
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
			PROCESSED_OUTPUT=$(echo "$CURL_OUTPUT" | json_decode "$@" 2>/dev/null)
			_debug "PROCESSED_OUTPUT: $PROCESSED_OUTPUT"
			sed -e '/^!/d' <<<"$PROCESSED_OUTPUT"

			if grep -qE '^!has_more' <<<"$PROCESSED_OUTPUT"; then				
				(( page++ )) || true
			else
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
# -- get_zone_id - get Cloudflare zone id
# --
# -- Arguments:	$1 - zone name
# ===============================================
function get_zone_id () {
	_debug_all "func get_zone_id: ${*}"
	local ZONE_ID ZONE=$1 CLI_ZONE=$1	
		
	# -- Checking if zone is an ID or nam
	is_hex "$CLI_ZONE"
	if [ $? == true ]; then
		_debug "Zone is an ID - $CLI_ZONE"
		ZONE_ID=$1
	else
		_debug "Zone is a name - $CLI_ZONE"	
	fi

	# -- Get zoneid using call_cf_v4
	ZONE_ID="$(call_cf_v4 GET /zones name="$ZONE" -- .result ,id)"
	if [[ $? -ge 1 ]]; then
		_error "Error getting zone id for $ZONE"
		exit 1
	elif [[ -z "$ZONE_ID" ]]; then
		_error "No such DNS zone found - $ZONE"
		exit 1
	else 
		_debug "ZONE_ID: $ZONE_ID"		
	fi
	echo "$ZONE_ID"
}

# ==============================================================================================
# -- Start Script
# ==============================================================================================

# -- Check for bash version
check_bash
if [[ $QUIET == "1" ]]; then
	# TODO need to implement quiet mode
	echo "Quiet mode not implemented yet"
fi

# -- Check for options
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
		help full
		_die
		;;
	--)	shift
		break;;
	-*)	false;;
	*)	break;;
	esac
	shift
done

# -----------------------------------------------
# -- debug
# -----------------------------------------------
# -- Check for debug
if [[ $DEBUG == "1" ]]; then
	echo -e "${CYAN}** DEBUG: Debugging is on${ECOL}"
elif [[ $DEBUG_CURL_OUTPUT == "2" ]]; then
	echo -e "${CYAN}** DEBUG: Debugging is on + CURL OUTPUT${ECOL}"	
fi

# -----------------------------------------------
# -- Cloudflare credentials
# -----------------------------------------------
# -- Check for .cloudflare credentials
if [ ! -f "$HOME/.cloudflare" ]
	then
		echo "No .cloudflare file."
	if [ -z "$CF_ACCOUNT" ]
	then
		_error "No \$CF_ACCOUNT set."
		help usage
		_die
	fi
	if [ -z "$CF_TOKEN" ]
	then
		_error "No \$CF_TOKEN set."
		help usage
		_die
	fi
else
	_debug "Found .cloudflare file."
	# shellcheck source=/dev/null
	source "$HOME/.cloudflare"
	_debug "Sourced CF_ACCOUNT: $CF_ACCOUNT CF_TOKEN: $CF_TOKEN"

        if [ -z "$CF_ACCOUNT" ]
        then
                _error "No \$CF_ACCOUNT set in config."
                help usage
				_die
        fi
        if [ -z "$CF_TOKEN" ]
        then
                _error "No \$CF_TOKEN set in config.

        $USAGE"
        fi
fi

# -- Check for arguments
if [ -z "$1" ]; then
	help usage
	_die "Missing arguments" 1
fi

# -- Debug
CMD_ALL="${*}"
_running "Running: ${CMD_ALL}"

# -- run commands
CMD1=$1
shift

case "$CMD1" in

# ===============================================
# -- show command @SHOW
# ===============================================
show|list)	
	CMD2=$1
	shift
	case "$CMD2" in

	# -- zone
	zone)
		[ -z "$1" ] && { help show; _die "Missing zone for $CMD2"; }
		call_cf_v4 GET /zone --		
		;;
	# -- zone
	zones)
        # -- Max per page=1000 and max results = 2000
        # TODO figure out how to get all zones in one call, or warn there is more than 1000 and add an option for second set of results etc.
		call_cf_v4 GET /zones -- .result %"%s$TA%s$TA#%s$TA%s$TA%s$NL" ,name,status,id,original_name_servers,name_servers		
		;;

	# -- settings
	setting|settings)		
		[ -z "$1" ] && { help show; _die "Missing sub-command for $CMD2"; }
		CLI_ZONE=$1
		ZONE_ID="$(get_zone_id "$CLI_ZONE")"

		if [ "$details" = 1 ]; then		
			fieldspec=,id,value,'?editable?"Editable"?""','?modified_on?<",, mod: $modified_on"?""'
		else
			fieldspec=,id,value,\"\",\"\"
		fi
		call_cf_v4 GET /zones/$ZONE_ID/settings -- .result %"%-30s %s$TA%s%s$NL" "$fieldspec"
		;;

	# -- record
	record|records)
		_running "Running: cloudflare $CMD1 records $*"
		[ -z "$1" ] && _error "Usage: cloudflare $CMD1 records <zone>"
		CLI_ZONE=$1
		ZONE_ID="$(get_zone_id "$CLI_ZONE")"

		# -- Get zone data
		_debug "- Getting zone data for $ZONE_ID"
		call_cf_v4 GET /zones/$ZONE_ID/dns_records -- .result %"%-20s %11s %-8s %s %s$TA; %s #%s$NL" \
			',@zone_name@name,?<$ttl==1?"auto"?ttl,type,||priority||data.priority||"",content,!!proxiable proxied locked,id'
		;;

	# -- access-rules
	access-rules|listing|listings|blocking|blockings)
		call_cf_v4 GET /user/firewall/access_rules/rules -- .result %"%s$TA%s$TA%s$TA# %s$NL" ',<$configuration["value"],mode,modified_on,notes'
		;;
	email-routing)
		[ -z "$1" ] && { help show; _die "Missing zone for $CMD2"; }
		CLI_ZONE=$1
		ZONE_ID="$(get_zone_id "$CLI_ZONE")"
		#call_cf_v4 GET /zones/$ZONE_ID/email/routing --  %"%-30s %s$TA%s%s$NL" ',name,enabled,created,modified,status'
		call_cf_v4 GET /zones/$ZONE_ID/email/routing -- .result '&<"name: $name"' '&<"status: $status"' '&<"created: $created"' '&<"modified: $modified"' '&<"enabled: $enabled"' '&<"
		
		;;
	# -- no command catchall
	*)
		help show
		if [[ -n $CMD2 ]]; then
			_die "Unknown command $CMD2" 1
		else
			_die "No command provided for $1" 1
		fi
		;;
	esac
	;;

# ===============================================
# -- add command @ADD
# ===============================================
add)
	_debug "sub-command: add ${*}"
	CMD2=$1
	shift
	case "$CMD2" in
	record)		
		[ $# -lt 4 ] && { help add record;_die "Missing arguments - $CMD_ALL"; }
		ZONE=$1
		shift
		type=${1^^}
		shift
		name=$1
		shift
		content=$1
		ttl=$2
		if [[ "$type" == "A" ]] || [[ "$type" == "CNAME" ]]; then
			proxied=$3
		elif [[ "$type" == "MX" ]] || [[ "$type" == "SRV" ]]; then
			prio=$3
		fi
		service=$4
		protocol=$5
		weight=$6
		port=$7

		[ -n "$proxied" ] || proxied=true
		[ -n "$ttl" ] || ttl=1
		[ -n "$prio" ] || prio=10
		if [[ $content =~ ^127.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] && [[ "$type" == "A" ]]; then _error "Can't proxy 127.0.0.0/8 using an A record"; fi
		
		_running2 "Getting zone_id for $ZONE"
		ZONE_ID="$(get_zone_id "$ZONE")"
		_running2 " - Found zone $ZONE with id $ZONE_ID"

		case "$type" in
		MX)
			_running2 " -- Creating MX record: $name $content $ttl $prio"
			call_cf_v4 POST /zones/$ZONE_ID/dns_records "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":$ttl,\"priority\":$prio}"
			echo "Record created: $CURL_OUTPUT_GLOBAL"
			;;
		LOC)
			locdata=''
			data_separated=1
			if [ -n "${content//[! ]/}" ]
			then
				data_separated=0
				set -- $content
			fi
			for key in lat_degrees lat_minutes lat_seconds lat_direction \
			  long_degrees long_minutes long_seconds long_direction \
			  altitude size precision_horz precision_vert
			do
				value=$1
				value=${value%m}
				locdata="$locdata${locdata:+,}\"$key\":\"$value\""
				shift
			done
			if [ $data_separated = 1 ]
			then
				ttl=${1:-1}
			fi
			call_cf_v4 POST /zones/$zone_id/dns_records "{\"type\":\"$type\",\"ttl\":$ttl,\"name\":\"$name\",\"data\":{$locdata}}"
			;;
		SRV)
			[ "${service:0:1}" = _ ] || service="_$service"
			[ "${protocol:0:1}" = _ ] || protocol="_$protocol"
			[ -n "$weight" ] || weight=1
			target=$content

			call_cf_v4 POST /zones/$zone_id/dns_records "{
				\"type\":\"$type\",
				\"ttl\":$ttl,
				\"data\":{
					\"service\":\"$service\",
					\"proto\":\"$protocol\",
					\"name\":\"$name\",
					\"priority\":$prio,
					\"weight\":$weight,
					\"port\":$port,
					\"target\":\"$target\"
					}
				}"
			;;
		TXT)
			call_cf_v4 POST /zones/$zone_id/dns_records "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":$ttl}"
			;;
		A)
			call_cf_v4 POST /zones/$zone_id/dns_records "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":$ttl,\"proxied\":$proxied}"
			;;
		CNAME)
			call_cf_v4 POST /zones/$zone_id/dns_records "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":$ttl,\"proxied\":$proxied}"
			;;
		*)
			call_cf_v4 POST /zones/$zone_id/dns_records "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":$ttl}"
			;;
		esac
		;;

	whitelist|blacklist|block|challenge)
		trg=$1
		trg_type=''
		shift
		notes=$*
		case "$CMD2" in
		  whitelist)	mode=whitelist;;
		  blacklist|block)	mode=block;;
		  challenge)	mode=challenge;;
		esac

		if expr "$trg" : '[0-9\.]\+$' >/dev/null
		then
			trg_type=ip
		elif expr "$trg" : '[0-9\.]\+/[0-9]\+$' >/dev/null
		then
			trg_type=ip_range
		elif expr "$trg" : '[A-Z]\+$' >/dev/null
		then
			trg_type=country
		fi
		[ -z "$trg" -o -z "$trg_type" ] && _die "Usage: cloudflare add [<whitelist | blacklist | challenge>] [<IP | IP/mask | country_code>] [note]"

		call_cf_v4 POST /user/firewall/access_rules/rules mode=$mode configuration[target]="$trg_type" configuration[value]="$trg" notes="$notes"
		;;

	zone)
		if [ $# != 1 ]
		then
			_die "Usage: cloudflare add zone <name>"
		fi
		call_cf_v4 POST /zones "{\"name\":\"$1\",\"jump_start\":true}" -- .result '&<"status: $status"'
		;;
	*)
	help add;
	echo ""
	_die "Missing sub-command"
	esac
	;;

# ===============================================
# -- delete command
# ===============================================
delete)	
	CMD2=$1
	shift
	case "$CMD2" in
	record)
		prm1=$1
		prm2=$2
		shift
		shift

		if [ ${#prm2} = 32 ] && is_hex "$prm2"
		then
			if [ -n "$1" ]
			then
				_die "Unknown parameters: ${*}"
			fi
			if is_hex "$prm1"
			then
				zone_id=$prm1
			else
				get_zone_id "$prm1"
			fi
			record_id=$prm2

		else
			record_type=''
			first_match=0

			[ -z "$prm1" ] && _die "Usage: cloudflare delete record [<record-name> [<record-type> | first] | [<zone-name>|<zone-id>] <record-id>]"

			if [ "$prm2" = first ]
			then
				first_match=1
			else
				record_type=${prm2^^}
			fi

			findout_record "$prm1" "$record_type" "$first_match"
			case $? in
			0)	true;;
			2)	_die "No suitable DNS zone found for \`$prm1'";;
			3)	_die "DNS record \`$prm1' not found";;
			4)	_die "Ambiguous record spec: \`$prm1'";;
			*)	_die "Internal error";;
			esac
		fi

		call_cf_v4 DELETE /zones/$zone_id/dns_records/$record_id
		;;

	listing)
		[ -z "$1" ] && _die "Usage: cloudflare delete listing [<IP | IP range | country code | ID | note fragment>] [first]"
		call_cf_v4 GET /user/firewall/access_rules/rules -- .result ,id,configuration.value,notes |\
		while read ruleid trg notes; do
			if [ "$ruleid" = "$1" -o "$trg" = "$1" ] || grep -qF "$1" <<<"$notes"
			then
				call_cf_v4 DELETE /user/firewall/access_rules/rules/$ruleid
				if [ "$2" = first ]
				then
					break
				fi
			fi
		done
		;;

	zone)
		if [ $# != 1 ]
		then
			_die "Usage: cloudflare delete zone <name>"
		fi
		get_zone_id "$1"
		call_cf_v4 DELETE /zones/$zone_id
		;;

	*)
		_die "Parameters:
   zone, record, listing"
	esac
	;;

# ===============================================
# -- change|set command
# ===============================================
change|set)
	CMD2=$1
	shift
	
	case "$CMD2" in
	# -- Zone
	zone)		
		[ -z "$1" ] && { help change; _die "Missing arguments"; }		
		[ -z "$2" ] && { help change; _die "Missing arguments"; }
		CLI_ZONE="$1"
		ZONE_ID="$(get_zone_id $CLI_ZONE)"
		shift
		setting_items=''

		# -- Map settings
		declare -A map
		map[security_level]="security_level"
		map[cache_level]="cache_level"
		map[rocket_loader]="rocket_loader"
		map[minify]="minify"
		map[development_mode]="development_mode"
		map[mirage]="mirage"
		map[ipv6]="ipv6"

		# -- Loop through settings
		while [ -n "$1" ]; do
			_debug "Changing $1 on $CLI_ZONE"
			setting=$1
			shift

			if [ -n "${map[$setting]}" ]; then
				setting=${map[$setting]}
			else
				help change
				_die "Error: Setting '$setting' is not a valid setting"
				exit 1
			fi
			setting_value=$1
			shift

			case "$setting" in
			minify)
				css=off
				html=off
				js=off
				for s in ${setting_value//,/ }; do
					case "$s" in
					css|html|js) eval $s=on;;
					*) _die "E.g: cloudflare $CMD1 zone <zone> minify css,html,js"
					esac
				done
				setting_value="{\"css\":\"$css\",\"html\":\"$html\",\"js\":\"$js\"}"
			;;
			esac

			if [ "${setting_value:0:1}" != '{' ]; then
				setting_value="\"$setting_value\""
			fi
			setting_items="$setting_items${setting_items:+,}{\"id\":\"$setting\",\"value\":$setting_value}"
		done

		call_cf_v4 PATCH /zones/$ZONE_ID/settings "{\"items\":[$setting_items]}"
		if [[ $? != 1 ]]; then
			echo " -- $CURL_OUTPUT_GLOBAL"	
		fi	
		;;

	record)
	[ -z "$1" ] && { help change; _die "Missing arguments"; }
		record_name=$1
		shift
		record_type=''
		first_match=0
		record_oldcontent=''

		while [ -n "$1" ]
		do
			case "$1" in
			first)	first_match=1;;
			type)	shift; record_type=${1^^};;
			oldcontent)	shift; record_oldcontent=$1;;
			*)		break;;
			esac
			shift
		done

		[ -z "$1" ] && { help change; _die "Missing arguments"; }		

		findout_record "$record_name" "$record_type" "$first_match" "$record_oldcontent"
		e=$?
		case $e in
		0)	true;;
		2)	_die "No suitable DNS zone found for \`$record_name'";;
		3)	_die "DNS record \`$record_name' not found";;
		4)	_die "Ambiguous record name: \`$record_name'";;
		*)	_die "Internal error";;
		esac

		record_content_esc=${record_content//\"/\\\"}
		old_data="\"name\":\"$record_name\",\"type\":\"$record_type\",\"ttl\":$record_ttl,\"content\":\"$record_content_esc\""
		new_data=''
		while [ -n "$1" ]; do
			setting=$1
			shift
			value=$1
			shift

			[ "$setting" = service_mode ] && setting="proxied"
			[ "$setting" = newtype -o "$setting" = new_type ] && setting="type"
			[ "$setting" = newname -o "$setting" = new_name ] && setting="name"
			[ "$setting" = newcontent ] && setting="content"
			if [ "$setting" = proxied ]; then
				value=${value,,}
				[ "$value" = on -o "$value" = 1 ] && value=true
				[ "$value" = off -o "$value" = 0 ] && value=false
			fi
			[ "$setting" = type ] && value=${value^^}

			if [ "$setting" != content ] && ( expr "$value" : '[0-9]\+$' >/dev/null || expr "$value" : '[0-9]\+\.[0-9]\+$' >/dev/null || [ "$value" = true -o "$value" = false ] )
			then
				value_escq=$value
			else
				value_escq=\"${value//\"/\\\"}\"
			fi
			new_data="$new_data${new_data:+,}\"$setting\":$value_escq"
		done

		call_cf_v4 PUT /zones/$zone_id/dns_records/$record_id "{$old_data,$new_data}"
		if [[ $? != 1 ]]; then
			echo "$CURL_OUTPUT_GLOBAL"	
		fi
		;;
	*)
		help change
		_die "Missing argument."   
	esac
	;;

# ===============================================
# -- clear command
# ===============================================
clear)	
	case "$1" in
	cache)
		shift
		[ -z "$1" ] && { help clear; exit 1;}
		ZONE_ID=$(get_zone_id "$1")
		call_cf_v4 DELETE /zones/$ZONE_ID/purge_cache '{"purge_everything":true}'
		;;
	*)
		help clear
		exit 1;
		;;
	esac
	;;

# ----------------
# -- check command
# ----------------
check)
	case "$1" in
	zone)
		shift
		[ -z "$1" ] && _die "Usage: cloudflare check zone <zone>"
		get_zone_id "$1"
		call_cf_v4 PUT /zones/$zone_id/activation_check
		;;
	*)
		_die "Parameters:
   zone"
		;;
	esac
	;;

# ---------------------
# -- invalidate command
# ---------------------
invalidate)
	if [ -n "$1" ]
	then
		urls=''
		zone_id=''
		for url in "${*[@]}"; do
			urls="${urls:+$urls,}\"$url\""
			if [ -z "$zone_id" ]
			then
				if [[ "$url" =~ ^([^:]+:)?/*([^:/]+) ]]
				then
					re_grps=${#BASH_REMATCH[@]}
					domain=${BASH_REMATCH[re_grps-1]}
					while true
					do
						zone_id=`get_zone_id "$domain" 2>/dev/null; echo "$zone_id"`
						if [ -n "$zone_id" ]
						then
							break
						fi
						parent=${domain#*.}
						if [ "$parent" = "$domain" ]
						then
							break
						fi
						domain=$parent
					done
				fi
			fi
		done
		if [ -z "$zone_id" ]
		then
			_die "Zone name could not be figured out."
		fi
		call_cf_v4 DELETE /zones/$zone_id/purge_cache "{\"files\":[$urls]}"
	else
		_die "Usage: cloudflare invalidate <url-1> [url-2 [url-3 [...]]]"
	fi
	;;

# ---------------
# -- json command
# ---------------
json)
	json_decode "${*}"
	;;

# -----------------------------------------------
# -- pass command
# -----------------------------------------------
pass)	
	call_cf_v4 ${*}
	;;
# ---------------
# -- help command
# ---------------
help)
	help usage
	;;
*)
	help usage
	_die "No Command provided." 1
	;;
esac

