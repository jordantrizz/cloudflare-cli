#!/usr/bin/env bash
# =============================================================================
# Unit Tests for Multi-Zone Processing Functions (v1.4.2)
# =============================================================================
# Run: bash tests/test-multi-zone.sh
# =============================================================================

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")

# Source required files
source "$PARENT_DIR/cf-inc.sh"
source "$PARENT_DIR/cf-inc-api.sh" 2>/dev/null

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Global temp directory for tests - exported so subshells can access it
export TEST_TMP_DIR=$(mktemp -d)
trap "rm -rf $TEST_TMP_DIR" EXIT

# =============================================================================
# Test Helpers
# =============================================================================

_test_pass() {
    ((TESTS_PASSED++))
    echo -e "\e[32m  ✓ PASS:\e[0m $1"
}

_test_fail() {
    ((TESTS_FAILED++))
    echo -e "\e[31m  ✗ FAIL:\e[0m $1"
    [[ -n "$2" ]] && echo "         Expected: $2"
    [[ -n "$3" ]] && echo "         Got:      $3"
}

_test_section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# =============================================================================
# Test: _parse_zones_file
# =============================================================================

test_parse_zones_file() {
    _test_section "Testing _parse_zones_file()"
    local TMPFILE
    local OUTPUT
    local COUNT

    # Test 1: Valid zones file
    ((TESTS_RUN++))
    TMPFILE=$(mktemp)
    cat > "$TMPFILE" << 'EOF'
example.com
example.org
test.net
EOF
    OUTPUT=$(_parse_zones_file "$TMPFILE")
    COUNT=$(echo "$OUTPUT" | wc -l)
    if [[ $COUNT -eq 3 ]]; then
        _test_pass "Parses valid zones file with 3 zones"
    else
        _test_fail "Parses valid zones file with 3 zones" "3 zones" "$COUNT zones"
    fi
    rm -f "$TMPFILE"

    # Test 2: File with comments
    ((TESTS_RUN++))
    TMPFILE=$(mktemp)
    cat > "$TMPFILE" << 'EOF'
# This is a comment
example.com
# Another comment
example.org
EOF
    OUTPUT=$(_parse_zones_file "$TMPFILE")
    COUNT=$(echo "$OUTPUT" | wc -l)
    if [[ $COUNT -eq 2 ]]; then
        _test_pass "Skips comment lines"
    else
        _test_fail "Skips comment lines" "2 zones" "$COUNT zones"
    fi
    rm -f "$TMPFILE"

    # Test 3: File with inline comments
    ((TESTS_RUN++))
    TMPFILE=$(mktemp)
    cat > "$TMPFILE" << 'EOF'
example.com # production site
example.org # staging
EOF
    OUTPUT=$(_parse_zones_file "$TMPFILE")
    if echo "$OUTPUT" | grep -q "example.com" && ! echo "$OUTPUT" | grep -q "#"; then
        _test_pass "Strips inline comments"
    else
        _test_fail "Strips inline comments" "zone without comment" "$OUTPUT"
    fi
    rm -f "$TMPFILE"

    # Test 4: File with blank lines
    ((TESTS_RUN++))
    TMPFILE=$(mktemp)
    cat > "$TMPFILE" << 'EOF'
example.com

example.org

test.net
EOF
    OUTPUT=$(_parse_zones_file "$TMPFILE")
    COUNT=$(echo "$OUTPUT" | wc -l)
    if [[ $COUNT -eq 3 ]]; then
        _test_pass "Skips blank lines"
    else
        _test_fail "Skips blank lines" "3 zones" "$COUNT zones"
    fi
    rm -f "$TMPFILE"

    # Test 5: File with whitespace
    ((TESTS_RUN++))
    TMPFILE=$(mktemp)
    cat > "$TMPFILE" << 'EOF'
  example.com  
	example.org	
EOF
    OUTPUT=$(_parse_zones_file "$TMPFILE")
    FIRST=$(echo "$OUTPUT" | head -1)
    if [[ "$FIRST" == "example.com" ]]; then
        _test_pass "Trims leading/trailing whitespace"
    else
        _test_fail "Trims leading/trailing whitespace" "example.com" "$FIRST"
    fi
    rm -f "$TMPFILE"

    # Test 6: Non-existent file
    ((TESTS_RUN++))
    OUTPUT=$(_parse_zones_file "/nonexistent/file.txt" 2>&1)
    if [[ $? -ne 0 ]]; then
        _test_pass "Returns error for non-existent file"
    else
        _test_fail "Returns error for non-existent file" "error" "success"
    fi

    # Test 7: Empty file
    ((TESTS_RUN++))
    TMPFILE=$(mktemp)
    echo "" > "$TMPFILE"
    OUTPUT=$(_parse_zones_file "$TMPFILE" 2>&1)
    if [[ $? -ne 0 ]]; then
        _test_pass "Returns error for empty file"
    else
        _test_fail "Returns error for empty file" "error" "success"
    fi
    rm -f "$TMPFILE"

    # Test 8: Missing argument
    ((TESTS_RUN++))
    OUTPUT=$(_parse_zones_file 2>&1)
    if [[ $? -ne 0 ]]; then
        _test_pass "Returns error when no file argument provided"
    else
        _test_fail "Returns error when no file argument provided" "error" "success"
    fi
}

