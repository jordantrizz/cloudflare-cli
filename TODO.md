# Todo
## 1.4.2
### Plan
#### Phase 1: CLI Input Handling
- [x] 1.1 Add support for multiple `-z` options in argument parsing (`cloudflare.sh`)
- [x] 1.2 Add `-f|--zones-file` option to accept a `zones.txt` file containing zone names/IDs
- [x] 1.3 Create `_parse_zones_file()` helper to read and validate zone list from file
- [x] 1.4 Merge zones from `-z` flags and `-f` file into a single `ZONES_TO_PROCESS` array

#### Phase 2: Multi-Domain Processing Core
- [x] 2.1 Create `_process_multi_zone()` wrapper function to iterate over zones
- [x] 2.2 Add pre-flight confirmation prompt showing domain count before processing
- [x] 2.3 Implement 5-second delay between zone operations to avoid rate limiting
- [x] 2.4 Add progress indicator (e.g., "Processing zone 3 of 10: example.com")

#### Phase 3: Logging & Reporting
- [x] 3.1 Create log file in `$TMP` with timestamped filename (e.g., `cf-multi-YYYYMMDD-HHMMSS.log`)
- [x] 3.2 Log each action per domain: zone name, action type, success/failure, timestamp
- [x] 3.3 Generate summary report at end: total processed, succeeded, failed, skipped
- [x] 3.4 Print log file path to user on completion

#### Phase 4: Error Handling
- [x] 4.1 Update error messages to include zone name/ID context
- [x] 4.2 Add `--continue-on-error` flag to proceed despite individual zone failures
- [x] 4.3 Collect failed zones and report them in summary
- [x] 4.4 Exit with non-zero status if any zone failed

#### Phase 5: Documentation & Testing
- [x] 5.1 Update `README.md` with multi-domain examples (`-z`, `-f`, combined)
- [x] 5.2 Add usage examples to `help` output in `cloudflare.sh`
- [x] 5.3 Create test file `tests/multi-domain.txt` with sample scenarios
- [ ] 5.4 Add unit tests for `_parse_zones_file()` and `_process_multi_zone()`

#### Completion Checklist
- [ ] All phases complete
- [ ] Manual testing with 3+ zones
- [ ] Version bump to 1.4.2
- [ ] Commit and tag release

### Add in support for applying rules to multiple domains.
* Allow specifying multiple -d options in the command line.
* Allow specifying zones.txt with zone domains or zoneid's to apply rules to multiple zones.
* Update README.md with examples of using multiple domains.
* Update unit tests to cover multiple domain scenarios.
* When multiple domaisn are specified, process the domains and count how many domains to action.
* Before starting process, confirm the amount of domains to process.
* Esnure that there is a 5 second delay between processing each domain to avoid rate limiting.
* Generate a summary report at the end showing the number of domains processed and actions taken.
* Generate a log file in $TMP detailing the actions taken for each domain.
* Update error handling to specify which domain an error occurred on when processing multiple domains.