#!/bin/bash
# -- A simple script to search for domains in your Cloudflare account
# -- Requires jq (https://stedolan.github.io/jq/)
# -- Usage: ./domain-search.sh <domain>
# -- Example: ./domain-search.sh example.com or ./domain-search.sh -f domains.txt

# -- Variables
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )" # -- Get current script directory
CACHE_FILE="$HOME/.cf-domain-search.cache"

# -- Check if jq is installed
if ! [ -x "$(command -v jq)" ]; then
  echo 'Error: jq is not installed.' >&2
  exit 1
fi

# -- usage
usage() {
    USAGE=\
"Usage: ./domain-search.sh (-f file.txt|<domain>) [-h] [-t] [-d]

    Example: ./domain-search.sh example.com or ./domain-search.sh -f domains.txt

    Options
        -h, --help      Display this help and exit
        -f, --file      File containing list of domains to search for
        -t, --test      Test file containing list of domains to search for
        -d, --debug     Enable debug mode
        -c, --cache     Enable cache mode

"
    echo "$USAGE"
}

# -- Debug
_debug () {
    [[ $DEBUG ]] && echo "DEBUG: $1"
}
_success () { echo -e "\033[0;42m${*} \e[0m"; }
_fail () { echo -e "\e[41m\e[97m${*} \e[0m"; }

# -- All args
ALL_ARGS="${*}"

# -- Process arguments
    POSITIONAL=()
    while [[ $# -gt 0 ]]
    do
    key="$1"

    case $key in
        -h|--help)
        HELP=YES
        shift # past argument
        ;;
        -t|--test)
        TEST="1"
        shift # past argument
        ;;
        -f|--file)
        DOMAIN_FILE="$2"
        shift # past argument
        shift # past value
        ;;
        -c|--cache)
        CACHE=1
        shift # past argument
        ;;
        -d|--debug)
        DEBUG="1"
        shift # past argument        
        ;;
        *)    # unknown option
        POSITIONAL+=("$1") # save it in an array for later
        shift # past argument
        ;;
    esac
    done
    set -- "${POSITIONAL[@]}" # restore positional parameters


# -- All args
_debug "ALL_ARGS: $ALL_ARGS"
_debug "\$1: $1"
_debug "TEST: $TEST"
_debug "DOMAIN_FILE: $DOMAIN_FILE"
_debug "DEBUG: $DEBUG"
[[ -n $1 ]] && DOMAIN="$1"

# -- Check if argument is passed
if [[ -z "$DOMAIN" && -z $DOMAIN_FILE ]]; then    
    usage
    echo "Error: No domain specified"
    exit 1
elif [[ $HELP ]]; then
    usage
    exit 1
fi


# --------------------
# -- Main
# --------------------

echo "Getting list of domains using ./cloudflare"
if [[ $TEST ]]; then
    CF_DOMAINS=$(cat $SCRIPT_DIR/tests/domains.txt)
    _debug "CF_DOMAINS: $CF_DOMAINS"
else
    if [[ $CACHE ]]; then
        if [[ -f $CACHE_FILE ]]; then
            # -- Check if cache file is older than an hour
            if [[ $(find $CACHE_FILE -mmin +60) ]]; then
                echo "-- Cache file is older than an hour, deleting cache file and pulling in fresh cache"
                rm $CACHE_FILE
                CF_DOMAINS=$($SCRIPT_DIR/cloudflare list zones | awk '{print $1}')
                echo "-- Caching domains to $HOME/.cf-domain-search.cache"
                echo "$CF_DOMAINS" > $HOME/.cf-domain-search.cache
            else
                echo "-- Cache file is not older than an hour, using cache file"
                CF_DOMAINS=$(cat $CACHE_FILE)
            fi
        else
            echo "-- Cache file does not exist, pulling in fresh cache"
            CF_DOMAINS=$($SCRIPT_DIR/cloudflare list zones | awk '{print $1}')
            echo "-- Caching domains to $HOME/.cf-domain-search.cache"
            echo "$CF_DOMAINS" > $HOME/.cf-domain-search.cache
        fi
    else
        echo "-- Grabbing domains from Cloudflare API"
        CF_DOMAINS=$($SCRIPT_DIR/cloudflare list zones | awk '{print $1}')
    fi
fi
echo ""

if [[ $DOMAIN_FILE ]]; then
    if [[ -f $DOMAIN_FILE ]]; then
        # -- Search for matching domains from $FILE in Cloudflare account
        echo "Search for matching domains from the file $DOMAIN_FILE in Cloudflare account"
        for domain in $(cat $DOMAIN_FILE); do
            SEARCH=$(grep '^'$domain'$' <<< "${CF_DOMAINS[@]}")
            if [[ $? == 0 ]]; then
                _success "$domain - FOUND"
            else
                 _fail "$domain - NOTFOUND"
            fi
        done
    else
        echo "Error: $DOMAIN_FILE does not exist"
        exit 1
    fi
else
    # -- Search for matching domain from stdin in Cloudflare account
    echo "Search for matching domain $DOMAIN in Cloudflare account"
    SEARCH=$(echo "${CF_DOMAINS[@]}" | grep "$DOMAIN")
    if [[ $? == 0 ]]; then        
        _success "$DOMAIN - FOUND"
    else
        _fail "$DOMAIN - NOTFOUND"
    fi
fi


