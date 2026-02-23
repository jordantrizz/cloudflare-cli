# AGENTS.md

## Development Notes
* Always generate a short commit message formatted as https://www.conventionalcommits.org/en/v1.0.0/ 
* Utilize git kraken for your git commits.
* Functions should exist in cf-inc.sh or cf-inc-cf.sh as we want to keep cloudflare.sh clean

## Structure
* The cloudflare command is a symlink to cloudflare.sh, which is the main entry point for the command line tool.

## Deprecated Functions
Don't use these functions anymore, they will be removed in future versions.
* findout_record
* json_decode 