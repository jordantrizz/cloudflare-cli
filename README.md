## DESCRIPTION

```
CLI utility managing CloudFlare services using CloudFlare API
```

## SYNOPSIS

```
$ cloudflare 
Usage: cloudflare [Options] <command> <parameters>
Options:
 --details, -d    Display detailed info where possible
 --debug, -D      Display API debugging info
 -E <email>
 -T <api_token>
Environment variables:
 CF_ACCOUNT  -  email address (as -E option)
 CF_TOKEN    -  API token (as -T option)
Enter "cloudflare help" to list available commands.

$ cloudflare help
Commands:
   show, add, delete, set, clear, invalidate, check

$ cloudflare show
Parameters:
   zones, settings, records, listing

$ cloudflare show settings
Usage: cloudflare list settings <zone>

$ cloudflare show records
Usage: cloudflare list records <zone>

$ cloudflare add
Parameters:
   zone, record, whitelist, blacklist

$ cloudflare add zone
Usage: cloudflare add zone <name>

$ cloudflare add record
Usage: cloudflare add record <zone> <type> <name> <content> [ttl] [prio] [service] [protocol] [weight] [port]
   <zone>      domain zone to register the record in (see "cloudflare list zones")
   <type>      eg. A AAAA CNAME MX NS SRV TXT SPF LOC (case insensitive)
   <name>      subdomain name, or "@" to refer to the domain's root
   <content>   usually an IP (A, AAAA), a target domain name (CNAME, MX, SRV), or free text (TXT)
   [ttl]       Time To Live, 1 = auto
   [prio]      required only by MX and SRV records, enter "10" if unsure
   [service]   free service name, eg. "_sip" (for SRV record type)
   [protocol]  _tcp, _udp, _tls (SRV)
   [weight]    relative weight for records with the same priority
   [port]      layer 4 port number

$ cloudflare add whitelist
Usage: cloudflare add [<whitelist | blacklist | challenge>] [<IP | IP/mask | country_code>] [note]

$ cloudflare delete
Parameters:
   zone, record, listing

$ cloudflare delete zone
Usage: cloudflare delete zone <zone>

$ cloudflare delete record
Usage: cloudflare delete record [<record-name> [<type>|"first"] | [zone] <record-id>]

$ cloudflare delete listing
Usage: cloudflare delete listing [<IP | IP/mask | country_code | ID | note_fragment>]

$ cloudflare set
Parameters:
   zone, record

$ cloudflare set zone
Usage: cloudflare set zone <zone> [setting] [value]

$ cloudflare set zone example.net
Parameters:
   sec_lvl [help | high | med | low | eoff]
   cache_lvl [agg | basic]
   rocket_loader [off | auto | manual]
   minify <bitmask>
       bit 1 = JS
       bit 2 = CSS
       bit 3 = HTML
   devmode [on | off]
   mirage2 [on | off]
   ipv6 [on | off]
         
$ cloudflare set record
Usage: cloudflare set record <record> ["type" <type> | "first"] [<parameter> <value>] [<parameter> <value>] ...
You must enter record type (A, MX, ...) when there are more records with the same name, or enter "first" to modify the first matching record in the zone.
Parameters:
  content        Usually IP address, or target for MX and CNAME
  service_mode   Turn CF proxying on (1) or off (0)
  for other parameters see 'add record' command.

$ cloudflare clear
Parameters:
   cache

$ cloudflare clear cache
Usage: cloudflare clear cache <zone>

$ cloudflare invalidate
Usage: cloudflare invalidate <url-1> [url-2 [url-3 [...]]]

$ cloudflare check
Parameters:
   zone

$ cloudflare check zone
Usage: cloudflare check zone <zone>
```


## REQUIREMENTS

- bash 4.x
- curl
- php (php-cli) 5.x
