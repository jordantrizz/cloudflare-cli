#!/usr/bin/env bash
# =================================================================================================
# cloudflare-cli v1.0.1
# =================================================================================================
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
API_METHOD=""
API_PROFILE=""
# shellcheck source=./cf-inc.sh
source "$SCRIPT_DIR/cf-inc.sh"
# shellcheck source=./cf-inc-api.sh
source "$SCRIPT_DIR/cf-inc-api.sh"
# shellcheck source=cf-inc-cf.sh
source "$SCRIPT_DIR/cf-inc-cf.sh"

# ==============================================================================================
# -- Start Script
# ==============================================================================================

# -- Check options
_debug "Checking for options"
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
			DEBUG=1
			;;
		-DF|--debug-file)
			DEBUG_FILE=1			
			;;
		-DC|--debug-curl)
			DEBUG=1
			DEBUG_CURL_OUTPUT=1
			;;
		-d|--detail|--detailed|--details)
			details=1;;
		-q|--quiet)
			# TODO needs  to be re-implemmented
			QUIET=1;;
		-p|--profile)
			shift
			if [ -z "$1" ]; then
				_die "Usage: cloudflare --profile <profile_name>"
			fi
			API_PROFILE="$1"
			_debug "Using profile: $API_PROFILE"
			;;
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

# -- If no command left after option parsing, just show usage and exit
if [ -z "$1" ]; then
	help usage
	_die "Missing arguments" 1
fi

# -- Debug full command (post-option parsing)
CMD_ALL="${*}"
_running "Running: ${CMD_ALL}"

# =================================================================================================
# -- Process Commands
# =================================================================================================
CMD1=$1
shift
case "$CMD1" in

# =================================================================================================
# -- show command @SHOW
# =================================================================================================
show|list)	
	CMD2=$1
	shift
	case "$CMD2" in

	# -- zone
	zone)		
		[ -z "$1" ] && { help show; _die "Missing zone for $CMD2"; }
		DOMAIN="$1"
		_cf_zone_exists "$DOMAIN"
		ZONE_ID=$(_cf_zone_id "$DOMAIN")
		if [ $? ]; then
			_running2 "Getting zone details for $DOMAIN with ID $ZONE_ID"
			LIST_ZONE_OUTPUT="Name\tStatus\tType\tID\tName Servers\tOriginal Name Servers\n"
			LIST_ZONE_OUTPUT+="----\t------\t----\t--\t------------\t-------------------\n"
			LIST_ZONE_OUTPUT+=$(call_cf_v4 GET /zones/$ZONE_ID -- %"%s$TA%s$TA%s$TA%s$TA%s$TA%s$NL" ,name,status,type,id,name_servers,original_name_servers)
			echo -e "$LIST_ZONE_OUTPUT" | column -t -s $'\t'
		else
			_die "No zone found for $DOMAIN"
		fi
		;;
	# -- zone
	zones)
        # -- Max per page=1000 and max results = 2000
        # TODO figure out how to get all zones in one call, or warn there is more than 1000 and add an option for second set of results etc.
		#call_cf_v4 GET /zones -- .result %"%s$TA%s$TA#%s$TA%s$TA%s$NL" ,name,status,id,original_name_servers,name_servers		
		_cf_zone_list	
		;;

	# -- settings
	setting|settings)		
		[ -z "$1" ] && { help show; _die "Missing sub-command for $CMD2"; }
		CLI_ZONE="$1"
		_cf_zone_exists "$CLI_ZONE"
		ZONE_ID="$(_cf_zone_id "$CLI_ZONE")"
		if [ $? ]; then
			_running2 "Getting settings for $CLI_ZONE"
		else
			_die "No zone found for $CLI_ZONE"
		fi

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
		CLI_ZONE="$1"
		_cf_zone_exists "$CLI_ZONE"
		ZONE_ID="$(_cf_zone_id "$CLI_ZONE")"		

		# -- Get zone data
		_debug "- Getting zone data for $ZONE_ID"
		#call_cf_v4 GET /zones/$ZONE_ID/dns_records -- .result %"%-20s %11s %-8s %s %s$TA; %s #%s$NL" \
		#	',@zone_name@name,?<$ttl==1?"auto"?ttl,type,||priority||data.priority||"",content,!!proxiable proxied locked,id'
		_cf_zone_records "$ZONE_ID"
		;;

	# -- access-rules
	access-rules|listing|listings|blocking|blockings)
		call_cf_v4 GET /user/firewall/access_rules/rules -- .result %"%s$TA%s$TA%s$TA# %s$NL" ',<$configuration["value"],mode,modified_on,notes'
		;;
	email-routing)
		[ -z "$1" ] && { help show; _die "Missing zone for $CMD2"; }
		CLI_ZONE="$1"
		_cf_zone_exists "$CLI_ZONE"
		ZONE_ID="$(_cf_zone_id "$CLI_ZONE")"


		#call_cf_v4 GET /zones/$ZONE_ID/email/routing --  %"%-30s %s$TA%s%s$NL" ',name,enabled,created,modified,status'
		call_cf_v4 GET /zones/$ZONE_ID/email/routing -- .result '&<"name: $name"' '&<"status: $status"' '&<"created: $created"' '&<"modified: $modified"' '&<"enabled: $enabled"' 
		
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

