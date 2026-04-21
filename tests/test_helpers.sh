#!/usr/bin/env bash
# Minimal assertion helpers for shell-script tests.
# Each test file sources this, then calls assert_* and tracks failures.

set -u

TEST_PASS=0
TEST_FAIL=0
TEST_CURRENT_NAME=""

_test_reset_counters() {
    TEST_PASS=0
    TEST_FAIL=0
}

_test_begin() {
    TEST_CURRENT_NAME="$1"
    printf '  %s ... ' "$TEST_CURRENT_NAME"
}

_test_ok() {
    TEST_PASS=$((TEST_PASS + 1))
    printf 'OK\n'
}

_test_fail() {
    TEST_FAIL=$((TEST_FAIL + 1))
    printf 'FAIL\n    %s\n' "$1"
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local label="${3:-values}"
    if [ "$expected" = "$actual" ]; then
        _test_ok
    else
        _test_fail "$label: expected [$expected], got [$actual]"
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    if [ "$expected" = "$actual" ]; then
        _test_ok
    else
        _test_fail "exit code: expected $expected, got $actual"
    fi
}

assert_file_exists() {
    local path="$1"
    if [ -f "$path" ]; then
        _test_ok
    else
        _test_fail "expected file to exist: $path"
    fi
}

assert_dir_is_git_repo() {
    local path="$1"
    if [ -d "$path/.git" ]; then
        _test_ok
    else
        _test_fail "expected git repo at: $path"
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    case "$haystack" in
        *"$needle"*) _test_ok ;;
        *) _test_fail "expected [$haystack] to contain [$needle]" ;;
    esac
}

setup_tmpdir() {
    local root="$1"
    mkdir -p "$root"
    mktemp -d "$root/run.XXXXXX"
}

cleanup_tmpdir() {
    local path="$1"
    [ -n "$path" ] && [ -d "$path" ] && rm -rf "$path"
}
