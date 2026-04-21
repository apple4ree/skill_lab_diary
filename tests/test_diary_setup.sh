#!/usr/bin/env bash
# Tests for plugin/skills/research-diary/scripts/diary_setup.sh

set -u
THIS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$THIS_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/plugin/skills/research-diary/scripts/diary_setup.sh"

# shellcheck disable=SC1091
. "$THIS_DIR/test_helpers.sh"
_test_reset_counters

TMP_ROOT="$THIS_DIR/tmp"
mkdir -p "$TMP_ROOT"

# --- Test: git init when path missing ---
_test_begin "git init when target path missing"

SANDBOX=$(setup_tmpdir "$TMP_ROOT")
LOCAL="$SANDBOX/diary"

DIARY_LOCAL_PATH="$LOCAL" bash "$SCRIPT"
actual_exit=$?

if [ $actual_exit -eq 0 ] && [ -d "$LOCAL/.git" ]; then
    _test_ok
else
    _test_fail "expected git init at $LOCAL (exit=$actual_exit)"
fi

cleanup_tmpdir "$SANDBOX"

# --- Test: skip when path already a git repo ---
_test_begin "skip when target path is already a git repo"

SANDBOX=$(setup_tmpdir "$TMP_ROOT")
LOCAL="$SANDBOX/diary"
mkdir -p "$LOCAL"
git -C "$LOCAL" init -q -b main
touch "$LOCAL/marker"

DIARY_LOCAL_PATH="$LOCAL" bash "$SCRIPT"
actual_exit=$?

if [ $actual_exit -eq 0 ] && [ -f "$LOCAL/marker" ]; then
    _test_ok
else
    _test_fail "expected skip; marker missing or nonzero exit ($actual_exit)"
fi

cleanup_tmpdir "$SANDBOX"

# --- Test: error when path exists but is not a git repo ---
_test_begin "error when target path exists but is not a git repo"

SANDBOX=$(setup_tmpdir "$TMP_ROOT")
LOCAL="$SANDBOX/diary"
mkdir -p "$LOCAL"
# No git init on purpose

DIARY_LOCAL_PATH="$LOCAL" bash "$SCRIPT" 2>/dev/null
actual_exit=$?

if [ $actual_exit -eq 1 ]; then
    _test_ok
else
    _test_fail "expected exit 1, got $actual_exit"
fi

cleanup_tmpdir "$SANDBOX"

# --- Test: defaults to $(pwd)/research-diary when DIARY_LOCAL_PATH unset ---
_test_begin "defaults to \$(pwd)/research-diary when env unset"

SANDBOX=$(setup_tmpdir "$TMP_ROOT")
(
    cd "$SANDBOX"
    unset DIARY_LOCAL_PATH
    bash "$SCRIPT"
)
actual_exit=$?

if [ $actual_exit -eq 0 ] && [ -d "$SANDBOX/research-diary/.git" ]; then
    _test_ok
else
    _test_fail "expected default path init (exit=$actual_exit)"
fi

cleanup_tmpdir "$SANDBOX"

# --- Summary ---
echo ""
echo "Passed: $TEST_PASS | Failed: $TEST_FAIL"
[ $TEST_FAIL -eq 0 ]