# =================================================================================================
# -- add command @ADD
# =================================================================================================
add)
	_debug "sub-command: add ${*}"
	CMD2=$1
	shift
	case "$CMD2" in
	record)		
		[ $# -lt 4 ] && { help add record;_die "Missing arguments - $CMD_ALL"; }
		_pre_flight_check
		_debug "Running with $API_METHOD"
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
		_cf_zone_exists "$ZONE"
		ZONE_ID="$(_cf_zone_id "$ZONE")"
		_running2 " - Found zone $ZONE with id $ZONE_ID"

		RECORD_CREATE_OUTPUT="ID\tZone Name\tName\tType\tContent\tProxiable\tProxied\tTTL"
		RECORD_CREATE_OUTPUT+="\n--\t---------\t----\t----\t-------\t---------\t-------\t---\n"

		case "$type" in
		MX)
			_running2 " -- Creating MX record: $name $content $ttl $prio"
			RECORD_CREATE_OUTPUT+=$(call_cf_v4 POST /zones/$ZONE_ID/dns_records "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":\"$ttl\",\"priority\":$prio}")
			echo -e "$RECORD_CREATE_OUTPUT" | column -t -s $'\t'			
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
			_running2 " -- Creating LOC record: $name $content $ttl"
			RECORD_CREATE_OUTPUT+=$(call_cf_v4 POST /zones/$ZONE_ID/dns_records "{\"type\":\"$type\",\"ttl\":$ttl,\"name\":\"$name\",\"data\":{$locdata}}")
			echo -e "$RECORD_CREATE_OUTPUT" | column -t -s $'\t'
			;;
		SRV)
			[ "${service:0:1}" = _ ] || service="_$service"
			[ "${protocol:0:1}" = _ ] || protocol="_$protocol"
			[ -n "$weight" ] || weight=1
			target=$content

			call_cf_v4 POST /zones/$ZONE_ID/dns_records "{
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
			_running2 " -- Creating TXT record: $name $content $ttl"
			RECORD_CREATE_OUTPUT+=$(call_cf_v4 POST /zones/$ZONE_ID/dns_records "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":$ttl}" -- %"%s$TA%s$TA%s$TA%s$TA%s$TA%s$TA%s$TA%s$NL" ,id,zone_name,name,type,content,proxiable,proxied,ttl)
			echo -e "$RECORD_CREATE_OUTPUT" | column -t -s $'\t'
			;;
		A)
			_running2 " -- Creating A record: $name $content $ttl $proxied"
			cf_api POST /client/v4/zones/$ZONE_ID/dns_records "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":$ttl,\"proxied\":$proxied}"
			if [[ $? == 0 ]]; then
				_success "Record created"
				echo $API_OUTPUT | jq -r '.result | "\(.id)\t\(.zone_name)\t\(.name)\t\(.type)\t\(.content)\t\(.proxiable)\t\(.proxied)\t\(.ttl)"' | column -t -s $'\t'
			else
				_error "Error creating A record"
				echo "$API_OUTPUT"
			fi
			;;
		CNAME)
			_running2 " -- Creating CNAME record: $name $content $ttl $proxied"
			RECORD_CREATE_OUTPUT+=$(call_cf_v4 POST /zones/$ZONE_ID/dns_records "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":$ttl,\"proxied\":$proxied}" -- %"%s$TA%s$TA%s$TA%s$TA%s$TA%s$TA%s$TA%s$NL" ,id,zone_name,name,type,content,proxiable,proxied,ttl)
			echo -e "$RECORD_CREATE_OUTPUT" | column -t -s $'\t'
			;;

		*)  
			_running2 " -- Creating record: $name $content $ttl"
			#  ,id,zone_name,name,type,content,proxiable,proxied,ttl			
			RECORD_CREATE_OUTPUT+=$(call_cf_v4 POST /zones/$ZONE_ID/dns_records "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":$ttl}" -- %"%s$TA%s$TA%s$TA%s$TA%s$TA%s$TA%s$TA%s$NL" ,id,zone_name,name,type,content,proxiable,proxied,ttl)
			echo -e "$RECORD_CREATE_OUTPUT" | column -t -s $'\t'

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
		# Usage: cloudflare add zone <zone> [account-id] 
		DOMAIN="$1"
		ACCOUNT_ID="$2"
		if [ -z "$DOMAIN" ]; then
			_die "Usage: cloudflare add zone <zone> [account-id]"					
		fi

		# Check if zone already exists
		_running2 "Checking if zone $DOMAIN already exists"		
		ZONE_ID=$(_cf_zone_id "$DOMAIN")			
		if [ $? ]; then
			_running2 "Zone $DOMAIN does not exist"
		else
			_error "Zone $DOMAIN already exists with ID $ZONE_ID"
			exit
		fi


		# -- Check if account id is provided
		if [ -n "$ACCOUNT_ID" ]; then
			_running2 "Account ID provided: $ACCOUNT_ID"
			_debug "Account ID provided: $ACCOUNT_ID"
			JSON="{\"account\":{\"id\":\"$ACCOUNT_ID\"},\"name\":\"$DOMAIN\",\"jump_start\":true}"
		else
			_running2 "No Account ID provided, creating in default account"
			_debug "No Account ID provided"
			JSON="{\"name\":\"$DOMAIN\",\"jump_start\":true}"
		fi

		# -- Create a new zone
		CREATE_ZONE_OUTPUT_CMD=$(call_cf_v4 POST /zones "$JSON" -- %"%s$TA%s$TA%s$TA%s$TA%s$NL" ,name,status,type,id,name_servers)
		CREATE_ZONE_OUTPUT="Name\tStatus\tType\tID\tName Servers\n"
		CREATE_ZONE_OUTPUT+="----\t------\t----\t--\t------------\n"
		CREATE_ZONE_OUTPUT+=$CREATE_ZONE_OUTPUT_CMD
		
		
		_success "Zone created" 
		echo -e "$CREATE_ZONE_OUTPUT" | column -t -s $'\t'
		echo ""

		_notice "Please make sure to update your name servers to the following:"
		# Get name servers
		echo "$CREATE_ZONE_OUTPUT_CMD" | awk '{print $5}'

		;;
	*)
	help add;
	echo ""
	_die "Missing sub-command"
	esac
	;;

