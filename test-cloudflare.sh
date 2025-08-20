#!/bin/bash

# ================================================================================
# -- Cloudflare CLI Testing Script
# ================================================================================
# This script tests all commands and functions of the cloudflare CLI
# Usage: ./test-cloudflare.sh <domain-name>
# Example: ./test-cloudflare.sh example.com
# ================================================================================

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
source "$SCRIPT_DIR/cf-cli-inc.sh"

# =====================================
# -- Test Configuration
# =====================================
TEST_DOMAIN="$1"
CLOUDFLARE_CLI="$SCRIPT_DIR/cloudflare"
LOG_FILE="$SCRIPT_DIR/test-results-$(date +%Y%m%d-%H%M%S).log"
TEMP_DIR="/tmp/cf-cli-test-$$"
TEST_RECORD_NAME="test-cf-cli"
TEST_RECORD_CONTENT="192.0.2.1"
TEST_TXT_CONTENT="v=test-cf-cli-$(date +%s)"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# =====================================
# -- Helper Functions
# =====================================

# Initialize test environment
init_test_env() {
    echo "Cloudflare CLI Test Suite"
    echo "========================="
    echo "Test Domain: $TEST_DOMAIN"
    echo "Test Log: $LOG_FILE"
    echo "Test Time: $(date)"
    echo ""
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Create log file
    echo "Cloudflare CLI Test Results - $(date)" > "$LOG_FILE"
    echo "Test Domain: $TEST_DOMAIN" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
}

# Cleanup test environment
cleanup_test_env() {
    rm -rf "$TEMP_DIR"
    echo ""
    echo "Test Results Summary:"
    echo "===================="
    echo "Total Tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "Skipped: $TESTS_SKIPPED"
    echo ""
    echo "Detailed results saved to: $LOG_FILE"
}

# Run a test command
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local expected_exit_code="${3:-0}"
    local should_contain="$4"
    local should_not_contain="$5"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Display test banner with white background and black text
    echo -e "\e[47m\e[30m Testing: $test_name \e[0m"
    echo "Command: $test_cmd"
    echo ""
    
    echo "Testing: $test_name" >> "$LOG_FILE"
    echo "Command: $test_cmd" >> "$LOG_FILE"
    
    # Run the command and capture output
    local output_file="$TEMP_DIR/test_output_$TESTS_TOTAL"
    local exit_code
    
    eval "$test_cmd" > "$output_file" 2>&1
    exit_code=$?
    
    local output
    output=$(cat "$output_file")
    
    # Display command output
    echo "Output:"
    echo "$output"
    echo ""
    
    # Check exit code
    local test_passed=true
    if [ "$exit_code" -ne "$expected_exit_code" ]; then
        test_passed=false
        echo -e "\e[41m\e[37m FAILED \e[0m (exit code: $exit_code, expected: $expected_exit_code)"
        echo "RESULT: FAILED (exit code: $exit_code, expected: $expected_exit_code)" >> "$LOG_FILE"
    fi
    
    # Check if output should contain certain text
    if [ -n "$should_contain" ] && ! echo "$output" | grep -q "$should_contain"; then
        test_passed=false
        echo -e "\e[41m\e[37m FAILED \e[0m (missing expected text: $should_contain)"
        echo "RESULT: FAILED (missing expected text: $should_contain)" >> "$LOG_FILE"
    fi
    
    # Check if output should not contain certain text
    if [ -n "$should_not_contain" ] && echo "$output" | grep -q "$should_not_contain"; then
        test_passed=false
        echo -e "\e[41m\e[37m FAILED \e[0m (contains unwanted text: $should_not_contain)"
        echo "RESULT: FAILED (contains unwanted text: $should_not_contain)" >> "$LOG_FILE"
    fi
    
    if [ "$test_passed" = true ]; then
        echo -e "\e[42m\e[37m PASSED \e[0m"
        echo "RESULT: PASSED" >> "$LOG_FILE"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    
    echo "Output:" >> "$LOG_FILE"
    echo "$output" >> "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"
    echo ""
    echo "=========================================="
    echo ""
    
    # Ask user to proceed to next test
    read -p "Press Enter to continue to next test (or Ctrl+C to exit)..." -r
    echo ""
}

