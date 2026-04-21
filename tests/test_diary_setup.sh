#!/usr/bin/env bash
# Tests for skills/research-diary/scripts/diary_setup.sh

set -u
THIS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$THIS_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/plugin/skills/research-diary/scripts/diary_setup.sh"

# shellcheck disable=SC1091
. "$THIS_DIR/test_helpers.sh"
_test_reset_counters

TMP_ROOT="$THIS_DIR/tmp"
mkdir -p "$TMP_ROOT"

# --- Test: clones from remote when local path missing and remote set ---
_test_begin "clones remote into DIARY_LOCAL_PATH when path missing"

SANDBOX=$(setup_tmpdir "$TMP_ROOT")
REMOTE="$SANDBOX/remote.git"
LOCAL="$SANDBOX/diary"

# Build a bare remote with one commit so clone succeeds
git init --bare -q -b main "$REMOTE"
SEED="$SANDBOX/seed"
git init -q -b main "$SEED"
( cd "$SEED" && git -c user.email=t@t -c user.name=t commit --allow-empty -q -m init \
    && git remote add origin "$REMOTE" \
    && git push -q origin main )

DIARY_LOCAL_PATH="$LOCAL" DIARY_GIT_REMOTE="$REMOTE" bash "$SCRIPT"
actual_exit=$?

if [ $actual_exit -eq 0 ] && [ -d "$LOCAL/.git" ]; then
    _test_ok
else
    _test_fail "expected clone to create git repo at $LOCAL (exit=$actual_exit)"
fi

cleanup_tmpdir "$SANDBOX"

# --- Test: git init when path missing and no remote set ---
_test_begin "git init when DIARY_GIT_REMOTE unset"

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
_test_begin "skip when local path is already a git repo"

SANDBOX=$(setup_tmpdir "$TMP_ROOT")
LOCAL="$SANDBOX/diary"
mkdir -p "$LOCAL"
git -C "$LOCAL" init -q -b main
# Mark so we can detect re-init
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
_test_begin "error when path exists but is not a git repo"

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

# --- Summary ---
echo ""
echo "Passed: $TEST_PASS | Failed: $TEST_FAIL"
[ $TEST_FAIL -eq 0 ]