# =================================================================================================
# -- delete command
# =================================================================================================
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
				ZONE_ID=$(_cf_zone_id "$prm1")
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

		call_cf_v4 DELETE /zones/$ZONE_ID/dns_records/$record_id
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
		DOMAIN="$1"
		_cf_zone_exists "$DOMAIN"
		ZONE_ID=$(_cf_zone_id "$DOMAIN")
		if [[ -z "$ZONE_ID" ]]; then
			_die "No zone found for $DOMAIN"
		fi

		_running2 "Deleting zone $DOMAIN with ID $ZONE_ID"	
		# Confirm deletion
		echo ""
		echo "===================================================================="
		_error "This will delete zone $DOMAIN with ID $ZONE_ID"		
		DELETE_ZONE_ACCOUNT_DETAILS="Name\tStatus\tType\tID\tName Servers\tOriginal Name Servers\n"
		DELETE_ZONE_ACCOUNT_DETAILS+="----\t------\t----\t--\t------------\t-------------------\n"
		DELETE_ZONE_ACCOUNT_DETAILS+=$(call_cf_v4 GET /zones/$ZONE_ID -- %"%s$TA%s$TA%s$TA%s$TA%s$TA%s$NL" ,name,status,type,id,name_servers,original_name_servers)
		echo -e "$DELETE_ZONE_ACCOUNT_DETAILS" | column -t -s $'\t'
		echo "===================================================================="
		echo ""

		_running2 "Are you sure you want to delete zone $DOMAIN with ID $ZONE_ID?"
		read -r -p "Continue? [y/N] " response
		case "$response" in
		[yY][eE][sS]|[yY]) 
			_debug "Continuing"
			;;
		*)
			_die "Aborting"
			;;
		esac
		_running2 "Deleting zone $DOMAIN with ID $ZONE_ID"
		call_cf_v4 DELETE /zones/$ZONE_ID
		;;

	*)
		_die "Parameters:
   zone, record, listing"
	esac
	;;