# =============================================================================
# Test: _init_multi_zone_log
# =============================================================================

test_init_multi_zone_log() {
    _test_section "Testing _init_multi_zone_log()"
    
    # Test 1: Creates log file
    ((TESTS_RUN++))
    ZONES_TO_PROCESS=("example.com" "example.org")
    _init_multi_zone_log
    if [[ -f "$MULTI_ZONE_LOG" ]]; then
        _test_pass "Creates log file"
    else
        _test_fail "Creates log file" "file exists" "file not found"
    fi

    # Test 2: Log file has correct header
    ((TESTS_RUN++))
    if grep -q "Cloudflare CLI Multi-Zone Operation Log" "$MULTI_ZONE_LOG"; then
        _test_pass "Log file contains header"
    else
        _test_fail "Log file contains header" "header present" "header missing"
    fi

    # Test 3: Log file has zone count
    ((TESTS_RUN++))
    if grep -q "Total zones: 2" "$MULTI_ZONE_LOG"; then
        _test_pass "Log file contains zone count"
    else
        _test_fail "Log file contains zone count" "Total zones: 2" "not found"
    fi

    # Cleanup
    rm -f "$MULTI_ZONE_LOG"
    ZONES_TO_PROCESS=()
}

# =============================================================================
# Test: _log_zone_action
# =============================================================================

test_log_zone_action() {
    _test_section "Testing _log_zone_action()"
    
    # Setup
    ZONES_TO_PROCESS=("example.com")
    _init_multi_zone_log

    # Test 1: Logs action correctly
    ((TESTS_RUN++))
    _log_zone_action "example.com" "clear_cache" "SUCCESS" "Cache cleared"
    if grep -q "example.com" "$MULTI_ZONE_LOG" && grep -q "SUCCESS" "$MULTI_ZONE_LOG"; then
        _test_pass "Logs zone action with status"
    else
        _test_fail "Logs zone action with status" "zone and status logged" "not found"
    fi

    # Test 2: Logs timestamp
    ((TESTS_RUN++))
    if grep -qE '\[[0-9]{2}:[0-9]{2}:[0-9]{2}\]' "$MULTI_ZONE_LOG"; then
        _test_pass "Logs timestamp in HH:MM:SS format"
    else
        _test_fail "Logs timestamp in HH:MM:SS format" "timestamp" "not found"
    fi

    # Cleanup
    rm -f "$MULTI_ZONE_LOG"
    ZONES_TO_PROCESS=()
}

