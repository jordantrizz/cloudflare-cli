#!/usr/bin/env bash
# =============================================================================
# bash-ui integration tests
# =============================================================================
# Run: bash tests/test-bash-ui.sh
#
# Covers the vendored library, the loader in cf-inc.sh, the deprecated
# message adapters, stdout purity (data only) and the inlined copy in
# cfddnsupdate. No Cloudflare credentials or network access required.
# =============================================================================

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR" || exit 1

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

_assert() {
    local desc=$1 rc=$2 expected=$3 got=$4
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ $rc -eq 0 ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        printf '  \033[32m✓ PASS:\033[0m %s\n' "$desc"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        printf '  \033[31m✗ FAIL:\033[0m %s\n' "$desc"
        printf '          expected: %s\n          got:      %s\n' "$expected" "$got"
    fi
}

_test_section() {
    printf '\n\033[1m━━━ %s ━━━\033[0m\n' "$1"
}

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# =============================================================================
# Vendored library
# =============================================================================
_test_section "Vendored library"

( cd vendor/bash-ui && sha256sum -c ui.sh.sha256 >/dev/null 2>&1 )
_assert "vendor/bash-ui/ui.sh matches its checksum" "$?" "checksum ok" "mismatch"

LIB_VERSION=$(sed -n 's/^UI_VERSION="\(.*\)"$/\1/p' vendor/bash-ui/ui.sh)
MARKER_VERSION=$(sed -n 's/^# >>> bash-ui \(.*\) >>>$/\1/p' cfddnsupdate)
_assert "cfddnsupdate inlines the vendored version ($LIB_VERSION)" \
    "$([[ -n $LIB_VERSION && $LIB_VERSION == "$MARKER_VERSION" ]] && echo 0 || echo 1)" \
    "$LIB_VERSION" "$MARKER_VERSION"

_assert "vendor/bash-ui/ holds the library and its checksum" \
    "$([[ -f vendor/bash-ui/ui.sh && -f vendor/bash-ui/ui.sh.sha256 ]] && echo 0 || echo 1)" \
    "both files" "missing"

# =============================================================================
# Loader and deprecated adapters
# =============================================================================
_test_section "Loader in cf-inc.sh"

bash -c 'source cf-inc.sh; command -v ui_ok >/dev/null' >/dev/null 2>&1
_assert "cf-inc.sh loads the library" "$?" "ui_ok defined" "ui_ok missing"

bash -c 'source cf-inc.sh; for f in _error _warning _success _running _running2 _running3 _creating _separator _dryrun _quiet _die; do command -v "$f" >/dev/null || exit 1; done' >/dev/null 2>&1
_assert "deprecated adapters still resolve" "$?" "all adapters defined" "adapter missing"

STDOUT_LINES=$(bash -c 'source cf-inc.sh; _error boom' 2>/dev/null | wc -l | tr -d ' ')
_assert "_error writes to stderr only" \
    "$([[ $STDOUT_LINES -eq 0 ]] && echo 0 || echo 1)" "0 stdout lines" "$STDOUT_LINES stdout lines"

bash -c 'source cf-inc.sh; _die nope 7' >/dev/null 2>&1
RC=$?
_assert "_die exits with the requested code" \
    "$([[ $RC -eq 7 ]] && echo 0 || echo 1)" "exit 7" "exit $RC"

QUIET_DATA=$(bash -c 'source cf-inc.sh; QUIET=1; _quiet "data-line"' 2>/dev/null)
_assert "_quiet still emits data on stdout when quiet is on" \
    "$([[ $QUIET_DATA == "data-line" ]] && echo 0 || echo 1)" "data-line" "$QUIET_DATA"

# =============================================================================
# stdout purity
# =============================================================================
_test_section "stdout purity"

bash cloudflare help > "$TMP_DIR/help.out" 2> "$TMP_DIR/help.err"
RC=$?

_assert "cloudflare help exits 0" "$([[ $RC -eq 0 ]] && echo 0 || echo 1)" "exit 0" "exit $RC"
_assert "help text is still on stdout" \
    "$(grep -q 'Usage: cloudflare' "$TMP_DIR/help.out" && echo 0 || echo 1)" \
    "Usage found" "usage missing"
_assert "no library banner on stdout" \
    "$(! grep -q 'Cloudflare API Library' "$TMP_DIR/help.out" && echo 0 || echo 1)" \
    "banner absent" "banner leaked to stdout"
