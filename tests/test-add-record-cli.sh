#!/usr/bin/env bash
# =============================================================================
# Regression tests for `cloudflare add record --ttl / --proxy`
# =============================================================================
# Runs the real entry point against a stubbed curl, so the flag parsing,
# prompting, defaults and probe behaviour are exercised without a network,
# real zones or real credentials.
#
# CF_ASSUME_TTY=1 is the test hook that makes the prompt helpers run with a
# piped stdin; without it (and without a terminal) the record defaults apply.
#
# Run: bash tests/test-add-record-cli.sh
# =============================================================================

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
CLI="$PARENT_DIR/cloudflare"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Per-run state
RC=0
OUTPUT=""
CALLS=0
POSTS=""

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
# Sandbox
# =============================================================================

TEST_TMP_DIR=$(mktemp -d)
trap '[[ -n "$TEST_TMP_DIR" ]] && rm -rf "$TEST_TMP_DIR"' EXIT

mkdir -p "$TEST_TMP_DIR/home" "$TEST_TMP_DIR/bin" "$TEST_TMP_DIR/tmp" "$TEST_TMP_DIR/work"

# A single profile so the credential check auto-selects it instead of prompting.
printf 'CF_TOKEN=stubtoken\n' > "$TEST_TMP_DIR/home/.cloudflare"

# Stub curl. Handles both call shapes used by the CLI:
#   cf_api      --output FILE -w "%{http_code}" --request ... --url ... [--data JSON]
#   call_cf_v4  -sS URL?... -X ... [--data JSON]           (body on stdout)
# Every POST body is appended to STUB_CALL_LOG for assertions.
cat > "$TEST_TMP_DIR/bin/curl" <<'STUB'
#!/usr/bin/env bash
url=""
method="GET"
payload=""
out=""
while [ $# -gt 0 ]; do
    case "$1" in
        --output) out="$2"; shift 2 ;;
        -w) shift 2 ;;
        --request|-X) method="$2"; shift 2 ;;
        --url) url="$2"; shift 2 ;;
        --data|--data-raw|--data-binary) payload="$2"; shift 2 ;;
        -H|--header) shift 2 ;;
        --get|--silent|--show-error|-s|-S|-sS) shift ;;
        -*) shift ;;
        *) url="$1"; shift ;;
    esac
done