# =================================================================================================
# -- change|set command
# =================================================================================================
change|set)
	CMD2=$1
	shift
	
	case "$CMD2" in
	# -- Zone
	zone)		
		[ -z "$1" ] && { help change; _die "Missing arguments"; }		
		[ -z "$2" ] && { help change; _die "Missing arguments"; }
		CLI_ZONE="$1"
		_cf_zone_exists "$CLI_ZONE"
		ZONE_ID="$(_cf_zone_id $CLI_ZONE)"		
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

# =================================================================================================
# -- clear command
# =================================================================================================
clear)	
	case "$1" in
	cache)		
		shift
		[ -z "$1" ] && { help clear; exit 1;}
		CLI_ZONE="$1"
		_cf_zone_exists "$CLI_ZONE"
		ZONE_ID=$(_cf_zone_id "$CLI_ZONE")
		call_cf_v4 DELETE /zones/$ZONE_ID/purge_cache '{"purge_everything":true}'
		;;
	*)
		help clear
		exit 1;
		;;
	esac
	;;

# =================================================================================================
# -- invalidate command
# =================================================================================================
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
						zone_id=`_cf_zone_id "$domain" 2>/dev/null; echo "$zone_id"`
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

# =================================================================================================
# -- template ( $TEMPLATE_NAME, $ZONE_ID )
# =================================================================================================
template)
	_debug "function:${FUNCNAME[0]} - ${*}"
	CMD=$1
	shift
	TEMPLATE_NAME=$1
	shift

	case "$CMD" in
	# -- list templates in /template
	list)
		_running "Listing templates"
		ls -1 templates
		;;
	apply)
		_running2 "Applying template $TEMPLATE_NAME"		
		# -- Check for template name
		if [ -z "$TEMPLATE_NAME" ]; then
			help template
			_die "Missing template name"
		fi

		# -- Check for template file
		if [ ! -f "templates/$TEMPLATE_NAME" ]; then
			help template
			_die "Template file not found - templates/$TEMPLATE_NAME"
		else
			_success "Template file found - templates/$TEMPLATE_NAME"
			TEMPLATE_FILE="templates/$TEMPLATE_NAME"
		fi

		# Parse command line options
		_running2 "Parsing command line options"
		declare -A ARG_VARIABLES
		declare -a REQUIRED_VARIABLES

		while [[ "$1" != "--" && $# -gt 0 ]]; do
		case "$1" in
			-v|--variable)
			shift
			key_value="$1"
			IFS='=' read -r key value <<< "$key_value"
			ARG_VARIABLES["$key"]="$value"
			;;
			*)
			echo "Unknown option: $1"
			exit 1
			;;
		esac
		shift
		done

		TEMPLATE_CONTENT=$(<"$TEMPLATE_FILE")

		# Function to apply variables to template
		apply_template() {
			local content="$1"
			for key in "${!ARG_VARIABLES[@]}"; do
				content="${content//\$$key/${ARG_VARIABLES[$key]}}"
			done
			echo "$content"
		}

		# Parse the template for variable definitions and commands
		_running2 "Parsing template for variables"
		while IFS= read -r line; do
		if [[ "$line" =~ ^#\ *(.*)=(.*) ]]; then			
			key="${BASH_REMATCH[1]}"
			value="${BASH_REMATCH[2]}"
			REQUIRED_VARIABLES+=("$key")
			_running3 " - Found template var: $key=${ARG_VARIABLES[$key]}"			
		fi
		done < "$TEMPLATE_FILE"

		# Check if all required variables are defined
		_running2 "Checking for required variables"
		for var in "${REQUIRED_VARIABLES[@]}"; do
			if [ -z "${ARG_VARIABLES[$var]}" ]; then
				_error "Error: Required variable '$var' is not defined."
				exit 1
			else
				_running3 " - Variable defined $var: ${ARG_VARIABLES[$var]}"
			fi
		done

		# Apply variables to the template content
		_running2 "Applying variables to template"
		# Remove comments
		TEMPLATE_CONTENT=$(sed '/^#/d' "$TEMPLATE_FILE")
		FINAL_COMMAND=$(apply_template "$TEMPLATE_CONTENT")

		# Execute the commands
		_running2 "Final command:"
		echo "$FINAL_COMMAND"
		echo ""
		echo -n "Proceed with the final command? [y/N] "
		read -r response
		
		if [[ ! "$response" =~ ^[Yy]$ ]]; then
			_die "Aborting"
		else
			# Run the template commands each new line is a command
			while IFS= read -r line; do
				# Check for blank line and skip
				[ -z "$line" ] && continue
				_running3 "============= Running: $line"
				[[ DEBUG -eq 1 ]] && echo "DEBUG: $line"
				[[ DEBUG -eq 1 ]] && set -x
				CMD_RUN=("$0" "$line")
				eval "${CMD_RUN[@]}"
				[[ DEBUG -eq 1 ]] && set +x
				_running3 "============= Done"
			done <<< "$FINAL_COMMAND"
			
		fi
		exit		
		;;
	*)
		help template;
		_die "Missing sub-command"
		;;
	esac
	;;

# =================================================================================================
# -- search
# =================================================================================================
search)
	_debug "Running: cloudflare search $*"
	CMD2=$1
	shift
	case "$CMD2" in
	zone)
		[ -z "$1" ] && { help search; _die "Missing zone name"; }
		_running2 "Searching for zone $1"
		zone_search "$1"
		;;
	zones)
		[ -z "$1" ] && { help search; _die "Missing search term"; }
		_running2 "Searching for zones with term $1"
		zone_search "$1"
		;;
	record)
		echo "Not implemented"
		;;
	*)
		_die "Usage: cloudflare search [zone|record]"
		;;
	esac
	;;