# Skip a test with reason
skip_test() {
    local test_name="$1"
    local reason="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    
    echo -e "\e[47m\e[30m Skipping: $test_name \e[0m"
    echo "Reason: $reason"
    echo -e "\e[43m\e[30m SKIPPED \e[0m"
    echo ""
    echo "=========================================="
    echo ""
    
    # Ask user to proceed to next test
    read -p "Press Enter to continue to next test (or Ctrl+C to exit)..." -r
    echo ""
    
    echo "SKIPPED: $test_name - $reason" >> "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"
}

# =====================================
# -- Test Functions
# =====================================

# Test help and usage commands
test_help_commands() {
    echo ""
    echo -e "\e[44m\e[37m === Testing Help Commands === \e[0m"
    echo ""
    
    run_test "Help command" "$CLOUDFLARE_CLI help" 0 "Usage:"
    run_test "Help flag" "$CLOUDFLARE_CLI --help" 1 "Usage:"
    run_test "No arguments" "$CLOUDFLARE_CLI" 1 "Missing arguments"
    run_test "Invalid command" "$CLOUDFLARE_CLI invalid_command" 1 "No Command provided"
}

# Test list/show commands
test_list_commands() {
    echo ""
    echo -e "\e[44m\e[37m === Testing List/Show Commands === \e[0m"
    echo ""
    
    run_test "List zones" "$CLOUDFLARE_CLI list zones" 0
    run_test "Show zones (alias)" "$CLOUDFLARE_CLI show zones" 0
    
    if [ -n "$TEST_DOMAIN" ]; then
        run_test "List zone settings" "$CLOUDFLARE_CLI list settings $TEST_DOMAIN" 0
        run_test "List zone records" "$CLOUDFLARE_CLI list records $TEST_DOMAIN" 0
        run_test "Show zone info" "$CLOUDFLARE_CLI show zone $TEST_DOMAIN" 0
    else
        skip_test "Zone-specific list commands" "No test domain provided"
    fi
    
    run_test "List access rules" "$CLOUDFLARE_CLI list access-rules" 0
    run_test "List with invalid zone" "$CLOUDFLARE_CLI list settings invalid.domain.that.does.not.exist" 1 "Error"
}

# Test basic zone operations (read-only)
test_zone_operations() {
    if [ -z "$TEST_DOMAIN" ]; then
        skip_test "Zone operations" "No test domain provided"
        return
    fi
    
    echo ""
    echo -e "\e[44m\e[37m === Testing Zone Operations === \e[0m"
    echo ""
    
    # Test zone check
    run_test "Check zone activation" "$CLOUDFLARE_CLI check zone $TEST_DOMAIN" 0
    
    # Test with details flag
    run_test "List settings with details" "$CLOUDFLARE_CLI --details list settings $TEST_DOMAIN" 0
    
    # Test quiet mode
    run_test "List records quiet mode" "$CLOUDFLARE_CLI --quiet list records $TEST_DOMAIN" 0
}

# Test cache operations
test_cache_operations() {
    if [ -z "$TEST_DOMAIN" ]; then
        skip_test "Cache operations" "No test domain provided"
        return
    fi
    
    echo ""
    echo -e "\e[44m\e[37m === Testing Cache Operations === \e[0m"
    echo ""
    
    # Note: These operations actually clear cache, so we're testing with caution
    echo "WARNING: The following tests will actually clear cache for $TEST_DOMAIN"
    read -p "Continue with cache clearing tests? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_test "Clear cache" "$CLOUDFLARE_CLI clear cache $TEST_DOMAIN" 0 "success"
    else
        skip_test "Clear cache" "User chose not to run destructive cache tests"
    fi
    
    # Test invalidate with a sample URL
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        run_test "Invalidate specific URL" "$CLOUDFLARE_CLI invalidate https://$TEST_DOMAIN/test.css" 0
    else
        skip_test "Invalidate URL" "User chose not to run destructive cache tests"
    fi
}

