# AGENTS.md

## Development Notes

* Always generate a short commit message formatted as https://www.conventionalcommits.org/en/v1.0.0/ after making any changes.
* Functions should exist in cf-inc.sh or cf-inc-cf.sh as we want to keep cloudflare.sh clean
* Human output goes through the vendored bash-ui library (`ui_*`, stderr). Data stays on stdout with `echo`/`printf`, so pipes keep working. Never write raw colour escapes or `tput` calls; `ui_style` is the only way to colour text.
* `cf-inc.sh` is the single place that loads `vendor/bash-ui/ui.sh`, with `$BASH_UI` for development and plain `printf` stubs when the file is missing. Scripts that don't source `cf-inc.sh` carry the same loader or, for single-file deployments like `cfddnsupdate`, an inlined region between `# >>> bash-ui <version> >>>` and `# <<< bash-ui <<<`.
* Keep the vendored library current with `bash <(curl -fsSL https://raw.githubusercontent.com/jordantrizz/bash-ui/main/scripts/bash-ui.sh) update`; CI checks the checksum, the pinned version and the inlined region in `cfddnsupdate`.

## Structure

* The cloudflare command is a symlink to cloudflare.sh, which is the main entry point for the command line tool.
* `vendor/bash-ui/` holds the pinned bash-ui release (`ui.sh` plus `ui.sh.sha256`). It is never edited by hand.

## Deprecated Functions

Don't use these functions anymore, they will be removed in future versions.
* findout_record
* json_decode
* `_error`, `_warning`, `_success`, `_running`, `_running2`, `_running3`, `_creating`, `_separator`, `_dryrun`, `_quiet`, `_loading*` — thin adapters over bash-ui (use `ui_err`, `ui_warn`, `ui_ok`, `ui_step`, `ui_info`, `ui_hr` directly)
* `_die` — use `ui_die`