# -----------------------------------------------
# -- account
# -----------------------------------------------
account)
	CMD=$1
	shift	
	case "$CMD" in
	list)
		_running "Getting list of accounts"
		ACCOUNT_LIST_OUTPUT="Name\tID\tType\tCreated Date\n"
		ACCOUNT_LIST_OUTPUT+=$(call_cf_v4 GET /accounts -- .result %"%s$TA%s$TA%s$TA%s$NL" ,name,id,type,created_on)
		echo -e "$ACCOUNT_LIST_OUTPUT" | column -t -s $'\t'

		;;
	detail)
		ACCOUNT_ID=$1
		[ -z "$1" ] && { help accounts; _die "Missing account id"; }
		_running "Getting account details for $1"
		call_cf_v4 GET /accounts/$1
		;;
	zones)
		ACCOUNT_ID=$1
		[ -z "$1" ] && { help accounts; _die "Missing account id"; }
		_running "Getting zones for account $ACCOUNT_ID"
		ACCOUNT_ZONE_LIST="Name\tStatus\tType\tID\tName Servers\tOriginal Name Servers\n"
		ACCOUNT_ZONE_LIST+="----\t------\t----\t--\t------------\t-------------------\n"		
		ACCOUNT_ZONE_LIST+=$(call_cf_v4 GET /zones account.id=$ACCOUNT_ID -- .result %"%s$TA%s$TA%s$TA%s$TA%s$TA%s$NL" ,name,status,type,id,name_servers,original_name_servers)
		echo -e "$ACCOUNT_ZONE_LIST" | column -t -s $'\t'
		;;
	*)
		_die "Usage: cloudflare account list"
		;;
	esac
	;;