# Test record operations (with user confirmation for write operations)
test_record_operations() {
    if [ -z "$TEST_DOMAIN" ]; then
        skip_test "Record operations" "No test domain provided"
        return
    fi
    
    echo ""
    echo -e "\e[44m\e[37m === Testing Record Operations === \e[0m"
    echo ""
    
    echo "WARNING: The following tests will create and delete DNS records for $TEST_DOMAIN"
    read -p "Continue with DNS record tests? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        skip_test "DNS record operations" "User chose not to run DNS modification tests"
        return
    fi
    
    # Test adding records
    run_test "Add A record" "$CLOUDFLARE_CLI add record $TEST_DOMAIN A $TEST_RECORD_NAME $TEST_RECORD_CONTENT 300 false" 0
    run_test "Add TXT record" "$CLOUDFLARE_CLI add record $TEST_DOMAIN TXT ${TEST_RECORD_NAME}-txt \"$TEST_TXT_CONTENT\" 300" 0
    
    # Test listing records to verify creation
    run_test "Verify A record exists" "$CLOUDFLARE_CLI list records $TEST_DOMAIN" 0 "$TEST_RECORD_NAME"
    
    # Test changing records
    run_test "Change A record content" "$CLOUDFLARE_CLI change record $TEST_RECORD_NAME.$TEST_DOMAIN content 192.0.2.2" 0
    run_test "Change A record TTL" "$CLOUDFLARE_CLI change record $TEST_RECORD_NAME.$TEST_DOMAIN ttl 600" 0
    
    # Test deleting records
    run_test "Delete A record" "$CLOUDFLARE_CLI delete record $TEST_RECORD_NAME.$TEST_DOMAIN A" 0
    run_test "Delete TXT record" "$CLOUDFLARE_CLI delete record ${TEST_RECORD_NAME}-txt.$TEST_DOMAIN TXT" 0
    
    # Verify deletion
    run_test "Verify A record deleted" "$CLOUDFLARE_CLI list records $TEST_DOMAIN" 0 "" "$TEST_RECORD_NAME"
}

# Test access rule operations
test_access_rule_operations() {
    echo ""
    echo -e "\e[44m\e[37m === Testing Access Rule Operations === \e[0m"
    echo ""
    
    echo "WARNING: The following tests will create and delete firewall access rules"
    read -p "Continue with access rule tests? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        skip_test "Access rule operations" "User chose not to run access rule modification tests"
        return
    fi
    
    # Test adding access rules
    run_test "Add IP whitelist" "$CLOUDFLARE_CLI add whitelist 192.0.2.100 'Test whitelist entry'" 0
    run_test "Add IP blacklist" "$CLOUDFLARE_CLI add blacklist 192.0.2.101 'Test blacklist entry'" 0
    run_test "Add challenge rule" "$CLOUDFLARE_CLI add challenge 192.0.2.102 'Test challenge entry'" 0
    
    # Test listing to verify
    run_test "List access rules" "$CLOUDFLARE_CLI list access-rules" 0 "192.0.2.100"
    
    # Test deleting access rules
    run_test "Delete whitelist rule" "$CLOUDFLARE_CLI delete listing 192.0.2.100" 0
    run_test "Delete blacklist rule" "$CLOUDFLARE_CLI delete listing 192.0.2.101" 0
    run_test "Delete challenge rule" "$CLOUDFLARE_CLI delete listing 192.0.2.102" 0
}

