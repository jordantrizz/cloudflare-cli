#!/usr/bin/env bash
# =============================================================================
# Regression tests for the multi-zone entry point (exit codes)
# =============================================================================
# The unit suite (tests/test-multi-zone.sh) exercises the multi-zone helper
# functions only. This suite runs the real `cloudflare` dispatcher against a
# stubbed curl, so it catches what a function-level test cannot:
#
#   - a `return` at the top level of the entry point (not a function)
#   - a successful multi-zone run exiting non-zero
#   - the spurious "Usage: cloudflare add zone <zone> [account-id]" error
#   - per-zone failures and --continue-on-error not reaching the exit status
#
# No network, no real zones, no real credentials, no 5s sleeps.
#
# Run: bash tests/test-multi-zone-cli.sh
# =============================================================================

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
CLI="$PARENT_DIR/cloudflare"
ACCOUNT_ID="0123456789abcdef0123456789abcdef"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Per-run state
RC=0
OUTPUT=""
CALLS=0
CASE_FAIL_MATCH=""

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
    [[ -n "${2:-}" ]] && echo "         Expected: $2"
    [[ -n "${3:-}" ]] && echo "         Got:      $3"
}

_test_section() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# =============================================================================
# Sandbox
# =============================================================================

TEST_TMP_DIR=$(mktemp -d)
trap '[[ -n "$TEST_TMP_DIR" ]] && rm -rf "$TEST_TMP_DIR"' EXIT

mkdir -p "$TEST_TMP_DIR/home" "$TEST_TMP_DIR/bin" "$TEST_TMP_DIR/tmp" "$TEST_TMP_DIR/work"

# A single profile so the credential check auto-selects it instead of prompting.
printf 'CF_TOKEN=stubtoken\n' > "$TEST_TMP_DIR/home/.cloudflare"

# Stub curl: print a canned Cloudflare body on stdout and exit 0.
# call_cf_v4 (cf-inc-cf.sh) reads stdout and looks for a leading
# {"success":false to detect an API error, so failures must exit 0 too.
cat > "$TEST_TMP_DIR/bin/curl" <<'STUB'
#!/usr/bin/env bash
zone=""
data=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --data) data="$2"; shift 2 ;;
        -H|-X) shift 2 ;;
        *) shift ;;
    esac