# =====================================
# -- proxy command
# =====================================
# =================================================================================================
# -- proxy command @PROXY
# =================================================================================================
proxy)
	_debug "sub-command: proxy ${*}"
	RECORD_NAME=$1
	if [[ -z "$RECORD_NAME" ]]; then
		help usage
		_die "Missing record name for proxy command" 1
	fi

	_pre_flight_check
	_debug "Running with $API_METHOD" 

	_running "Looking up record: $RECORD_NAME"
	if ! findout_record "$RECORD_NAME" "" 1; then
		_die "Record not found: $RECORD_NAME" 1
	fi

	# At this point findout_record has set: zone, zone_id, record_id, record_type, record_ttl, record_content
	_debug "Found record: zone=$zone zone_id=$zone_id id=$record_id type=$record_type ttl=$record_ttl content=$record_content"

	# Get current proxied status for the record
	current_proxied=$(call_cf_v4 GET /zones/${zone_id}/dns_records/${record_id} -- .result %"%s" ,proxied)
	if [[ "$current_proxied" == "true" ]]; then
		target_proxied="false"
		action="unproxy"
	else
		target_proxied="true"
		action="proxy"
	fi

	_running2 "Record: $RECORD_NAME ($record_type) -> currently proxied=$current_proxied"
	_read_answer "Do you want to $action this record? [y/N] "
	case "$ANSWER" in
		[yY]|[yY][eE][sS])
			_running2 "Updating record to proxied=$target_proxied"
			call_cf_v4 PATCH /zones/${zone_id}/dns_records/${record_id} -- '&>{"proxied":'"$target_proxied"'}'
			;;
		*)
			_running2 "Aborted by user; no changes made."
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
		DOMAIN="$1"
		[ -z "$DOMAIN" ] && _die "Usage: cloudflare check zone <zone>"
		_cf_zone_exists "$DOMAIN"
		ZONE_ID=$(_cf_zone_id "$DOMAIN")
		_running2 "Found zone id $ZONE_ID for $DOMAIN"
		call_cf_v4 PUT /zones/$ZONE_ID/activation_check
		;;
	*)
		_die "Parameters:
   zone"
		;;
	esac
	;;

# ---------------
# -- json command
# ---------------
json)	
	_running "Reading STDIN data and sending to json_decode with args: ${@}"
	JSON_FILE="$1"
	shift
	cat $JSON_FILE | json_decode "${@}"	
	;;
# -----------------------------------------------
# -- ishex command
# -----------------------------------------------
ishex)
	is_hex "${*}"
	echo $?
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

