#!/usr/bin/env bash
# =============================================================================
# ShellCheck gate
# =============================================================================
# Runs the same report CI runs, so a finding is caught before the push instead
# of in the lint job. Findings are fixed, not excluded: a suppression is an
# inline `# shellcheck disable=SCXXXX` with its reason (see .shellcheckrc).
#
# Run: bash tests/test-lint.sh
# =============================================================================

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")
cd "$PARENT_DIR" || exit 1

# Keep this list identical to the ShellCheck step in .github/workflows/ci.yml.
FILES=(cloudflare cf-tenant cfddnsupdate cf-bulkredirect.sh
       cf-domain-search.sh cf-inc.sh cf-inc-api.sh cf-inc-cf.sh)

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

_test_pass() {
    ((TESTS_PASSED++))
    printf '\033[32m  ✓ PASS:\033[0m %s\n' "$1"
}

_test_fail() {
    ((TESTS_FAILED++))
    printf '\033[31m  ✗ FAIL:\033[0m %s\n' "$1"
    [[ -n "${2:-}" ]] && printf '         %s\n' "$2"
}

_assert() {
    # _assert <description> <condition-exit-code> [detail]
    ((TESTS_RUN++))
    if [[ "$2" -eq 0 ]]; then
        _test_pass "$1"
    else
        _test_fail "$1" "${3:-}"
    fi
}

printf '\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
printf '  ShellCheck gate\n'
printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'

if ! command -v shellcheck >/dev/null 2>&1; then
    printf '  skipped: shellcheck is not installed (CI installs it and blocks on any finding)\n\n'
    exit 0
fi

# Every linted file exists, so a rename cannot silently drop it from the gate.
for file in "${FILES[@]}" tests/*.sh; do
    _assert "exists: $file" "$([[ -f $file ]] && echo 0 || echo 1)"
done

REPORT=$(shellcheck -x "${FILES[@]}" tests/*.sh 2>&1)
_assert "the full ShellCheck report is empty" "$?" "${REPORT:-no findings}"
[[ -n "$REPORT" ]] && printf '%s\n' "$REPORT"

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
