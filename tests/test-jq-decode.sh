#!/usr/bin/env bash

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PARENT_DIR=$(dirname "$SCRIPT_DIR")

source "$PARENT_DIR/cf-inc.sh" 2>/dev/null
source "$PARENT_DIR/cf-inc-cf.sh" 2>/dev/null

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

_pass() {
	((TESTS_PASSED++))
	echo "  ✓ PASS: $1"
}

_fail() {
	((TESTS_FAILED++))
	echo "  ✗ FAIL: $1"
	[[ -n "$2" ]] && echo "    Expected: $2"
	[[ -n "$3" ]] && echo "    Got:      $3"
}

test_tsv_filter() {
	((TESTS_RUN++))
	local output
	output=$(printf '%s' '{"success":true,"result":{"name":"example.com","status":"active","name_servers":["ns1.example.com","ns2.example.com"]}}' | jq_decode '.result | [.name, .status, (.name_servers | join(","))] | @tsv')
	if [[ "$output" == $'example.com\tactive\tns1.example.com,ns2.example.com' ]]; then
		_pass "jq_decode supports jq filters for tabular output"
	else
		_fail "jq_decode supports jq filters for tabular output" $'example.com\tactive\tns1.example.com,ns2.example.com' "$output"
	fi
}

test_error_exit_code() {
	((TESTS_RUN++))
	local output rc
	output=$(printf '%s' '{"success":false,"errors":[{"code":1000,"message":"bad request"}]}' | jq_decode '.result')
	rc=$?
	if [[ $rc -eq 2 && "$output" == "E1000: bad request" ]]; then
		_pass "jq_decode returns exit code 2 for API errors"
	else
		_fail "jq_decode returns exit code 2 for API errors" "rc=2 and E1000: bad request" "rc=$rc output=$output"
	fi
}

test_pagination_marker() {
	((TESTS_RUN++))
	local output
	output=$(printf '%s' '{"success":true,"result":[{"id":"a"},{"id":"b"}],"result_info":{"page":1,"total_pages":2}}' | jq_decode '.result[] | .id')
	if [[ "$output" == $'!has_more\na\nb' ]]; then
		_pass "jq_decode preserves pagination marker"
	else
		_fail "jq_decode preserves pagination marker" $'!has_more\na\nb' "$output"
	fi
}

echo "Running jq_decode unit tests"
test_tsv_filter
test_error_exit_code
test_pagination_marker

echo ""
echo "Total:  $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
if [[ $TESTS_FAILED -gt 0 ]]; then
	echo "Failed: $TESTS_FAILED"
	exit 1
fi
