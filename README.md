# cloudflare-cli
CLI utility managing CloudFlare services highly focused on DNS using CloudFlare API

# Usage

```
Usage: cloudflare [Options] <command> <parameters>
Options:
 --details, -d    Display detailed info where possible
 --debug, -D      Display API debugging info
 --quiet, -q      Less verbose
 -E <email>
 -T <api_token>
 -p, --profile    Use credentials profile NAME from ~/.cloudflare

Multi-Zone Options:
 -z, --zone       Specify zone (can be repeated for multiple zones)
 -f, --zones-file Read zones from file (one per line, # comments)
 --continue-on-error  Continue processing despite individual zone failures

Environment variables:
 CF_ACCOUNT  -  email address (as -E option)
 CF_TOKEN    -  API token (as -T option)
Enter "cloudflare help" to list available commands.
```

# Multi-Zone Operations

You can apply commands to multiple zones at once using the `-z` and `-f` options.

## Specify zones on command line
```bash
# Clear cache on multiple zones
cloudflare -z example.com -z example.org clear cache

# Show records for multiple zones  
cloudflare -z site1.com -z site2.com show records
```

## Use a zones file
Create a file with one zone per line (comments with `#` are supported):
```
# zones.txt
example.com
example.org
# staging.example.com  (commented out)
production.example.net
```

Then use it:
```bash
cloudflare -f zones.txt clear cache
```

## Bulk create zones under an account
If you want to create many zones under a specific account, combine `-f` (or repeated `-z`) with `add zone` and an account id:

```bash
# Create all zones from zones.txt under the given account id
cloudflare -f zones.txt --account-id <account_id> add zone

# Alternative form (account id as the parameter after `add zone`)
cloudflare -f zones.txt add zone <account_id>
```

The output includes the assigned Cloudflare nameservers per zone (these are the nameservers you update at your registrar).

## Combine both methods
```bash
cloudflare -z extra-zone.com -f zones.txt clear cache
```

## Continue on errors
By default, processing stops on the first error. Use `--continue-on-error` to process all zones:
```bash
cloudflare -f zones.txt --continue-on-error clear cache
```

After processing, a summary report is displayed and a log file is created in `$TMPDIR`.

# Config
## Config Global API
1. Create a file in $HOME/.cloudflare
2. Add the following lines to the file:
   ```
   CF_ACCOUNT=<your_email>
   CF_KEY=<your_api_token>
   ```
## Config Token
1. Create a file in $HOME/.cloudflare
2. Add the following lines to the file:
3. ```
   CF_TOKEN=<your_api_token>
   ```
## Config Profiles
You can create multiple profiles to manage different CloudFlare accounts or configurations. Each profile can have its own email and API token.
1. Create a file in $HOME/.cloudflare
2. Add the following lines to the file:
3. ```
   CF_ACCOUNT_<PROFILE>=<your_email>
   CF_KEY_<PROFILE>=<your_api_token>
   CF_TOKEN_<PROFILE>=<your_api_token>
   ```

# Commands

```
$ cloudflare help
Commands:
   show, add, delete, change, clear, invalidate, check
```

```
$ cloudflare show
Parameters:
   zones, settings, records, listing
```

```
$ cloudflare show zones
example.net active  #IDSTRING   OLD-NS1,OLD-NS2  NEW-NS1,NEW-NS2
```

```
$ cloudflare show settings
Usage: cloudflare show settings <zone>
```

```
$ cloudflare show settings example.net
advanced_ddos                  off
always_online                  on
automatic_https_rewrites       off
...
```

```
$ cloudflare show records
Usage: cloudflare show records <zone>
```

```
$ cloudflare show records example.net
www     auto CNAME     example.net.       ; proxiable,proxied #IDSTRING
@       auto A         198.51.100.1       ; proxiable,proxied #IDSTRING
*       3600 A         198.51.100.2       ;  #IDSTRING
...
```

