#!/usr/bin/env bash
# Tests for skills/research-diary/scripts/diary_commit.sh

set -u
THIS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$THIS_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/skills/research-diary/scripts/diary_commit.sh"

# shellcheck disable=SC1091
. "$THIS_DIR/test_helpers.sh"
_test_reset_counters

TMP_ROOT="$THIS_DIR/tmp"
mkdir -p "$TMP_ROOT"

# --- Test: commits the named diary file with standard message ---
_test_begin "commits diary file with standard message"

SANDBOX=$(setup_tmpdir "$TMP_ROOT")
LOCAL="$SANDBOX/diary"
mkdir -p "$LOCAL/proj"
git -C "$LOCAL" init -q -b main
git -C "$LOCAL" config user.email t@t
git -C "$LOCAL" config user.name t
echo "# hello" > "$LOCAL/proj/2026-04-21.md"

DIARY_LOCAL_PATH="$LOCAL" bash "$SCRIPT" proj 2026-04-21
actual_exit=$?

msg=$(git -C "$LOCAL" log -1 --pretty=%s 2>/dev/null || echo "")

if [ $actual_exit -eq 0 ] && [ "$msg" = "diary(proj): 2026-04-21" ]; then
    _test_ok
else
    _test_fail "exit=$actual_exit; last commit subject=[$msg]"
fi

cleanup_tmpdir "$SANDBOX"

# --- Test: push succeeds when remote reachable ---
_test_begin "pushes to remote when configured and reachable"

SANDBOX=$(setup_tmpdir "$TMP_ROOT")
LOCAL="$SANDBOX/diary"
REMOTE="$SANDBOX/remote.git"

git init --bare -q -b main "$REMOTE"
mkdir -p "$LOCAL/proj"
git -C "$LOCAL" init -q -b main
git -C "$LOCAL" config user.email t@t
git -C "$LOCAL" config user.name t
git -C "$LOCAL" remote add origin "$REMOTE"
echo "# hello" > "$LOCAL/proj/2026-04-21.md"

DIARY_LOCAL_PATH="$LOCAL" bash "$SCRIPT" proj 2026-04-21
actual_exit=$?

# Confirm the commit appeared on remote
remote_has=$(git --git-dir="$REMOTE" log --oneline 2>/dev/null | wc -l | tr -d ' ')

if [ $actual_exit -eq 0 ] && [ "$remote_has" = "1" ]; then
    _test_ok
else
    _test_fail "exit=$actual_exit; remote commits=$remote_has (expected 1)"
fi

cleanup_tmpdir "$SANDBOX"

# --- Test: push failure is non-fatal (exit 0, local commit preserved) ---
_test_begin "push failure is non-fatal"

SANDBOX=$(setup_tmpdir "$TMP_ROOT")
LOCAL="$SANDBOX/diary"
mkdir -p "$LOCAL/proj"
git -C "$LOCAL" init -q -b main
git -C "$LOCAL" config user.email t@t
git -C "$LOCAL" config user.name t
# Configure an unreachable remote
git -C "$LOCAL" remote add origin "$SANDBOX/does-not-exist.git"
echo "# hello" > "$LOCAL/proj/2026-04-21.md"

DIARY_LOCAL_PATH="$LOCAL" bash "$SCRIPT" proj 2026-04-21 2>/dev/null
actual_exit=$?

# Local commit must have happened even though push failed
local_commits=$(git -C "$LOCAL" log --oneline 2>/dev/null | wc -l | tr -d ' ')

if [ $actual_exit -eq 0 ] && [ "$local_commits" = "1" ]; then
    _test_ok
else
    _test_fail "exit=$actual_exit; local_commits=$local_commits"
fi

cleanup_tmpdir "$SANDBOX"

# --- Summary ---
echo ""
echo "Passed: $TEST_PASS | Failed: $TEST_FAIL"
[ $TEST_FAIL -eq 0 ]
