#!/usr/bin/env bash
# =============================================================================
# Unit Tests for Managed Zone Helpers
# =============================================================================
# Run: bash tests/test-managed-zone.sh
# =============================================================================

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")

source "$PARENT_DIR/cf-inc.sh"
source "$PARENT_DIR/cf-inc-api.sh" 2>/dev/null
source "$PARENT_DIR/cf-inc-cf.sh" 2>/dev/null

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

API_OUTPUT=""
CURL_EXIT_CODE=""
MESG=""
CSV=0
QUIET=0
ZONES_TO_PROCESS=()

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

cf_api() {
    local method="$1"
    local path="$2"
    CF_API_LAST_METHOD="$method"
    CF_API_LAST_PATH="$path"

    case "$CF_API_SCENARIO" in
        managed)
            CURL_EXIT_CODE="200"
            API_OUTPUT='{"result":[{"id":"zone-123","name":"example.com","status":"active"}]}'
            ;;
        missing)
            CURL_EXIT_CODE="200"
            API_OUTPUT='{"result":[]}'
            ;;
        error)
            CURL_EXIT_CODE="403"
            MESG="Forbidden"
            API_OUTPUT='{"success":false}'
            ;;
        *)
            CURL_EXIT_CODE="500"
            MESG="Unknown test scenario"
            API_OUTPUT='{}'
            ;;
    esac
}

test_cf_zone_managed_info() {
    local OUTPUT
    local RESULT

    _test_section "Testing _cf_zone_managed_info()"

    ((TESTS_RUN++))
    CF_API_SCENARIO="managed"
    OUTPUT=$(_cf_zone_managed_info "example.com")
    RESULT=$?
    if [[ $RESULT -eq 0 ]] && [[ "$OUTPUT" == $'example.com\tyes\tactive\tzone-123' ]]; then
        _test_pass "Returns managed zone details"
    else
        _test_fail "Returns managed zone details" $'exit 0 and example.com\tyes\tactive\tzone-123' "exit $RESULT and $OUTPUT"
    fi

    ((TESTS_RUN++))
    CF_API_SCENARIO="missing"
    OUTPUT=$(_cf_zone_managed_info "missing.example.com")
    RESULT=$?
    if [[ $RESULT -eq 2 ]] && [[ "$OUTPUT" == $'missing.example.com\tno\t\t' ]]; then
        _test_pass "Returns a negative managed result for missing zones"
    else
        _test_fail "Returns a negative managed result for missing zones" $'exit 2 and missing.example.com\tno\t\t' "exit $RESULT and $OUTPUT"
    fi

    ((TESTS_RUN++))
    CF_API_SCENARIO="error"
    OUTPUT=$(_cf_zone_managed_info "example.com")
    RESULT=$?
    if [[ $RESULT -eq 1 ]]; then
        _test_pass "Returns an error on API failure"
    else
        _test_fail "Returns an error on API failure" "exit 1" "exit $RESULT"
    fi
}

test_cf_print_zone_managed_result() {
    local OUTPUT

    _test_section "Testing _cf_print_zone_managed_result()"

    ((TESTS_RUN++))
    CSV=1
    OUTPUT=$(_cf_print_zone_managed_result $'example.com\tyes\tactive\tzone-123')
    if echo "$OUTPUT" | grep -q '^domain,managed,status,zone_id$' && echo "$OUTPUT" | grep -q '^example.com,yes,active,zone-123$'; then
        _test_pass "Prints CSV header and row"
    else
        _test_fail "Prints CSV header and row" "CSV header and row" "$OUTPUT"
    fi

    ((TESTS_RUN++))
    CSV=0
    OUTPUT=$(_cf_print_zone_managed_result $'example.com\tyes\tactive\tzone-123' 2>&1)
    if echo "$OUTPUT" | grep -q 'Domain is managed by the current account - example.com' && echo "$OUTPUT" | grep -q 'active'; then
        _test_pass "Prints human-readable managed output"
    else
        _test_fail "Prints human-readable managed output" "success line and active status" "$OUTPUT"
    fi
}

test_cf_zone_managed_check_many() {
    local OUTPUT
    local RESULT

    _test_section "Testing _cf_zone_managed_check_many()"

    ((TESTS_RUN++))
    CSV=1
    ZONES_TO_PROCESS=("example.com" "missing.example.com")
    CF_API_SCENARIO="managed"
    OUTPUT=$(
        cf_api() {
            local method="$1"
            local path="$2"
            case "$path" in
                */zones\?name=example.com)
                    CURL_EXIT_CODE="200"
                    API_OUTPUT='{"result":[{"id":"zone-123","name":"example.com","status":"active"}]}'
                    ;;
                */zones\?name=missing.example.com)
                    CURL_EXIT_CODE="200"
                    API_OUTPUT='{"result":[]}'
                    ;;
            esac
        }
        _cf_zone_managed_check_many "${ZONES_TO_PROCESS[@]}"
    )
    RESULT=$?
    if [[ $RESULT -eq 2 ]] && [[ $(echo "$OUTPUT" | grep -c '^domain,managed,status,zone_id$') -eq 1 ]] && echo "$OUTPUT" | grep -q '^example.com,yes,active,zone-123$' && echo "$OUTPUT" | grep -q '^missing.example.com,no,,$'; then
        _test_pass "Prints one CSV header and aggregates mixed managed results"
    else
        _test_fail "Prints one CSV header and aggregates mixed managed results" "exit 2 and one CSV header" "exit $RESULT and $OUTPUT"
    fi

    ((TESTS_RUN++))
    CSV=0
    ZONES_TO_PROCESS=("example.com" "broken.example.com")
    OUTPUT=$(
        cf_api() {
            local method="$1"
            local path="$2"
            case "$path" in
                */zones\?name=example.com)
                    CURL_EXIT_CODE="200"
                    API_OUTPUT='{"result":[{"id":"zone-123","name":"example.com","status":"active"}]}'
                    ;;
                */zones\?name=broken.example.com)
                    CURL_EXIT_CODE="403"
                    MESG="Forbidden"
                    API_OUTPUT='{"success":false}'
                    ;;
            esac
        }
        _cf_zone_managed_check_many "${ZONES_TO_PROCESS[@]}" 2>&1
    )
    RESULT=$?
    if [[ $RESULT -eq 1 ]] && echo "$OUTPUT" | grep -q 'Domain is managed by the current account - example.com' && echo "$OUTPUT" | grep -q 'Unable to determine whether broken.example.com is managed by the current account'; then
        _test_pass "Returns API failure when any zone lookup fails"
    else
        _test_fail "Returns API failure when any zone lookup fails" "exit 1 with one managed result and one API error" "exit $RESULT and $OUTPUT"
    fi
}

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║             Managed Zone Helper Unit Tests                              ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"

test_cf_zone_managed_info
test_cf_print_zone_managed_result
test_cf_zone_managed_check_many

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

[[ $TESTS_FAILED -gt 0 ]] && exit 1
exit 0