_assert "no ANSI escape on stdout" \
    "$(! grep -q $'\033' "$TMP_DIR/help.out" && echo 0 || echo 1)" \
    "no escapes" "escape found"
_assert "the banner is on stderr" \
    "$(grep -q 'bash-ui' "$TMP_DIR/help.err" && echo 0 || echo 1)" \
    "bash-ui banner" "banner missing"
_assert "the running step is on stderr" \
    "$(grep -q 'Running: help' "$TMP_DIR/help.err" && echo 0 || echo 1)" \
    "step present" "step missing"

UI_COLOR=always bash cloudflare help > "$TMP_DIR/color.out" 2> "$TMP_DIR/color.err"
_assert "UI_COLOR=always colours stderr only" \
    "$(grep -q $'\033' "$TMP_DIR/color.err" && ! grep -q $'\033' "$TMP_DIR/color.out" && echo 0 || echo 1)" \
    "colour on stderr, none on stdout" "colour misplaced"

bash cloudflare -q help > /dev/null 2> "$TMP_DIR/quiet.err"
_assert "UI_QUIET suppresses the step lines" \
    "$([[ ! -s $TMP_DIR/quiet.err ]] && echo 0 || echo 1)" "empty stderr" "$(wc -l < "$TMP_DIR/quiet.err") lines"

NO_COLOR=1 bash cloudflare help > /dev/null 2> "$TMP_DIR/nocolor.err"
NO_COLOR_STATUS=$?
_assert "NO_COLOR=1 exits 0 with no escapes" \
    "$([[ $NO_COLOR_STATUS -eq 0 ]] && ! grep -q $'\033' "$TMP_DIR/nocolor.err" && echo 0 || echo 1)" \
    "clean" "escape found"

UI_ASCII=1 bash cloudflare help > /dev/null 2> "$TMP_DIR/ascii.err"
UI_ASCII_STATUS=$?
_assert "UI_ASCII=1 exits 0 with no escapes" \
    "$([[ $UI_ASCII_STATUS -eq 0 ]] && ! grep -q $'\033' "$TMP_DIR/ascii.err" && echo 0 || echo 1)" \
    "clean" "escape found"

# Data stays on stdout for a command that prints a table.
bash cf-tenant --cf > "$TMP_DIR/cf.out" 2> /dev/null
_assert "cf-tenant --cf keeps its table on stdout" \
    "$(head -1 "$TMP_DIR/cf.out" | grep -q '^Function' && echo 0 || echo 1)" \
    "Function header" "$(head -1 "$TMP_DIR/cf.out")"

# Search results are data; the progress lines are not.
bash cf-domain-search.sh -t -f tests/domains.txt > "$TMP_DIR/search.out" 2> "$TMP_DIR/search.err"
_assert "domain search results stay on stdout" \
    "$(grep -q ' - FOUND$' "$TMP_DIR/search.out" && echo 0 || echo 1)" \
    "FOUND lines" "no results"
_assert "domain search progress stays off stdout" \
    "$(! grep -q 'Getting list of domains' "$TMP_DIR/search.out" && echo 0 || echo 1)" \
    "no progress on stdout" "progress leaked"
_assert "piped domain search output is plain text" \
    "$(! grep -q $'\033' "$TMP_DIR/search.out" && echo 0 || echo 1)" \
    "no escapes" "escape found"

# =============================================================================
# Inlined region
# =============================================================================
_test_section "cfddnsupdate inline region"

sed -n '/^# >>> bash-ui/,/^# <<< bash-ui/p' cfddnsupdate | sed '1d;$d' > "$TMP_DIR/inline.sh"
cmp -s "$TMP_DIR/inline.sh" vendor/bash-ui/ui.sh
_assert "the inlined region matches vendor/bash-ui/ui.sh" "$?" "identical" "drifted"

bash -c 'source <(sed -n "/^# >>> bash-ui/,/^# <<< bash-ui/p" cfddnsupdate); ui_ok inline' >/dev/null 2>&1
_assert "the inlined region is self-contained" "$?" "ui_ok works" "broken region"

# =============================================================================
# Results
# =============================================================================
printf '\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
printf '  Total:  %s\n' "$TESTS_RUN"
printf '  \033[32mPassed: %s\033[0m\n' "$TESTS_PASSED"
if [[ $TESTS_FAILED -gt 0 ]]; then
    printf '  \033[31mFailed: %s\033[0m\n' "$TESTS_FAILED"
    exit 1
fi
printf '\n'
exit 0