if [[ "$method" == "POST" ]]; then
    [[ -n "${STUB_CALL_LOG:-}" ]] && printf 'POST %s %s\n' "$url" "$payload" >> "$STUB_CALL_LOG"
    result=$(printf '%s' "$payload" | jq -c \
        '. + {id:"rec1", zone_name:"example.com", proxiable:true,
              proxied:(.proxied // false), ttl:(.ttl // 1)}' 2>/dev/null)
    if [[ -z "$result" || "$result" == "null" ]]; then
        result='{"id":"rec1","zone_name":"example.com","name":"www","type":"A","content":"203.0.113.10","proxiable":true,"proxied":false,"ttl":1}'
    fi
    body="{\"success\":true,\"result\":$result}"
else
    [[ -n "${STUB_CALL_LOG:-}" ]] && printf 'GET %s\n' "$url" >> "$STUB_CALL_LOG"
    if [[ "$url" == *"/zones?name="* ]]; then
        body='{"success":true,"result":[{"id":"zone1"}]}'
    else
        body='{"success":true,"result":[]}'
    fi
fi

if [[ -n "$out" ]]; then
    printf '%s' "$body" > "$out"
    printf '200'
else
    printf '%s' "$body"
fi
STUB

chmod +x "$TEST_TMP_DIR/bin/curl"

# =============================================================================
# Runner
# =============================================================================

# _run_cli <stdin-text> <args...>
# Runs the real entry point in the sandbox and stores RC / OUTPUT / CALLS / POSTS.
# CASE_TTY controls CF_ASSUME_TTY (0 = no terminal hook, 1 = prompts enabled).
_run_cli() {
    local stdin_text="$1"
    shift
    local call_log="$TEST_TMP_DIR/calls.log"
    : > "$call_log"

    (
        cd "$TEST_TMP_DIR/work" || exit 1
        printf '%b' "$stdin_text" | env -i \
            HOME="$TEST_TMP_DIR/home" \
            PATH="$TEST_TMP_DIR/bin:/usr/local/bin:/usr/bin:/bin" \
            TMPDIR="$TEST_TMP_DIR/tmp" \
            TERM=dumb \
            CF_ASSUME_TTY="${CASE_TTY:-0}" \
            STUB_CALL_LOG="$call_log" \
            bash "$CLI" "$@"
    ) > "$TEST_TMP_DIR/out.txt" 2>&1
    RC=$?
    OUTPUT=$(<"$TEST_TMP_DIR/out.txt")
    CALLS=$(grep -c '^POST ' "$call_log" 2>/dev/null)
    [[ -z "$CALLS" ]] && CALLS=0
    POSTS=$(grep '^POST ' "$call_log" 2>/dev/null)
}

# Request bodies may span lines (curl receives the JSON verbatim), so search the
# whole call log; POSTS keeps the first line of each POST for failure output.
_has_post() { grep -qF -- "$1" "$TEST_TMP_DIR/calls.log"; }
_has_output() { grep -qF -- "$1" <<<"$OUTPUT"; }

# =============================================================================
# Test: flags drive TTL and proxying
# =============================================================================

test_flags() {
    _test_section "Flags set TTL and proxying"
    CASE_TTY=0
    _run_cli '' add record example.com A www 203.0.113.10 --ttl 300 --proxy no

    _assert "Exits 0" "$([[ $RC -eq 0 ]] && echo 0 || echo 1)" "exit 0" "exit $RC"
    _assert "Sends one create request" "$([[ $CALLS -eq 1 ]] && echo 0 || echo 1)" "1 POST" "$CALLS POST"
    _assert "Payload carries ttl 300" "$(_has_post '"ttl":300' && echo 0 || echo 1)" '"ttl":300' "$POSTS"
    _assert "Payload carries proxied false" "$(_has_post '"proxied":false' && echo 0 || echo 1)" '"proxied":false' "$POSTS"
    _assert "Does not prompt without a terminal" "$(! _has_output 'TTL (auto or seconds)' && echo 0 || echo 1)"

    _run_cli '' add record example.com A www 203.0.113.10 --ttl auto --proxy yes
    _assert "auto becomes ttl 1" "$(_has_post '"ttl":1' && echo 0 || echo 1)" '"ttl":1' "$POSTS"
    _assert "yes becomes proxied true" "$(_has_post '"proxied":true' && echo 0 || echo 1)" '"proxied":true' "$POSTS"

    _run_cli '' add record example.com CNAME blog example.com --ttl=120 --proxy=false
    _assert "Equals form sets ttl 120" "$(_has_post '"ttl":120' && echo 0 || echo 1)" '"ttl":120' "$POSTS"
    _assert "false alias becomes proxied false" "$(_has_post '"proxied":false' && echo 0 || echo 1)" '"proxied":false' "$POSTS"
}

# =============================================================================
# Test: non-interactive defaults
# =============================================================================

test_noninteractive_defaults() {
    _test_section "No terminal and no flags takes auto/yes"
    CASE_TTY=0
    _run_cli '' add record example.com A www 203.0.113.10

    _assert "Exits 0" "$([[ $RC -eq 0 ]] && echo 0 || echo 1)" "exit 0" "exit $RC"
    _assert "Defaults to ttl 1" "$(_has_post '"ttl":1' && echo 0 || echo 1)" '"ttl":1' "$POSTS"
    _assert "Defaults to proxied true" "$(_has_post '"proxied":true' && echo 0 || echo 1)" '"proxied":true' "$POSTS"
    _assert "Never prompts" "$(! _has_output 'TTL (auto or seconds)' && ! _has_output 'Proxy through Cloudflare' && echo 0 || echo 1)"

    CASE_TTY=1
    _run_cli '' -y add record example.com A www 203.0.113.10
    _assert "-y skips the TTL prompt" "$(! _has_output 'TTL (auto or seconds)' && echo 0 || echo 1)"
    _assert "-y skips the proxy prompt" "$(! _has_output 'Proxy through Cloudflare' && echo 0 || echo 1)"
    _assert "-y still sends the defaults" "$(_has_post '"ttl":1' && _has_post '"proxied":true' && echo 0 || echo 1)" '"ttl":1 + "proxied":true' "$POSTS"
}

# =============================================================================
# Test: interactive prompts
# =============================================================================

test_prompts() {
    _test_section "Prompts accept Enter for the default"
    CASE_TTY=1
    _run_cli '\n\n' add record example.com A www 203.0.113.10

    _assert "Exits 0" "$([[ $RC -eq 0 ]] && echo 0 || echo 1)" "exit 0" "exit $RC"
    _assert "Prompts for TTL" "$(_has_output 'TTL (auto or seconds) [auto]:' && echo 0 || echo 1)"
    _assert "Prompts for proxy" "$(_has_output 'Proxy through Cloudflare? (yes/no) [yes]:' && echo 0 || echo 1)"
    _assert "Empty answer takes auto" "$(_has_post '"ttl":1' && echo 0 || echo 1)" '"ttl":1' "$POSTS"
    _assert "Empty answer takes yes" "$(_has_post '"proxied":true' && echo 0 || echo 1)" '"proxied":true' "$POSTS"

    _test_section "Prompted values reach the payload"
    _run_cli '120\nno\n' add record example.com A www 203.0.113.10
    _assert "Typed TTL is used" "$(_has_post '"ttl":120' && echo 0 || echo 1)" '"ttl":120' "$POSTS"
    _assert "Typed proxy answer is used" "$(_has_post '"proxied":false' && echo 0 || echo 1)" '"proxied":false' "$POSTS"
}

# =============================================================================
# Test: invalid values stop before the API
# =============================================================================

test_invalid_values() {
    _test_section "Invalid values fail before any request"
    CASE_TTY=0

    _run_cli '' add record example.com A www 203.0.113.10 --ttl banana
    _assert "Invalid TTL exits non-zero" "$([[ $RC -ne 0 ]] && echo 0 || echo 1)" "non-zero" "exit $RC"
    _assert "Invalid TTL names the value" "$(_has_output "Invalid ttl 'banana'" && echo 0 || echo 1)"
    _assert "Invalid TTL sends nothing" "$([[ $CALLS -eq 0 ]] && echo 0 || echo 1)" "0 POST" "$CALLS POST"

    _run_cli '' add record example.com A www 203.0.113.10 --proxy maybe
    _assert "Invalid proxy exits non-zero" "$([[ $RC -ne 0 ]] && echo 0 || echo 1)" "non-zero" "exit $RC"
    _assert "Invalid proxy names the value" "$(_has_output "Invalid proxy 'maybe'" && echo 0 || echo 1)"
    _assert "Invalid proxy sends nothing" "$([[ $CALLS -eq 0 ]] && echo 0 || echo 1)" "0 POST" "$CALLS POST"
}

# =============================================================================
# Test: type-specific rules
# =============================================================================

test_types() {
    _test_section "--proxy is ignored for non-proxiable types"
    CASE_TTY=0
    _run_cli '' add record example.com TXT @ verification=abc --ttl 300 --proxy yes

    _assert "TXT still exits 0" "$([[ $RC -eq 0 ]] && echo 0 || echo 1)" "exit 0" "exit $RC"
    _assert "TXT warns about the ignored flag" "$(_has_output '--proxy is ignored for TXT records' && echo 0 || echo 1)"
    _assert "TXT keeps its TTL" "$(_has_post '"ttl":300' && echo 0 || echo 1)" '"ttl":300' "$POSTS"
    _assert "TXT payload has no proxied field" "$(_has_post '"proxied"' && echo 1 || echo 0)" "no proxied" "$POSTS"

    _test_section "MX keeps its priority after content"
    _run_cli '' add record example.com MX @ mail.example.com 10 --ttl 3600
    _assert "MX priority is sent" "$(_has_post '"priority":10' && echo 0 || echo 1)" '"priority":10' "$POSTS"
    _assert "MX TTL is numeric" "$(_has_post '"ttl":3600' && echo 0 || echo 1)" '"ttl":3600' "$POSTS"

    _test_section "SRV keeps five positionals after content"
    _run_cli '' add record example.com SRV @ sipserver.example.com 10 _sip _tcp 5 5060 --ttl 300
    _assert "SRV priority" "$(_has_post '"priority":10' && echo 0 || echo 1)" '"priority":10' "$POSTS"
    _assert "SRV service" "$(_has_post '"service":"_sip"' && echo 0 || echo 1)" '"service":"_sip"' "$POSTS"
    _assert "SRV protocol" "$(_has_post '"proto":"_tcp"' && echo 0 || echo 1)" '"proto":"_tcp"' "$POSTS"
    _assert "SRV weight" "$(_has_post '"weight":5' && echo 0 || echo 1)" '"weight":5' "$POSTS"
    _assert "SRV port" "$(_has_post '"port":5060' && echo 0 || echo 1)" '"port":5060' "$POSTS"

    _test_section "AAAA can be proxied"
    _run_cli '' add record example.com AAAA www 2001:db8::1 --ttl 60 --proxy yes
    _assert "AAAA payload is proxied" "$(_has_post '"proxied":true' && _has_post '"type":"AAAA"' && echo 0 || echo 1)" '"type":"AAAA" + "proxied":true' "$POSTS"
}

# =============================================================================
# Test: legacy positional values are rejected loudly
# =============================================================================

test_leftover_positional() {
    _test_section "Positional TTL is rejected"
    CASE_TTY=0
    _run_cli '' add record example.com A www 203.0.113.10 300

    _assert "Exits non-zero" "$([[ $RC -ne 0 ]] && echo 0 || echo 1)" "non-zero" "exit $RC"
    _assert "Names the unexpected argument" "$(_has_output "Unexpected argument '300'" && echo 0 || echo 1)"
    _assert "Sends nothing" "$([[ $CALLS -eq 0 ]] && echo 0 || echo 1)" "0 POST" "$CALLS POST"
}

# =============================================================================
# Test: help advertises the flags
# =============================================================================

test_help() {
    _test_section "Help text documents the flags"
    CASE_TTY=0
    _run_cli '' help add record

    _assert "Help exits 0" "$([[ $RC -eq 0 ]] && echo 0 || echo 1)" "exit 0" "exit $RC"
    _assert "Help shows --ttl" "$(_has_output '--ttl <auto|seconds>' && echo 0 || echo 1)"
    _assert "Help shows --proxy" "$(_has_output '--proxy <yes|no>' && echo 0 || echo 1)"
    _assert "Help drops positional ttl" "$(! _has_output '[ttl]' && echo 0 || echo 1)"
    _assert "Help drops positional proxied" "$(! _has_output '[proxied]' && echo 0 || echo 1)"
}

# =============================================================================
# Run All Tests
# =============================================================================

echo ""
echo "╔═══════════════════════════════════════════════════════════════════════════╗"
echo "║        add record --ttl / --proxy tests (flags, prompts, no network)      ║"
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

test_flags
test_noninteractive_defaults
test_prompts
test_invalid_values
test_types
test_leftover_positional
test_help

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
echo "  Failed: $TESTS_FAILED"
echo ""

[[ $TESTS_FAILED -gt 0 ]] && exit 1
exit 0