# Test error conditions and edge cases
test_error_conditions() {
    echo ""
    echo -e "\e[44m\e[37m === Testing Error Conditions === \e[0m"
    echo ""
    
    run_test "Missing arguments - list" "$CLOUDFLARE_CLI list" 1 "No command provided"
    run_test "Missing arguments - add" "$CLOUDFLARE_CLI add" 1 "Parameters:"
    run_test "Missing arguments - delete" "$CLOUDFLARE_CLI delete" 1 "Parameters:"
    run_test "Missing arguments - change" "$CLOUDFLARE_CLI change" 1 "Parameters:"
    run_test "Missing arguments - clear" "$CLOUDFLARE_CLI clear" 1 "Parameters: cache"
    run_test "Missing arguments - check" "$CLOUDFLARE_CLI check" 1 "Parameters:"
    
    run_test "Invalid zone for settings" "$CLOUDFLARE_CLI list settings nonexistent.invalid.zone.test" 1
    run_test "Invalid zone for records" "$CLOUDFLARE_CLI list records nonexistent.invalid.zone.test" 1
    
    if [ -n "$TEST_DOMAIN" ]; then
        run_test "Invalid record type" "$CLOUDFLARE_CLI add record $TEST_DOMAIN INVALID test-record 192.0.2.1" 1
        run_test "Missing record parameters" "$CLOUDFLARE_CLI add record $TEST_DOMAIN A" 1 "Missing arguments"
    fi
}

# Test debug and verbose modes
test_debug_modes() {
    if [ -z "$TEST_DOMAIN" ]; then
        skip_test "Debug modes" "No test domain provided"
        return
    fi
    
    echo ""
    echo -e "\e[44m\e[37m === Testing Debug and Verbose Modes === \e[0m"
    echo ""
    
    run_test "Debug mode" "$CLOUDFLARE_CLI --debug list zones" 0 "DEBUG:"
    run_test "Details mode" "$CLOUDFLARE_CLI --details list settings $TEST_DOMAIN" 0
    run_test "Quiet mode" "$CLOUDFLARE_CLI --quiet list records $TEST_DOMAIN" 0
}

# Test JSON decoder functionality
test_json_functionality() {
    echo ""
    echo -e "\e[44m\e[37m === Testing JSON Functionality === \e[0m"
    echo ""
    
    # Create a test JSON file
    local test_json="$TEMP_DIR/test.json"
    cat > "$test_json" << 'EOF'
{
  "result": [
    {"name": "example.com", "id": "12345", "status": "active"},
    {"name": "test.com", "id": "67890", "status": "pending"}
  ],
  "success": true
}
EOF
    
    run_test "JSON decode test" "cat $test_json | $CLOUDFLARE_CLI json .result ,name,id,status" 0 "example.com"
}

# =====================================
# -- Main Test Execution
# =====================================

# Check if domain argument is provided
if [ -z "$TEST_DOMAIN" ]; then
    echo "Warning: No test domain provided. Some tests will be skipped."
    echo "Usage: $0 <domain-name>"
    echo "Example: $0 example.com"
    echo ""
    read -p "Continue with basic tests only? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Test execution cancelled."
        exit 1
    fi
fi

# Check if cloudflare CLI exists
if [ ! -f "$CLOUDFLARE_CLI" ]; then
    echo "ERROR: Cloudflare CLI not found at $CLOUDFLARE_CLI"
    exit 1
fi

# Check if credentials are configured
if [ ! -f "$HOME/.cloudflare" ] && [ -z "$CF_ACCOUNT" ] && [ -z "$CF_KEY" ]; then
    echo "ERROR: Cloudflare credentials not configured."
    echo "Please create $HOME/.cloudflare or set CF_ACCOUNT and CF_KEY environment variables."
    exit 1
fi

# Initialize test environment
init_test_env

# Run all test suites
test_help_commands
test_list_commands
test_zone_operations
test_cache_operations
test_record_operations
test_access_rule_operations
test_error_conditions
test_debug_modes
test_json_functionality

# Cleanup and show results
cleanup_test_env

# Exit with appropriate code
if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
else
    exit 0
fi
