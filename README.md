  DESCRIPTION

CLI utility managing CloudFlare services using CloudFlare API


  SYNOPSIS

Usage: cloudflare [-v] [-E <email>] [-T <api_token>] <command> <parameters>
Environment variables:
 CF_ACCOUNT  -  email address (-E option)
 CF_TOKEN    -  API token (-T option)


Commands:
   list, add, delete, set, clear

Command: list
Parameters:
   zones, settings, records, blocking

Command: add
Parameters:
   record, whitelist, blacklist

Command: add record
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

Command: delete record
Usage: cloudflare delete record [<record-name> [<type>|"first"] | [zone] <record-id>]

Command: set zone
Parameters:
   sec_lvl [help | high | med | low | eoff]
   cache_lvl [agg | basic]
   rocket_loader [off | auto | manual]
   minify <bitmask>
       bit 1 = JS
       bit 2 = CSS
       bit 3 = HTML
   devmode [on | off]