done
if [[ "$data" =~ \"name\":\"([^\"]+)\" ]]; then
    zone="${BASH_REMATCH[1]}"
fi
[[ -n "${STUB_CALL_LOG:-}" ]] && printf '%s\n' "$zone" >> "$STUB_CALL_LOG"

if [[ -n "${STUB_FAIL_MATCH:-}" && "$zone" == *"$STUB_FAIL_MATCH"* ]]; then
    printf '%s' '{"success":false,"errors":[{"code":1001,"message":"stub failure"}]}'
    exit 0
fi

printf '{"success":true,"result":{"name":"%s","status":"active","type":"full","id":"%s","name_servers":["isabel.ns.cloudflare.com","jim.ns.cloudflare.com"]}}' \
    "$zone" "$STUB_ZONE_ID"
STUB

# Stub sleep: the multi-zone loop waits MULTI_ZONE_DELAY (5s) between zones.
cat > "$TEST_TMP_DIR/bin/sleep" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB

chmod +x "$TEST_TMP_DIR/bin/curl" "$TEST_TMP_DIR/bin/sleep"

# =============================================================================
# Runner
# =============================================================================

# _write_zones <file> <zone> [<zone> ...]
_write_zones() {
    local file="$1"
    shift
    printf '%s\n' "$@" > "$file"
}

# _run_cli <stdin-text> <args...>
# Runs the real entry point in the sandbox and stores RC / OUTPUT / CALLS.
_run_cli() {
    local stdin_text="$1"
    shift
    local call_log="$TEST_TMP_DIR/calls.log"
    local started=$SECONDS
    : > "$call_log"

    (
        cd "$TEST_TMP_DIR/work" || exit 1
        printf '%b' "$stdin_text" | env -i \
            HOME="$TEST_TMP_DIR/home" \
            PATH="$TEST_TMP_DIR/bin:/usr/local/bin:/usr/bin:/bin" \
            TMPDIR="$TEST_TMP_DIR/tmp" \
            TERM=dumb \
            STUB_CALL_LOG="$call_log" \
            STUB_FAIL_MATCH="$CASE_FAIL_MATCH" \
            STUB_ZONE_ID="$ACCOUNT_ID" \
            bash "$CLI" "$@"
    ) > "$TEST_TMP_DIR/out.txt" 2>&1
    RC=$?
    ELAPSED=$(( SECONDS - started ))
    OUTPUT=$(<"$TEST_TMP_DIR/out.txt")
    CALLS=$(wc -l < "$call_log" 2>/dev/null | tr -d ' ')
    [[ -z "$CALLS" ]] && CALLS=0
}

_assert() {
    # _assert <description> <condition-exit-code> [expected] [got]
    ((TESTS_RUN++))
    if [[ "$2" -eq 0 ]]; then
        _test_pass "$1"
    else
        _test_fail "$1" "${3:-}" "${4:-}"
    fi
}

# =============================================================================
# Test: successful multi-zone run
# =============================================================================

test_success() {
    _test_section "Successful multi-zone add zone"
    CASE_FAIL_MATCH=""
    _write_zones "$TEST_TMP_DIR/work/zones-ok.txt" "alpha-test.example" "beta-test.example"

    _run_cli 'y\n' -f zones-ok.txt --account-id "$ACCOUNT_ID" add zone

    _assert "Exits 0 when every zone succeeded" "$([[ $RC -eq 0 ]] && echo 0 || echo 1)" "exit 0" "exit $RC"
    _assert "Processes both zones" "$([[ $CALLS -eq 2 ]] && echo 0 || echo 1)" "2 API calls" "$CALLS API calls"
    _assert "Prints both zone rows" "$(grep -q 'alpha-test.example' <<<"$OUTPUT" && grep -q 'beta-test.example' <<<"$OUTPUT" && echo 0 || echo 1)"

    _assert "Summary reports 2 successes" "$(grep -Eq 'Succeeded:[[:space:]]+2' <<<"$OUTPUT" && echo 0 || echo 1)" "Succeeded: 2" "$(grep -E 'Succeeded:' <<<"$OUTPUT")"

    _assert "No 'can only return' bash error" "$(! grep -q 'can only' <<<"$OUTPUT" && echo 0 || echo 1)" "no return diagnostic" "$(grep 'can only' <<<"$OUTPUT")"

    _assert "No spurious usage error" "$(! grep -q 'Usage: cloudflare add zone' <<<"$OUTPUT" && echo 0 || echo 1)" "no usage error" "$(grep 'Usage: cloudflare add zone' <<<"$OUTPUT")"

    _assert "Inter-zone delay is not actually slept" "$([[ $ELAPSED -lt 5 ]] && echo 0 || echo 1)" "< 5s" "${ELAPSED}s"
}

# =============================================================================
# Test: a failing zone stops the run
# =============================================================================

test_failure_stops() {
    _test_section "Per-zone failure stops the run"
    CASE_FAIL_MATCH="fail-zone"
    _write_zones "$TEST_TMP_DIR/work/zones-fail.txt" "fail-zone.example" "good-zone.example"

    _run_cli 'y\n' -f zones-fail.txt --account-id "$ACCOUNT_ID" add zone

    _assert "Exits 1 when a zone failed" "$([[ $RC -eq 1 ]] && echo 0 || echo 1)" "exit 1" "exit $RC"
    _assert "Does not attempt the zone after the failure" "$([[ $CALLS -eq 1 ]] && echo 0 || echo 1)" "1 API call" "$CALLS API calls"
    _assert "Summary names the failed zone" "$(grep -q 'fail-zone.example' <<<"$OUTPUT" && grep -q 'Failed:' <<<"$OUTPUT" && echo 0 || echo 1)"
    _assert "No spurious usage error" "$(! grep -q 'Usage: cloudflare add zone' <<<"$OUTPUT" && echo 0 || echo 1)"
}

# =============================================================================
# Test: --continue-on-error
# =============================================================================

test_continue_on_error() {
    _test_section "--continue-on-error keeps going and still exits non-zero"
    CASE_FAIL_MATCH="fail-"
    _write_zones "$TEST_TMP_DIR/work/zones-allfail.txt" "fail-a.example" "fail-b.example"

    _run_cli 'y\n' -f zones-allfail.txt --account-id "$ACCOUNT_ID" --continue-on-error add zone

    _assert "Exits 1 when zones failed" "$([[ $RC -eq 1 ]] && echo 0 || echo 1)" "exit 1" "exit $RC"
    _assert "Attempts both zones" "$([[ $CALLS -eq 2 ]] && echo 0 || echo 1)" "2 API calls" "$CALLS API calls"
    _assert "Summary reports 2 failures" "$(grep -Eq 'Failed:[[:space:]]+2' <<<"$OUTPUT" && echo 0 || echo 1)" "Failed: 2" "$(grep -E 'Failed:' <<<"$OUTPUT")"
}

# =============================================================================
# Test: user cancellation
# =============================================================================

test_cancel() {
    _test_section "Cancelling at the prompt"
    CASE_FAIL_MATCH=""
    _write_zones "$TEST_TMP_DIR/work/zones-cancel.txt" "alpha-test.example" "beta-test.example"

    _run_cli 'n\n' -f zones-cancel.txt --account-id "$ACCOUNT_ID" add zone

    _assert "Exits 1 when cancelled" "$([[ $RC -eq 1 ]] && echo 0 || echo 1)" "exit 1" "exit $RC"
    _assert "Makes no API calls" "$([[ $CALLS -eq 0 ]] && echo 0 || echo 1)" "0 API calls" "$CALLS API calls"
    _assert "Reports the cancellation" "$(grep -qi 'cancelled' <<<"$OUTPUT" && echo 0 || echo 1)"
    _assert "No spurious usage error" "$(! grep -q 'Usage: cloudflare add zone' <<<"$OUTPUT" && echo 0 || echo 1)"
}

# =============================================================================
# Test: the bulk zone add alias behaves identically
# =============================================================================

test_bulk_alias() {
    _test_section "bulk zone add matches add zone"
    CASE_FAIL_MATCH=""
    _write_zones "$TEST_TMP_DIR/work/zones-bulk.txt" "alpha-test.example" "beta-test.example"

    _run_cli 'y\n' -f zones-bulk.txt --account-id "$ACCOUNT_ID" bulk zone add

    _assert "Exits 0 on success" "$([[ $RC -eq 0 ]] && echo 0 || echo 1)" "exit 0" "exit $RC"
    _assert "Uses the bulk code path" "$(grep -q 'Bulk creating 2 zone(s)' <<<"$OUTPUT" && echo 0 || echo 1)"
    _assert "Summary reports 2 successes" "$(grep -Eq 'Succeeded:[[:space:]]+2' <<<"$OUTPUT" && echo 0 || echo 1)"
}

# =============================================================================
# Test: the entry point has no top-level return
# =============================================================================

test_no_top_level_return() {
    _test_section "Entry point structure"

    # `cloudflare` is a flat case dispatcher: option parsing, then one case.
    # It defines no functions, so any `return` in it runs outside a function
    # and can only print "can only `return' from a function or sourced script".
    # If a function is ever added to this file, narrow this check instead of
    # deleting it.
    local hits
    hits=$(grep -nE '^[[:space:]]*return\b' "$CLI")
    _assert "No top-level return in cloudflare" "$([[ -z "$hits" ]] && echo 0 || echo 1)" "no matches" "$hits"

    local exits
    exits=$(grep -cF "exit \"\$MULTI_ZONE_RC\"" "$CLI")
    _assert "Multi-zone branches exit with MULTI_ZONE_RC" "$([[ $exits -eq 2 ]] && echo 0 || echo 1)" "2 exits" "$exits"
}

# =============================================================================
# Run All Tests
# =============================================================================

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║        Multi-Zone Entry Point Tests (exit codes, no network)              ║"
echo "╚═══════════════════════════════════════════════════════════════════════════╝"

missing=0
for bin in bash jq mktemp grep wc; do
    command -v "$bin" >/dev/null 2>&1 || { echo "  skip: required command not found: $bin"; missing=1; }
done
if [[ $missing -eq 1 ]]; then
    echo ""
    echo "  Skipping: install the missing command(s) above and re-run."
    exit 0
fi

test_success
test_failure_stops
test_continue_on_error
test_cancel
test_bulk_alias
test_no_top_level_return

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

[[ $TESTS_FAILED -gt 0 ]] && exit 1
exit 0