# =============================================================================
# Test: _confirm_multi_zone (non-interactive)
# =============================================================================

test_confirm_multi_zone() {
    _test_section "Testing _confirm_multi_zone()"
    
    # Test 1: Returns 1 (false) when user enters 'n'
    ((TESTS_RUN++))
    ZONES_TO_PROCESS=("example.com" "example.org")
    echo "n" | _confirm_multi_zone > /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        _test_pass "Returns false when user declines"
    else
        _test_fail "Returns false when user declines" "return 1" "return 0"
    fi

    # Test 2: Returns 0 (true) when user enters 'y'
    ((TESTS_RUN++))
    echo "y" | _confirm_multi_zone > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        _test_pass "Returns true when user confirms"
    else
        _test_fail "Returns true when user confirms" "return 0" "return 1"
    fi

    ZONES_TO_PROCESS=()
}

# =============================================================================
# Test: _multi_zone_summary
# =============================================================================

test_multi_zone_summary() {
    _test_section "Testing _multi_zone_summary()"
    
    # Setup
    ZONES_TO_PROCESS=("zone1.com" "zone2.com" "zone3.com")
    ZONES_SUCCESS=("zone1.com" "zone2.com")
    ZONES_FAILED=("zone3.com")
    _init_multi_zone_log

    # Test 1: Outputs summary
    ((TESTS_RUN++))
    OUTPUT=$(_multi_zone_summary 2>&1)
    if echo "$OUTPUT" | grep -q "Total zones"; then
        _test_pass "Outputs total zone count"
    else
        _test_fail "Outputs total zone count" "Total zones" "not found"
    fi

    # Test 2: Shows failed zones
    ((TESTS_RUN++))
    if echo "$OUTPUT" | grep -q "zone3.com"; then
        _test_pass "Lists failed zones"
    else
        _test_fail "Lists failed zones" "zone3.com" "not found"
    fi

    # Cleanup
    rm -f "$MULTI_ZONE_LOG"
    ZONES_TO_PROCESS=()
    ZONES_SUCCESS=()
    ZONES_FAILED=()
}

# =============================================================================
# Test: _process_multi_zone
# =============================================================================

# Mock action function for testing - writes to temp file to track invocations
_mock_action_success() {
    echo "$1" >> "$TEST_TMP_DIR/mock_invocations.txt"
    return 0
}

_mock_action_fail() {
    echo "$1" >> "$TEST_TMP_DIR/mock_invocations.txt"
    return 1
}

