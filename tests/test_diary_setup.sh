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

# --- Test: DIARY_REMOTE_URL configures origin and project-named branch ---
_test_begin "DIARY_REMOTE_URL sets origin and creates project-named branch"

SANDBOX=$(setup_tmpdir "$TMP_ROOT")
PROJECT_NAME="my_proj"
PROJECT_DIR="$SANDBOX/$PROJECT_NAME"
mkdir -p "$PROJECT_DIR"
REMOTE_URL="$SANDBOX/remote.git"
git init --bare -q "$REMOTE_URL"

(
    cd "$PROJECT_DIR"
    unset DIARY_LOCAL_PATH
    DIARY_REMOTE_URL="$REMOTE_URL" bash "$SCRIPT"
)
actual_exit=$?

diary_dir="$PROJECT_DIR/research-diary"

if [ $actual_exit -ne 0 ] || [ ! -d "$diary_dir/.git" ]; then
    _test_fail "setup failed: exit=$actual_exit; diary_dir=$diary_dir"
else
    remote=$(git -C "$diary_dir" remote get-url origin 2>/dev/null || echo "")
    branch=$(git -C "$diary_dir" symbolic-ref --short HEAD 2>/dev/null || echo "")
    if [ "$remote" = "$REMOTE_URL" ] && [ "$branch" = "$PROJECT_NAME" ]; then
        _test_ok
    else
        _test_fail "remote=[$remote] (expected $REMOTE_URL); branch=[$branch] (expected $PROJECT_NAME)"
    fi
fi

cleanup_tmpdir "$SANDBOX"

# --- Test: DIARY_REMOTE_URL + .diary-project-name override wins over basename ---
_test_begin "DIARY_REMOTE_URL uses .diary-project-name override when present"

SANDBOX=$(setup_tmpdir "$TMP_ROOT")
PROJECT_DIR="$SANDBOX/ugly_dirname"
mkdir -p "$PROJECT_DIR"
echo "clean_name" > "$PROJECT_DIR/.diary-project-name"
REMOTE_URL="$SANDBOX/remote.git"
git init --bare -q "$REMOTE_URL"

(
    cd "$PROJECT_DIR"
    unset DIARY_LOCAL_PATH
    DIARY_REMOTE_URL="$REMOTE_URL" bash "$SCRIPT"
)
actual_exit=$?

diary_dir="$PROJECT_DIR/research-diary"
branch=$(git -C "$diary_dir" symbolic-ref --short HEAD 2>/dev/null || echo "")

if [ $actual_exit -eq 0 ] && [ "$branch" = "clean_name" ]; then
    _test_ok
else
    _test_fail "exit=$actual_exit; branch=[$branch] (expected clean_name)"
fi

cleanup_tmpdir "$SANDBOX"

# --- Summary ---
echo ""
echo "Passed: $TEST_PASS | Failed: $TEST_FAIL"
[ $TEST_FAIL -eq 0 ]
