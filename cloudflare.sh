#!/usr/bin/env bash

# =================================================================================================
# cloudflare-cli v1.0.1
# =================================================================================================
# shellcheck source=./cf-inc.sh
source cf-inc.sh

# ==============================================================================================
# -- Start Script
# ==============================================================================================

# -- Variables


# -- Check functions
_check_bash
_check_quiet
_check_debug
_check_cloudflare_credentials

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

# -- Check for arguments
if [ -z "$1" ]; then
	help usage
	_die "Missing arguments" 1
fi

# -- Debug
CMD_ALL="${*}"
_running "Running: ${CMD_ALL}"

# ==============================================================================================
# -- Process Commands
# ==============================================================================================
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
			call_cf_v4 POST /zones/$ZONE_ID/dns_records "{\"type\":\"$type\",\"ttl\":$ttl,\"name\":\"$name\",\"data\":{$locdata}}"
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
			call_cf_v4 POST /zones/$ZONE_ID/dns_records "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":$ttl}"
			;;
		A)
			call_cf_v4 POST /zones/$ZONE_ID/dns_records "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":$ttl,\"proxied\":$proxied}"
			;;
		CNAME)
			call_cf_v4 POST /zones/$ZONE_ID/dns_records "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":$ttl,\"proxied\":$proxied}"
			;;
		*)
			call_cf_v4 POST /zones/$ZONE_ID/dns_records "{\"type\":\"$type\",\"name\":\"$name\",\"content\":\"$content\",\"ttl\":$ttl}"
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

# -----------------------------------------------
# -- template ( $TEMPLATE_NAME, $ZONE_ID )
# -----------------------------------------------
template)
	_debug_all "func template: ${*}"	
	ZONE=$2
	TEMPLATE_NAME=$3

	case "$1" in
	# -- list templates in /template
	list)
		_running "Listing templates"
		ls -1 templates
		;;
	apply)
		_debug "Applying template"

		# -- Check for template name
		if [ -z "$TEMPLATE_NAME" ]; then
			help template
			_die "Missing template name"
		fi

		# -- Check for zone id
		if [ -z "$ZONE" ]; then
			help template
			_die "Missing zone"
		fi

		# -- Check for template file
		if [ ! -f "templates/$TEMPLATE_NAME" ]; then
			help template
			_die "Template file not found - templates/$TEMPLATE_NAME"
		fi

		# -- Get template data, skip # comment lines
		TEMPLATE_DATA="$(grep -v '^#' "templates/$TEMPLATE_NAME")"
		_debug "TEMPLATE_DATA: $TEMPLATE_DATA"

		# -- Get zone_id
		_running2 "Getting zone_id for $ZONE"
		ZONE_ID="$(get_zone_id "$ZONE")"
		_debug "ZONE_ID: $ZONE_ID"
		
		# -- Run commands in template
		_running2 "Run below commands?"
		_running2 "-------------------"
		_running2 "Zone: $ZONE"
		_running2 "Zone ID: $ZONE_ID"
		_running2 "Template: $TEMPLATE_NAME"
		_running2 "Commands:"
		_running2 "-------------------"
		_running2 "$TEMPLATE_DATA"
		_running2 "-------------------"
		_running2 "Continue?"
		_running2 "-------------------"
		read -r -p "Continue? [y/N] " response
		
		# -- Check response
		case "$response" in
		[yY][eE][sS]|[yY]) 
			_debug "Continuing"
			;;
		*)
			_die "Aborting"
			;;
		esac

		_running2 "Running commands in template"
		while read -r line; do
			expanded_line="$(eval "echo \"$line\"")"
			_debug "Running command: $0 $expanded_line"
			"$0" $expanded_line
		done <<< "$TEMPLATE_DATA"
		;;
	*)
		help template;
		_die "Missing sub-command"
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