test_process_multi_zone() {
    _test_section "Testing _process_multi_zone()"
    
    # Note: Piping to _process_multi_zone runs it in a subshell, so we can't
    # check ZONES_SUCCESS/ZONES_FAILED arrays directly. Instead, we verify
    # behavior through the mock function invocations and return codes.
    
    # Test 1: Processes all zones on success (verify via mock invocations)
    ((TESTS_RUN++))
    ZONES_TO_PROCESS=("zone1.com" "zone2.com")
    ZONES_SUCCESS=()
    ZONES_FAILED=()
    MULTI_ZONE_DELAY=0  # Speed up tests
    rm -f "$TEST_TMP_DIR/mock_invocations.txt"
    
    # Auto-confirm with 'y'
    echo "y" | _process_multi_zone _mock_action_success > /dev/null 2>&1
    RESULT=$?
    INVOCATIONS=$(wc -l < "$TEST_TMP_DIR/mock_invocations.txt" 2>/dev/null || echo "0")
    
    if [[ $RESULT -eq 0 ]] && [[ $INVOCATIONS -eq 2 ]]; then
        _test_pass "Processes all zones on success"
    else
        _test_fail "Processes all zones on success" "return 0, 2 invocations" "return $RESULT, $INVOCATIONS invocations"
    fi
    rm -f "$MULTI_ZONE_LOG"

    # Test 2: Stops on error without --continue-on-error
    ((TESTS_RUN++))
    ZONES_TO_PROCESS=("zone1.com" "zone2.com" "zone3.com")
    ZONES_SUCCESS=()
    ZONES_FAILED=()
    MULTI_ZONE_CONTINUE_ON_ERROR=0
    rm -f "$TEST_TMP_DIR/mock_invocations.txt"
    
    echo "y" | _process_multi_zone _mock_action_fail > /dev/null 2>&1
    RESULT=$?
    INVOCATIONS=$(wc -l < "$TEST_TMP_DIR/mock_invocations.txt" 2>/dev/null || echo "0")
    
    # Should stop after first failure, so only 1 invocation
    if [[ $RESULT -ne 0 ]] && [[ $INVOCATIONS -eq 1 ]]; then
        _test_pass "Stops on first error by default"
    else
        _test_fail "Stops on first error by default" "return 1, 1 invocation" "return $RESULT, $INVOCATIONS invocations"
    fi
    rm -f "$MULTI_ZONE_LOG"

    # Test 3: Continues on error with flag set
    ((TESTS_RUN++))
    ZONES_TO_PROCESS=("zone1.com" "zone2.com" "zone3.com")
    ZONES_SUCCESS=()
    ZONES_FAILED=()
    MULTI_ZONE_CONTINUE_ON_ERROR=1
    rm -f "$TEST_TMP_DIR/mock_invocations.txt"
    
    echo "y" | _process_multi_zone _mock_action_fail > /dev/null 2>&1
    RESULT=$?
    INVOCATIONS=$(wc -l < "$TEST_TMP_DIR/mock_invocations.txt" 2>/dev/null || echo "0")
    
    # Should continue despite errors, so 3 invocations
    if [[ $RESULT -ne 0 ]] && [[ $INVOCATIONS -eq 3 ]]; then
        _test_pass "Continues on error when flag set"
    else
        _test_fail "Continues on error when flag set" "return 1, 3 invocations" "return $RESULT, $INVOCATIONS invocations"
    fi
    rm -f "$MULTI_ZONE_LOG"

    # Test 4: User cancellation
    ((TESTS_RUN++))
    ZONES_TO_PROCESS=("zone1.com")
    ZONES_SUCCESS=()
    ZONES_FAILED=()
    rm -f "$TEST_TMP_DIR/mock_invocations.txt"
    
    echo "n" | _process_multi_zone _mock_action_success > /dev/null 2>&1
    RESULT=$?
    if [[ -f "$TEST_TMP_DIR/mock_invocations.txt" ]]; then
        INVOCATIONS=$(wc -l < "$TEST_TMP_DIR/mock_invocations.txt")
    else
        INVOCATIONS=0
    fi
    
    if [[ $RESULT -ne 0 ]] && [[ $INVOCATIONS -eq 0 ]]; then
        _test_pass "Cancels when user declines"
    else
        _test_fail "Cancels when user declines" "return 1, 0 invocations" "return $RESULT, $INVOCATIONS invocations"
    fi

    # Cleanup
    ZONES_TO_PROCESS=()
    ZONES_SUCCESS=()
    ZONES_FAILED=()
    MULTI_ZONE_CONTINUE_ON_ERROR=0
    MULTI_ZONE_DELAY=5
}

# =============================================================================
# Run All Tests
# =============================================================================

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║          Multi-Zone Processing Unit Tests (v1.4.2)                        ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"

test_parse_zones_file
test_init_multi_zone_log
test_log_zone_action
test_confirm_multi_zone
test_multi_zone_summary
test_process_multi_zone

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Test Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Total:  $TESTS_RUN"
echo -e "  \e[32mPassed: $TESTS_PASSED\e[0m"
if [[ $TESTS_FAILED -gt 0 ]]; then
    echo -e "  \e[31mFailed: $TESTS_FAILED\e[0m"
fi
echo ""

# Exit with error if any tests failed
[[ $TESTS_FAILED -gt 0 ]] && exit 1
exit 0
