# Cloudflare CLI Test Suite

This comprehensive testing script tests all commands and functions of the Cloudflare CLI tool.

## Usage

```bash
./test-cloudflare.sh [domain-name]
```

## Examples

```bash
# Run all tests with a specific domain
./test-cloudflare.sh example.com

# Run basic tests only (no domain required)
./test-cloudflare.sh
```

## Test Categories

### 1. Help Commands
- Tests help output, usage information, and error handling for invalid commands

### 2. List/Show Commands  
- `list zones` - List all zones in account
- `list settings <zone>` - List zone settings
- `list records <zone>` - List DNS records for zone
- `list access-rules` - List firewall access rules
- `show zones` - Alias for list zones

### 3. Zone Operations
- `check zone <zone>` - Check zone activation status
- Tests with various flags (--details, --quiet, --debug)

### 4. Cache Operations ⚠️
**WARNING:** These tests perform actual cache clearing operations!
- `clear cache <zone>` - Clear all cache for zone
- `invalidate <url>` - Invalidate specific URLs

### 5. DNS Record Operations ⚠️
**WARNING:** These tests create and delete actual DNS records!
- `add record` - Create A and TXT records
- `change record` - Modify existing records
- `delete record` - Remove records
- Verification of record creation/deletion

### 6. Access Rule Operations ⚠️
**WARNING:** These tests create and delete actual firewall rules!
- `add whitelist/blacklist/challenge` - Create access rules
- `delete listing` - Remove access rules

### 7. Error Conditions
- Tests invalid commands, missing arguments, and error handling
- Tests with non-existent zones and invalid parameters

### 8. Debug and Verbose Modes
- Tests --debug, --details, and --quiet flags
- Verifies debug output is generated

### 9. JSON Functionality
- Tests the built-in JSON decoder functionality

## Prerequisites

1. **Cloudflare Credentials**: Configure either:
   - `~/.cloudflare` file with `CF_ACCOUNT` and `CF_KEY`
   - Environment variables `CF_ACCOUNT` and `CF_KEY`

2. **Test Domain**: For comprehensive testing, provide a domain that:
   - Is managed by your Cloudflare account
   - You have permission to modify DNS records
   - You're comfortable clearing cache for

## Safety Features

- **Interactive Prompts**: Destructive operations require user confirmation
- **Test Isolation**: Uses unique test record names with timestamps
- **Detailed Logging**: All test results saved to timestamped log files
- **Cleanup**: Automatically removes test records after testing

## Output

The script provides:
- Real-time test progress with PASS/FAIL/SKIP status
- Summary of total tests run, passed, failed, and skipped
- Detailed log file with full command output and results
- Non-zero exit code if any tests fail

## Example Output

```
Cloudflare CLI Test Suite
=========================
Test Domain: example.com
Test Log: test-results-20250820-113000.log
Test Time: Tue Aug 20 11:30:00 UTC 2025

=== Testing Help Commands ===
Testing: Help command ... PASSED
Testing: Help flag ... PASSED
Testing: No arguments ... PASSED

=== Testing List/Show Commands ===
Testing: List zones ... PASSED
Testing: List zone settings ... PASSED

...

Test Results Summary:
====================
Total Tests: 45
Passed: 42
Failed: 1
Skipped: 2
```

## Notes

- Some tests are skipped if no domain is provided
- Destructive tests require explicit user confirmation
- The script creates temporary test records that are cleaned up automatically
- All API calls use the same credentials as the main cloudflare CLI tool