```
$ cloudflare show listings
198.51.100.0/24 whitelist       2014-10-30T05:31:30.099176Z     # NOTES
198.51.100.4    block           2014-10-30T05:31:30.099176Z     # NOTES
CN              challenge       2014-10-30T05:31:30.099176Z     # NOTES
...
```

```
$ cloudflare add
Parameters:
   zone, record, whitelist, blacklist, challenge
```

```
$ cloudflare add zone
Usage: cloudflare add zone <name>
```

```
$ cloudflare add record
Usage: cloudflare add record <zone> <type> <name> <content> [ttl] [prio] [service] [protocol] [weight] [port]
   <zone>      domain zone to register the record in, see 'show zones' command
   <type>      one of: A, AAAA, CNAME, MX, NS, SRV, TXT, SPF, LOC
   <name>      subdomain name, or "@" to refer to the domain's root
   <content>   IP address for A, AAAA
               FQDN for CNAME, MX, NS, SRV
               any text for TXT, spf definition text for SPF
               coordinates for LOC (see RFC 1876 section 3)
   [ttl]       Time To Live, 1 = auto
   [prio]      required only by MX and SRV records, enter "10" if unsure
   These ones are only for SRV records:
   [service]   service name, eg. "sip"
   [protocol]  tcp, udp, tls
   [weight]    relative weight for records with the same priority
   [port]      layer-4 port number
```

```
$ cloudflare add whitelist
Usage: cloudflare add [<whitelist | blacklist | challenge>] [<IP | IP/mask | country_code>] [note]
```

```
$ cloudflare delete
Parameters:
   zone, record, listing
```

```
$ cloudflare delete zone
Usage: cloudflare delete zone <name>
```

```
$ cloudflare delete record
Usage: cloudflare delete record [<record-name> [<record-type> | first] | [<zone-name>|<zone-id>] <record-id>]
```

```
$ cloudflare delete record ftp.example.net
```

```
$ cloudflare delete record example.net 1234567890abcdef1234567890abcdef
```

```
$ cloudflare delete listing
Usage: cloudflare delete listing [<IP | IP range | country_code | ID | note_fragment>] [first]
```

```
$ cloudflare change
Parameters:
   zone, record
```

```
$ cloudflare change zone
Usage: cloudflare change zone <zone> <setting> <value> [<setting> <value> [ ... ]]
```

```
$ cloudflare change zone example.net
Settings:
   security_level [under_attack | high | medium | low | essentially_off]
   cache_level [aggressive | basic | simplified]
   rocket_loader [on | off | manual]
   minify <any variation of css, html, js delimited by comma>
   development_mode [on | off]
   mirage [on | off]
   ipv6 [on | off]
Other: see output of 'show zone' command
```

```
$ cloudflare change record
Usage: cloudflare set record <name> [type <type> | first | oldcontent <content>] <setting> <value> [<setting> <value> [ ... ]]
You must enter "type" and the record type (A, MX, ...) when the record name is ambiguous,
or enter "first" to modify the first matching record in the zone,
or enter "oldcontent" and the exact content of the record you want to modify if there are more records with the same name and type.
Settings:
  newname        Rename the record
  newtype        Change type
  content        See description in 'add record' command
  ttl            See description in 'add record' command
  proxied        Turn CF proxying on/off
```

```
$ cloudflare clear
Parameters:
   cache
```

```
$ cloudflare clear cache
Usage: cloudflare clear cache <zone>
```

```
$ cloudflare invalidate
Usage: cloudflare invalidate <url-1> [url-2 [url-3 [...]]]
```

```
$ cloudflare check
Parameters:
   zone
```

```
$ cloudflare check zone
Usage: cloudflare check zone <zone>
```


## REQUIREMENTS

- bash 4.x
- curl
- php (php-cli) 5.x


## DONATE

Support me to improve cloudflare-cli

<a href="https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=KAXRPGK8YBRVG"><img src="https://www.paypalobjects.com/en_US/i/btn/btn_donateCC_LG.gif" /></a>

