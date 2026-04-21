# Research Diary Plugin Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code plugin (`research-diary-plugin`) that writes structured per-project research diaries from the current session, stores them locally in a git-tracked directory, and pushes to a configured GitHub repo.

**Architecture:** Plugin with a single skill `research-diary`. The skill (`SKILL.md`) orchestrates: detect project name → ensure local diary repo exists → read existing diary if any → merge current session's content via rules in `references/merge_rules.md` → write file → commit & push via `scripts/diary_commit.sh`. Local directory itself is a git clone of the configured remote — local accumulation and remote push share the same repo.

**Tech Stack:** Bash (POSIX-friendly) for scripts, Markdown + YAML frontmatter for diary files, plain shell-script test harness (no external deps). Plugin manifest format per Claude Code plugin spec.

---

## Design Spec

Reference: `docs/superpowers/specs/2026-04-21-research-diary-plugin-design.md`

## File Structure

Plugin repo root layout:

```
skill_lab_diary/                               # repo root
├── .claude-plugin/
│   └── plugin.json                            # plugin manifest (required path)
├── README.md                                  # install + config guide
├── .gitignore                                 # excludes test tmp dirs
├── skills/
│   └── research-diary/
│       ├── SKILL.md                           # /research-diary entry + procedure
│       ├── scripts/
│       │   ├── diary_setup.sh                 # init local diary repo (clone or init)
│       │   └── diary_commit.sh                # git add + commit + push helper
│       └── references/
│           ├── diary_format.md                # field template + examples
│           ├── merge_rules.md                 # §5 merge rules in detail
│           └── test_scenarios.md              # manual regression scenarios
├── tests/
│   ├── test_helpers.sh                        # shell assertion helpers
│   ├── run_tests.sh                           # runs all test_*.sh, aggregates
│   ├── test_diary_setup.sh                    # bash tests for diary_setup.sh
│   └── test_diary_commit.sh                   # bash tests for diary_commit.sh
└── docs/
    └── superpowers/
        ├── specs/2026-04-21-research-diary-plugin-design.md
        └── plans/2026-04-21-research-diary-plugin.md          # this file
```

### Responsibilities

| File | Responsibility |
|---|---|
| `.claude-plugin/plugin.json` | Declare plugin name, version, description. `./skills/` is auto-discovered — no explicit `skills` field needed |
| `skills/research-diary/SKILL.md` | Instructions for Claude: when to activate, procedure to follow, which references to read |
| `scripts/diary_setup.sh` | Idempotent: ensure `$DIARY_LOCAL_PATH` exists and is a git repo. Clone remote if available; else `git init`. Error if dir exists but isn't a repo |
| `scripts/diary_commit.sh` | `cd` into diary path, `git add` specific file, commit with standard message, attempt push. Push failure non-fatal |
| `references/diary_format.md` | Authoritative field list, frontmatter schema, canonical example |
| `references/merge_rules.md` | Detailed decision tree for Case A (new) vs Case B (merge) + modification-proposal flow |
| `references/test_scenarios.md` | Human-run regression scenarios for merge logic |
| `tests/test_helpers.sh` | `assert_eq`, `assert_exit_code`, `setup_tmpdir`, `cleanup_tmpdir` |
| `tests/test_diary_setup.sh` | TDD coverage for the four setup branches |
| `tests/test_diary_commit.sh` | TDD coverage for commit + push success/failure |

---

## Task 1: Scaffold plugin layout and manifest

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.gitignore`
- Create: `skills/research-diary/` (directory)
- Create: `skills/research-diary/scripts/` (directory)
- Create: `skills/research-diary/references/` (directory)
- Create: `tests/` (directory)

- [ ] **Step 1: Create `.gitignore`**

Write `.gitignore`:

```
# Research diary backup files (per spec §5 step 7)
*.bak

# Test temporary directories
tests/tmp/

# macOS/editor noise
.DS_Store
*.swp
```

- [ ] **Step 2: Create the manifest at the required path**

Run:

```bash
mkdir -p .claude-plugin
```

Write `.claude-plugin/plugin.json`:

```json
{
  "name": "research-diary-plugin",
  "version": "0.1.0",
  "description": "Structured per-project research diaries written from Claude Code sessions, pushed to a personal GitHub repo.",
  "author": {
    "name": "Lab research tooling"
  }
}
```

Note: `./skills/` is auto-discovered by Claude Code; no explicit `skills` field needed.

- [ ] **Step 3: Create directory placeholders**

Run:

```bash
mkdir -p skills/research-diary/scripts skills/research-diary/references tests
```

- [ ] **Step 4: Verify layout**

Run:

```bash
find . -type d -not -path './.git*' -not -path './docs*' | sort
```

Expected output includes:

```
.
./.claude-plugin
./skills
./skills/research-diary
./skills/research-diary/references
./skills/research-diary/scripts
./tests
```

- [ ] **Step 5: Commit**

```bash
git add .gitignore .claude-plugin/plugin.json
git commit -m "feat: scaffold research-diary plugin manifest and layout"
```

---

## Task 2: Build test harness

**Files:**
- Create: `tests/test_helpers.sh`
- Create: `tests/run_tests.sh`

- [ ] **Step 1: Create `tests/test_helpers.sh`**

Write `tests/test_helpers.sh`:

```bash
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
```

- [ ] **Step 2: Create `tests/run_tests.sh`**

Write `tests/run_tests.sh`:

```bash
#!/usr/bin/env bash
# Run every tests/test_*.sh file and aggregate pass/fail counts.

set -u

THIS_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL_PASS=0
TOTAL_FAIL=0
FAILED_FILES=()

for f in "$THIS_DIR"/test_*.sh; do
    [ -e "$f" ] || continue
    echo "=== $(basename "$f") ==="
    if bash "$f"; then
        # shellcheck disable=SC1090
        file_pass=$(bash -c "source '$f' >/dev/null 2>&1; echo \$TEST_PASS" 2>/dev/null || echo 0)
        file_fail=$(bash -c "source '$f' >/dev/null 2>&1; echo \$TEST_FAIL" 2>/dev/null || echo 0)
    else
        FAILED_FILES+=("$(basename "$f")")
    fi
done

# Simpler aggregation: each test_*.sh prints its own summary; this script just
# surfaces file-level exit status.
echo ""
if [ ${#FAILED_FILES[@]} -eq 0 ]; then
    echo "All test files passed."
    exit 0
else
    echo "Test files with failures:"
    printf '  - %s\n' "${FAILED_FILES[@]}"
    exit 1
fi
```

- [ ] **Step 3: Make scripts executable**

Run:

```bash
chmod +x tests/test_helpers.sh tests/run_tests.sh
```

- [ ] **Step 4: Verify harness runs cleanly with no test files yet**

Run:

```bash
bash tests/run_tests.sh
```

Expected: `All test files passed.` (no `test_*.sh` files exist yet except `test_helpers.sh` which is filtered by naming convention — it does match `test_*` though, so actually rename check needed).

Adjust: Edit `tests/run_tests.sh` to exclude `test_helpers.sh` explicitly. Change the loop:

```bash
for f in "$THIS_DIR"/test_*.sh; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in
        test_helpers.sh) continue ;;
    esac
    echo "=== $(basename "$f") ==="
    ...
```

Re-run:

```bash
bash tests/run_tests.sh
```

Expected: `All test files passed.`

- [ ] **Step 5: Commit**

```bash
git add tests/test_helpers.sh tests/run_tests.sh
git commit -m "test: add shell-script test harness with assertion helpers"
```

---

## Task 3: TDD `diary_setup.sh` — clone branch

**Files:**
- Create: `tests/test_diary_setup.sh`
- Create: `skills/research-diary/scripts/diary_setup.sh`

Spec reference: §6 `diary_setup.sh` — "존재 안 함 + remote 있음 → `git clone`".

- [ ] **Step 1: Write the failing test**

Write `tests/test_diary_setup.sh`:

```bash
#!/usr/bin/env bash
# Tests for skills/research-diary/scripts/diary_setup.sh

set -u
THIS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$THIS_DIR/.." && pwd)"
SCRIPT="$REPO_ROOT/skills/research-diary/scripts/diary_setup.sh"

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
git init --bare -q "$REMOTE"
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

# --- Summary ---
echo ""
echo "Passed: $TEST_PASS | Failed: $TEST_FAIL"
[ $TEST_FAIL -eq 0 ]
```

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x tests/test_diary_setup.sh
bash tests/test_diary_setup.sh
```

Expected: FAIL because `skills/research-diary/scripts/diary_setup.sh` does not exist yet. Exit code non-zero.

- [ ] **Step 3: Write minimal implementation (clone branch only)**

Write `skills/research-diary/scripts/diary_setup.sh`:

```bash
#!/usr/bin/env bash
# Ensure the local diary directory exists and is a git repository.
# Env:
#   DIARY_LOCAL_PATH  (default: ~/research-diary)
#   DIARY_GIT_REMOTE  (optional; if set and local path absent, clone from it)

set -u

local_path="${DIARY_LOCAL_PATH:-$HOME/research-diary}"
remote="${DIARY_GIT_REMOTE:-}"

if [ ! -e "$local_path" ]; then
    if [ -n "$remote" ]; then
        git clone "$remote" "$local_path"
        exit $?
    fi
fi

exit 0
```

- [ ] **Step 4: Make executable and run test**

```bash
chmod +x skills/research-diary/scripts/diary_setup.sh
bash tests/test_diary_setup.sh
```

Expected: `Passed: 1 | Failed: 0`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add tests/test_diary_setup.sh skills/research-diary/scripts/diary_setup.sh
git commit -m "feat(setup): clone diary repo from DIARY_GIT_REMOTE when path missing"
```

---

## Task 4: `diary_setup.sh` — init branch

Spec reference: §6 `diary_setup.sh` — "존재 안 함 + remote 없음 → `mkdir -p && git init`".

- [ ] **Step 1: Add failing test**

Append to `tests/test_diary_setup.sh` **before the summary block** (`echo ""; echo "Passed: ..."`):

```bash
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
```

- [ ] **Step 2: Run to verify failure**

```bash
bash tests/test_diary_setup.sh
```

Expected: second test fails (`expected git init at ...`).

- [ ] **Step 3: Extend implementation**

Replace body of `skills/research-diary/scripts/diary_setup.sh`:

```bash
#!/usr/bin/env bash
# Ensure the local diary directory exists and is a git repository.
# Env:
#   DIARY_LOCAL_PATH  (default: ~/research-diary)
#   DIARY_GIT_REMOTE  (optional; if set and local path absent, clone from it)

set -u

local_path="${DIARY_LOCAL_PATH:-$HOME/research-diary}"
remote="${DIARY_GIT_REMOTE:-}"

if [ ! -e "$local_path" ]; then
    if [ -n "$remote" ]; then
        git clone "$remote" "$local_path"
        exit $?
    fi
    mkdir -p "$local_path"
    git -C "$local_path" init -q -b main
    exit $?
fi

exit 0
```

- [ ] **Step 4: Run test to verify pass**

```bash
bash tests/test_diary_setup.sh
```

Expected: `Passed: 2 | Failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add tests/test_diary_setup.sh skills/research-diary/scripts/diary_setup.sh
git commit -m "feat(setup): git init local diary when no remote configured"
```

---

## Task 5: `diary_setup.sh` — idempotent skip branch

Spec reference: §6 `diary_setup.sh` — "이미 존재하고 git repo면 skip".

- [ ] **Step 1: Add failing test**

Append to `tests/test_diary_setup.sh` before the summary block:

```bash
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
```

- [ ] **Step 2: Run test**

```bash
bash tests/test_diary_setup.sh
```

Expected: this test PASSES already because current implementation's `if [ ! -e "$local_path" ]` skips the block when path exists. Verify that's the case. If it fails unexpectedly, debug.

(TDD note: this case is already covered by existing code structure — verify it, no code change needed. This is a guard test.)

- [ ] **Step 3: Commit test addition**

```bash
git add tests/test_diary_setup.sh
git commit -m "test(setup): guard that existing git repo is not re-initialized"
```

---

## Task 6: `diary_setup.sh` — exists-but-not-repo error branch

Spec reference: §6 `diary_setup.sh` — "존재하지만 git repo 아니면 exit 1 + 에러 메시지".

- [ ] **Step 1: Add failing test**

Append to `tests/test_diary_setup.sh` before the summary block:

```bash
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
```

- [ ] **Step 2: Run to verify failure**

```bash
bash tests/test_diary_setup.sh
```

Expected: this test fails — current implementation exits 0 when path exists.

- [ ] **Step 3: Extend implementation**

Replace body of `skills/research-diary/scripts/diary_setup.sh`:

```bash
#!/usr/bin/env bash
# Ensure the local diary directory exists and is a git repository.
# Env:
#   DIARY_LOCAL_PATH  (default: ~/research-diary)
#   DIARY_GIT_REMOTE  (optional; if set and local path absent, clone from it)

set -u

local_path="${DIARY_LOCAL_PATH:-$HOME/research-diary}"
remote="${DIARY_GIT_REMOTE:-}"

if [ ! -e "$local_path" ]; then
    if [ -n "$remote" ]; then
        git clone "$remote" "$local_path"
        exit $?
    fi
    mkdir -p "$local_path"
    git -C "$local_path" init -q -b main
    exit $?
fi

# Path exists; verify it is a git repo
if [ -d "$local_path/.git" ] || git -C "$local_path" rev-parse --git-dir >/dev/null 2>&1; then
    exit 0
fi

echo "diary_setup: $local_path exists but is not a git repository" >&2
exit 1
```

- [ ] **Step 4: Run test**

```bash
bash tests/test_diary_setup.sh
```

Expected: `Passed: 4 | Failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add tests/test_diary_setup.sh skills/research-diary/scripts/diary_setup.sh
git commit -m "feat(setup): exit 1 when diary path exists but is not a git repo"
```

---

## Task 7: TDD `diary_commit.sh` — local commit

**Files:**
- Create: `tests/test_diary_commit.sh`
- Create: `skills/research-diary/scripts/diary_commit.sh`

Spec reference: §6 `diary_commit.sh` — "cd → `git add` → commit message `diary(<project>): <date>` → attempt push".

- [ ] **Step 1: Write the failing test**

Write `tests/test_diary_commit.sh`:

```bash
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

# --- Summary ---
echo ""
echo "Passed: $TEST_PASS | Failed: $TEST_FAIL"
[ $TEST_FAIL -eq 0 ]
```

- [ ] **Step 2: Run to verify failure**

```bash
chmod +x tests/test_diary_commit.sh
bash tests/test_diary_commit.sh
```

Expected: FAIL (script does not exist).

- [ ] **Step 3: Write minimal implementation**

Write `skills/research-diary/scripts/diary_commit.sh`:

```bash
#!/usr/bin/env bash
# Commit and (optionally) push a diary file to the local diary repo.
# Usage: diary_commit.sh <project> <YYYY-MM-DD>
# Env:
#   DIARY_LOCAL_PATH  (default: ~/research-diary)
#
# Exit codes:
#   0 on successful local commit (push failure does NOT fail this script)
#   non-zero on local commit failure or misuse

set -u

if [ $# -ne 2 ]; then
    echo "usage: diary_commit.sh <project> <YYYY-MM-DD>" >&2
    exit 2
fi

project="$1"
date="$2"
local_path="${DIARY_LOCAL_PATH:-$HOME/research-diary}"
rel_path="$project/$date.md"

if [ ! -d "$local_path/.git" ]; then
    echo "diary_commit: not a git repo: $local_path" >&2
    exit 1
fi

cd "$local_path" || exit 1

if [ ! -f "$rel_path" ]; then
    echo "diary_commit: file not found: $rel_path" >&2
    exit 1
fi

git add "$rel_path"
git commit -q -m "diary($project): $date" || exit 1

exit 0
```

- [ ] **Step 4: Make executable and run test**

```bash
chmod +x skills/research-diary/scripts/diary_commit.sh
bash tests/test_diary_commit.sh
```

Expected: `Passed: 1 | Failed: 0`.

- [ ] **Step 5: Commit**

```bash
git add tests/test_diary_commit.sh skills/research-diary/scripts/diary_commit.sh
git commit -m "feat(commit): commit diary file with standard message"
```

---

## Task 8: `diary_commit.sh` — push attempt + push-failure tolerance

Spec reference: §6 `diary_commit.sh` — "`git push` 시도 — 실패해도 exit 0, 경고만 stderr로 출력".

- [ ] **Step 1: Add failing test (push success)**

Append to `tests/test_diary_commit.sh` before the summary block:

```bash
# --- Test: push succeeds when remote reachable ---
_test_begin "pushes to remote when configured and reachable"

SANDBOX=$(setup_tmpdir "$TMP_ROOT")
LOCAL="$SANDBOX/diary"
REMOTE="$SANDBOX/remote.git"

git init --bare -q "$REMOTE"
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
```

- [ ] **Step 2: Run test**

```bash
bash tests/test_diary_commit.sh
```

Expected: fail — current implementation does not push.

- [ ] **Step 3: Extend implementation to push**

Replace body of `skills/research-diary/scripts/diary_commit.sh`:

```bash
#!/usr/bin/env bash
# Commit and (optionally) push a diary file to the local diary repo.
# Usage: diary_commit.sh <project> <YYYY-MM-DD>
# Env:
#   DIARY_LOCAL_PATH  (default: ~/research-diary)
#
# Exit codes:
#   0 on successful local commit (push failure does NOT fail this script)
#   non-zero on local commit failure or misuse

set -u

if [ $# -ne 2 ]; then
    echo "usage: diary_commit.sh <project> <YYYY-MM-DD>" >&2
    exit 2
fi

project="$1"
date="$2"
local_path="${DIARY_LOCAL_PATH:-$HOME/research-diary}"
rel_path="$project/$date.md"

if [ ! -d "$local_path/.git" ]; then
    echo "diary_commit: not a git repo: $local_path" >&2
    exit 1
fi

cd "$local_path" || exit 1

if [ ! -f "$rel_path" ]; then
    echo "diary_commit: file not found: $rel_path" >&2
    exit 1
fi

git add "$rel_path"
git commit -q -m "diary($project): $date" || exit 1

# Attempt push if a remote is configured; never fail the script on push error
if git remote | grep -q .; then
    remote_name=$(git remote | head -1)
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if ! git push -q "$remote_name" "$current_branch" 2>/dev/null; then
        echo "diary_commit: push to $remote_name failed (commit kept locally)" >&2
    fi
fi

exit 0
```

- [ ] **Step 4: Run test to verify pass**

```bash
bash tests/test_diary_commit.sh
```

Expected: `Passed: 2 | Failed: 0`.

- [ ] **Step 5: Add failing test for push-failure tolerance**

Append to `tests/test_diary_commit.sh` before the summary block:

```bash
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
```

- [ ] **Step 6: Run test to verify pass**

```bash
bash tests/test_diary_commit.sh
```

Expected: `Passed: 3 | Failed: 0` — implementation from Step 3 already suppresses push failure.

- [ ] **Step 7: Commit**

```bash
git add tests/test_diary_commit.sh skills/research-diary/scripts/diary_commit.sh
git commit -m "feat(commit): push to remote and tolerate push failure"
```

---

## Task 9: Run full test suite end-to-end

- [ ] **Step 1: Run aggregated test runner**

```bash
bash tests/run_tests.sh
```

Expected: `All test files passed.`

If any failures, fix before proceeding. Do not mark this task complete until clean.

- [ ] **Step 2: No commit needed** — verification step only.

---

## Task 10: Write `references/diary_format.md`

**Files:**
- Create: `skills/research-diary/references/diary_format.md`

Spec reference: §4 일지 파일 포맷.

- [ ] **Step 1: Write the reference file**

Write `skills/research-diary/references/diary_format.md`:

```markdown
# Diary File Format

Canonical specification of a per-day diary file. Used by `SKILL.md` as the authoritative template.

## Path

```
${DIARY_LOCAL_PATH}/<project>/<YYYY-MM-DD>.md
```

- `DIARY_LOCAL_PATH` default: `~/research-diary`
- `<project>`: basename of the current working directory, OR the content of `.diary-project-name` if that file exists in the working directory
- `<YYYY-MM-DD>`: local date at write time

## File Structure

A diary file has YAML frontmatter followed by Markdown sections.

### Frontmatter Schema

```yaml
---
date: 2026-04-21              # YYYY-MM-DD, local date
project: skill_lab_diary      # project identifier
server: dgu-workstation       # `hostname` output at write time
work_hours:                   # list of "HH:MM - HH:MM" ranges; best-effort heuristic
  - 09:12 - 11:40
  - 14:03 - 17:25
sessions: 2                   # number of /research-diary invocations today
---
```

**Heuristic for `work_hours`:** best-effort estimate. Prefer, in order:
1. First user message timestamp from the current Claude Code session jsonl (under `~/.claude/projects/`), if readable
2. File mtime of the current session jsonl as the session start
3. Omit the field if neither works

End time is always "now" (time of `/research-diary` invocation).

### Section Schema

Use `##` headings. **Omit any section whose content is empty** — do not leave "- (none)" placeholders.

Order must be exactly:

1. `## Goal (오늘의 목표)` — 1–3 items carried from yesterday's Next
2. `## Hypothesis (가설)` — what this session tried to verify
3. `## Experiments (실험)` — config / dataset version / seed; enough to re-run
4. `## Done (실제로 한 일)` — time-ordered or topic-ordered bullets
5. `## Results (결과)` — numbers/plots + interpretation. No interpretation = not a diary
6. `## Decisions & Rationale (결정과 이유)` — prevents "why did I do this?" 3 months later
7. `## Discarded / Negative Results (버린 것)` — failed approaches + why (paper limitation/future-work seed)
8. `## Blockers (막힌 점)` — explicit and separate; first thing to look at tomorrow
9. `## Next (다음 액션)` — concrete task to start tomorrow

## Top-Level Heading

File starts with the frontmatter, then one H1:

```markdown
# 2026-04-21 — skill_lab_diary
```

(`# <date> — <project>`)

## Canonical Example

```markdown
---
date: 2026-04-21
project: skill_lab_diary
server: dgu-workstation
work_hours:
  - 14:03 - 17:25
sessions: 1
---

# 2026-04-21 — skill_lab_diary

## Goal (오늘의 목표)
- Ship v0.1 of the research-diary plugin scaffold.

## Done (실제로 한 일)
- Wrote plugin.json and directory layout.
- TDD'd diary_setup.sh for all four branches.
- Wrote diary_commit.sh with push-failure tolerance.

## Decisions & Rationale (결정과 이유)
- Used plain bash tests over bats — avoids external dependency for lab users.
- Push failure is non-fatal so offline sessions still preserve local diary.

## Blockers (막힌 점)
- None.

## Next (다음 액션)
- Write SKILL.md orchestration procedure.
```
```

- [ ] **Step 2: Commit**

```bash
git add skills/research-diary/references/diary_format.md
git commit -m "docs(ref): add authoritative diary file format reference"
```

---

## Task 11: Write `references/merge_rules.md`

**Files:**
- Create: `skills/research-diary/references/merge_rules.md`

Spec reference: §5 Merge 동작.

- [ ] **Step 1: Write the reference file**

Write `skills/research-diary/references/merge_rules.md`:

```markdown
# Merge Rules for Same-Day Diary Updates

Defines how `/research-diary` behaves when invoked multiple times on the same date for the same project.

## Decision Tree

```
Does ${DIARY_LOCAL_PATH}/<project>/<today>.md exist?
├── No  → Case A (fresh write)
└── Yes → Case B (merge)
```

## Case A — Fresh Write

1. Extract field-by-field content from the current session transcript.
2. Write a new file per `diary_format.md`.
3. Frontmatter: `sessions: 1`, `work_hours` has one range, `date` is today, `project` is resolved, `server` is `hostname`.
4. Omit any section whose content is empty.

## Case B — Merge Into Existing File

### Steps

1. **Read** the existing file. Parse frontmatter and each `## ` section into an in-memory structure.
2. **Analyze** the current session transcript. Produce a set of candidate additions per section, plus a set of candidate modifications to existing items.
3. **Default rule — Append, don't rewrite:**
   - For each section, append new bullets after the existing ones. Preserve existing bullets verbatim.
   - If a section did not exist before, insert it at its canonical position per `diary_format.md`.
4. **Modification candidates — require user approval:**
   The following are NOT applied without explicit confirmation. Present them as a diff and wait for per-item approval.
   - **Resolved Blocker:** a bullet under `## Blockers` appears resolved by work in the current session. Propose: remove from Blockers, add corresponding item to Done.
   - **Completed Next:** a bullet under `## Next` appears completed in the current session. Propose: remove from Next, add to Done.
   - **Corrected Result:** a metric under `## Results` is contradicted by a re-run in the current session. Propose: update the number and note the correction.
   - **Direct contradiction:** any new content that directly contradicts an existing bullet. Propose: present both and ask which to keep.
5. **Frontmatter update:**
   - `work_hours`: append the current session's range.
   - `sessions`: increment by 1.
   - `date`, `project`, `server`: leave unchanged.
6. **Backup before write:** copy the existing file to `<today>.md.bak` before writing. `.gitignore` excludes `*.bak`.
7. **Write** the updated file.

### Presentation of Modification Candidates

When presenting to the user, use this format:

```
Proposed modifications to existing diary:

[1] Blocker "X를 왜 못 돌리는지 모름" → RESOLVED in today's session
    Action: remove from Blockers, add to Done as "Fixed X".
    Apply? [y/N]

[2] Next item "Y 실험 돌리기" → COMPLETED today
    Action: remove from Next.
    Apply? [y/N]
```

Each `y` applies that single change; `N` or anything else skips it.
After all responses, perform the append step + approved modifications in one write.

## Corruption Recovery

If parsing the existing file fails (user manually edited and broke format):
1. Rename existing file to `<today>.md.bak`.
2. Notify user: "Existing diary could not be parsed; saved as .bak and writing fresh file."
3. Proceed as Case A.
```

- [ ] **Step 2: Commit**

```bash
git add skills/research-diary/references/merge_rules.md
git commit -m "docs(ref): add merge rules for same-day diary updates"
```

---

## Task 12: Write `references/test_scenarios.md`

**Files:**
- Create: `skills/research-diary/references/test_scenarios.md`

Spec reference: §8 Testing Strategy — Manual regression.

- [ ] **Step 1: Write the reference file**

Write `skills/research-diary/references/test_scenarios.md`:

```markdown
# Manual Regression Scenarios — Merge Logic

Merge decisions are made by Claude at runtime, so automated unit tests do not cover them. After any change to `SKILL.md` or `merge_rules.md`, walk through each scenario below against a disposable `DIARY_LOCAL_PATH` and confirm expected behavior.

## Setup

```bash
export DIARY_LOCAL_PATH=/tmp/diary-test
unset DIARY_GIT_REMOTE
rm -rf "$DIARY_LOCAL_PATH"
```

Run each scenario in a fresh Claude Code session in a project directory of your choice.

---

## Scenario 1 — Fresh first diary

**Precondition:** `$DIARY_LOCAL_PATH` does not exist.

**Steps:**
1. Do some research work in the session (read a file, run an experiment, hit a blocker).
2. Run `/research-diary`.

**Expected:**
- `diary_setup.sh` creates `$DIARY_LOCAL_PATH` via `git init`.
- A file is written at `$DIARY_LOCAL_PATH/<project>/<today>.md`.
- Frontmatter `sessions: 1`, one `work_hours` entry.
- Only sections with actual content appear (no empty sections).
- A commit exists in the local repo; push skipped since no remote.

---

## Scenario 2 — Same-day append

**Precondition:** Scenario 1 has been completed today.

**Steps:**
1. Start a new Claude Code session in the same project directory.
2. Do more work (new Done items, new Results).
3. Run `/research-diary`.

**Expected:**
- Existing diary is read.
- New bullets appended to relevant sections; existing bullets preserved verbatim.
- Frontmatter `sessions: 2`, `work_hours` has two entries.
- A `<today>.md.bak` exists alongside the updated file.

---

## Scenario 3 — Modification proposal (resolved blocker)

**Precondition:** Scenario 2 has been completed. Yesterday's or this morning's diary had a Blocker entry.

**Steps:**
1. In this session, demonstrably resolve that Blocker.
2. Run `/research-diary`.

**Expected:**
- Claude lists a modification proposal: "Blocker X appears resolved; move to Done?".
- Accepting removes the Blocker and adds a Done bullet. Rejecting leaves Blockers unchanged and still appends new work to Done.

---

## Scenario 4 — Low-signal session

**Precondition:** Any state.

**Steps:**
1. Use the session only for file browsing / chit-chat, no research progress.
2. Run `/research-diary`.

**Expected:**
- Claude prompts: "Not much research-worthy work in this session. Still want to create/update a diary?"
- Accepting proceeds with minimal content. Rejecting exits cleanly with no file written and no commit.

---

## Scenario 5 — Push failure

**Precondition:**
- `DIARY_GIT_REMOTE` set to an unreachable URL, e.g. `git@github.com:nonexistent-user/no-repo.git`.
- `$DIARY_LOCAL_PATH` freshly initialized OR scenario 1 completed without a remote — then add the bad remote manually.

**Steps:**
1. Do some work and run `/research-diary`.

**Expected:**
- Local file written and committed.
- Push attempt fails; stderr shows `push to origin failed (commit kept locally)`.
- Exit status of the overall skill is success; next invocation will push both commits once reachable.

---

## Scenario 6 — Corrupted existing file

**Precondition:** Scenario 1 has been completed today.

**Steps:**
1. Manually edit `<today>.md` to break the frontmatter (e.g., delete `---` line).
2. Run `/research-diary`.

**Expected:**
- Claude reports inability to parse existing file.
- Existing file moved to `<today>.md.bak`.
- Fresh diary written using Case A flow.
```

- [ ] **Step 2: Commit**

```bash
git add skills/research-diary/references/test_scenarios.md
git commit -m "docs(ref): add manual regression scenarios for merge logic"
```

---

## Task 13: Write `SKILL.md`

**Files:**
- Create: `skills/research-diary/SKILL.md`

Spec reference: §6 SKILL.md 핵심 내용.

- [ ] **Step 1: Write the skill entry**

Write `skills/research-diary/SKILL.md`:

````markdown
---
name: research-diary
description: Use when the user invokes `/research-diary` or asks to write, update, or append a research diary for the current project. Produces a structured per-day Markdown diary in a local git-tracked directory and pushes to a configured GitHub repo.
---

# Research Diary

Write or update a per-project, per-day research diary from the current Claude Code session.

## When to Activate

- User runs `/research-diary`.
- User says things like "오늘 연구일지 써줘", "하루 정리해줘", "write today's research log", "update my diary".

## Environment

Reads these environment variables from `settings.json`:

| Variable | Default | Meaning |
|---|---|---|
| `DIARY_LOCAL_PATH` | `~/research-diary` | Local diary git repo root |
| `DIARY_GIT_REMOTE` | (unset) | Optional. If set, used on first setup to `git clone`; push target thereafter |

## Procedure

Execute these steps in order. Do not skip steps.

### 1. Ensure local diary directory is ready

Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/research-diary/scripts/diary_setup.sh"
```

- Exit 0: proceed.
- Exit 1: the path exists but is not a git repo. Stop and ask the user: "$DIARY_LOCAL_PATH exists but is not a git repository. Reinitialize it as a git repo, or pick a different `DIARY_LOCAL_PATH`?" Wait for confirmation before doing anything destructive.

### 2. Resolve the project name

- If file `.diary-project-name` exists in the current working directory, use its trimmed content.
- Otherwise use the basename of `pwd`.

### 3. Resolve today's date and target path

- `date` = `YYYY-MM-DD` in local timezone.
- `target` = `${DIARY_LOCAL_PATH}/<project>/<date>.md`.
- Create `${DIARY_LOCAL_PATH}/<project>/` if missing: `mkdir -p`.

### 4. Decide Case A or Case B

- If `target` does not exist → **Case A (fresh write)**.
- If `target` exists → **Case B (merge)**. Read it now so subsequent analysis can reference it.

### 5. Analyze the current session

Survey the conversation from this session. Extract, per field from `references/diary_format.md`:

- Goal, Hypothesis, Experiments, Done, Results, Decisions & Rationale, Discarded, Blockers, Next.

**Empty sections must be omitted from the output file entirely.**

If the session appears to contain no research-worthy work (pure chit-chat, aimless file browsing), pause and ask the user: "This session doesn't look like it has notable research work. Create/update the diary anyway?" If they decline, stop without writing anything.

If detail is needed on field semantics or examples, read `references/diary_format.md`.

### 6. For Case B, compute merge

Read `references/merge_rules.md` for the full decision tree. Summary:

- Append new bullets to each section; keep existing content verbatim.
- Identify modification candidates (resolved Blocker, completed Next, corrected Result, contradictions) and present as a diff for per-item user approval. Do not apply a modification without explicit `y`.

If the existing file fails to parse, rename it to `${target}.bak`, notify the user, and proceed as Case A.

### 7. Build the frontmatter

- `date`: today.
- `project`: resolved project name.
- `server`: output of `hostname`.
- `work_hours`: heuristic — start time from the first user message timestamp of the current session (look at the session jsonl under `~/.claude/projects/` if available; otherwise use the jsonl mtime; otherwise omit). End time = now. Format: `HH:MM - HH:MM`.
- `sessions`:
  - Case A → `1`.
  - Case B → existing `sessions` + 1. Also append a new range to `work_hours`.

### 8. Write the file

- For Case B, first copy `target` to `${target}.bak`.
- Write the final content with frontmatter + non-empty sections only.

### 9. Commit and push

Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/research-diary/scripts/diary_commit.sh" <project> <date>
```

- Exit 0 always means the local commit succeeded. Push may have silently failed; check stderr for the warning.

### 10. Summarize to the user

Print a concise summary:

- File path written.
- Case A or Case B (and which modification proposals were applied).
- Push status: success / failed (with a one-line reason from stderr if present) / skipped (no remote).

## Notes

- Never create diaries for dates other than today.
- Never batch multiple projects in one invocation; one call = one project.
- Backups (`*.bak`) are ignored by git; they are a safety net for merge mistakes.
````

- [ ] **Step 2: Verify references are resolvable**

Run:

```bash
ls skills/research-diary/references/diary_format.md skills/research-diary/references/merge_rules.md skills/research-diary/scripts/diary_setup.sh skills/research-diary/scripts/diary_commit.sh
```

Expected: all four paths listed with no errors.

- [ ] **Step 3: Commit**

```bash
git add skills/research-diary/SKILL.md
git commit -m "feat(skill): add research-diary orchestration skill"
```

---

## Task 14: Write `README.md` (installation + usage guide)

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write the README**

Write `README.md`:

````markdown
# research-diary-plugin

A Claude Code plugin that writes structured per-project research diaries from your current session, stores them in a local git-tracked directory, and pushes them to your personal GitHub repo.

Designed for lab-wide deployment: one plugin install per researcher, individual config via `settings.json`.

## What It Does

Invoke `/research-diary` at the end of (or during) a research session and Claude will:

1. Survey the current session's conversation.
2. Extract structured fields: Goal, Hypothesis, Experiments, Done, Results, Decisions & Rationale, Discarded, Blockers, Next.
3. Write `~/research-diary/<project>/<today>.md` (path configurable).
4. If a diary already exists for today, merge the new content (append by default; ask for confirmation before modifying existing entries).
5. Commit and push to your configured GitHub repo.

Project name = basename of the current working directory (override with a `.diary-project-name` file).

## Install

```bash
/plugin install github:<your-lab-org>/research-diary-plugin
```

## Configure

Add to `~/.claude/settings.json`:

```json
{
  "env": {
    "DIARY_LOCAL_PATH": "/home/<you>/research-diary",
    "DIARY_GIT_REMOTE": "git@github.com:<you>/research-diary.git"
  }
}
```

| Variable | Default | Purpose |
|---|---|---|
| `DIARY_LOCAL_PATH` | `~/research-diary` | Where diaries live locally. This directory is itself a git clone of your remote |
| `DIARY_GIT_REMOTE` | (unset) | Your personal GitHub repo. Omit to stay local-only (push is skipped) |

On first run the plugin will `git clone $DIARY_GIT_REMOTE $DIARY_LOCAL_PATH` (or `git init` if no remote is set).

## Usage

In any project directory:

```
$ claude
> ... do your research work ...
> /research-diary
```

Re-run later the same day to append; Claude will ask before modifying existing entries (e.g., moving a resolved Blocker to Done).

## File Format

`~/research-diary/<project>/YYYY-MM-DD.md` with YAML frontmatter and Markdown sections. See `skills/research-diary/references/diary_format.md` for the full schema and example.

## Development

### Running tests

```bash
bash tests/run_tests.sh
```

Tests cover the two shell scripts (`diary_setup.sh`, `diary_commit.sh`). Merge behavior is driven by Claude at runtime; see `skills/research-diary/references/test_scenarios.md` for manual regression scenarios.

### Layout

```
.
├── .claude-plugin/plugin.json
├── README.md
├── skills/research-diary/
│   ├── SKILL.md
│   ├── scripts/
│   │   ├── diary_setup.sh
│   │   └── diary_commit.sh
│   └── references/
│       ├── diary_format.md
│       ├── merge_rules.md
│       └── test_scenarios.md
├── tests/
└── docs/superpowers/{specs,plans}/
```

## License

TBD by the lab.
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add README with install, config, and usage guide"
```

---

## Task 15: Final end-to-end verification

- [ ] **Step 1: Full test run**

```bash
bash tests/run_tests.sh
```

Expected: `All test files passed.`

- [ ] **Step 2: Lint the layout**

Run:

```bash
find . -type f \
  -not -path './.git/*' \
  -not -path './tests/tmp/*' \
  | sort
```

Expected output contains exactly:

```
./.claude-plugin/plugin.json
./.gitignore
./README.md
./docs/superpowers/plans/2026-04-21-research-diary-plugin.md
./docs/superpowers/specs/2026-04-21-research-diary-plugin-design.md
./skills/research-diary/SKILL.md
./skills/research-diary/references/diary_format.md
./skills/research-diary/references/merge_rules.md
./skills/research-diary/references/test_scenarios.md
./skills/research-diary/scripts/diary_commit.sh
./skills/research-diary/scripts/diary_setup.sh
./tests/run_tests.sh
./tests/test_diary_commit.sh
./tests/test_diary_setup.sh
./tests/test_helpers.sh
```

- [ ] **Step 3: Verify all scripts are executable**

Run:

```bash
ls -l skills/research-diary/scripts/*.sh tests/*.sh | awk '{print $1, $NF}'
```

Expected: every `.sh` has `x` in the user permission bits.

If any are not executable: `chmod +x <file>`, then commit with:

```bash
git add -A
git commit -m "chore: ensure shell scripts are executable"
```

- [ ] **Step 4: Manual smoke test**

Invoke a dry-run of the two scripts directly in a temp dir:

```bash
tmp=$(mktemp -d)
DIARY_LOCAL_PATH="$tmp/diary" bash skills/research-diary/scripts/diary_setup.sh
mkdir -p "$tmp/diary/smoke"
echo "# smoke test" > "$tmp/diary/smoke/$(date +%F).md"
git -C "$tmp/diary" config user.email t@t
git -C "$tmp/diary" config user.name t
DIARY_LOCAL_PATH="$tmp/diary" bash skills/research-diary/scripts/diary_commit.sh smoke "$(date +%F)"
git -C "$tmp/diary" log --oneline
rm -rf "$tmp"
```

Expected: one commit with subject `diary(smoke): <today>`.

- [ ] **Step 5: No commit for verification** — done.

---

## Self-Review Notes

- **Spec §1–§9 coverage:**
  - §2 Architecture (four units) → Tasks 3–8 (scripts), 10–13 (refs + SKILL.md), 1 (manifest)
  - §3 Config → Task 13 (SKILL.md reads env), Task 14 (README documents it)
  - §4 File format → Task 10 `diary_format.md`
  - §5 Merge → Task 11 `merge_rules.md`, wired into SKILL.md step 6
  - §6 Plugin file structure → Task 1 scaffold + Task 13 SKILL procedure
  - §7 Error handling → scripts handle missing/invalid paths (Tasks 3–6, 7–8); SKILL.md step 1, 5 handle user-facing prompts
  - §8 Testing → Tasks 2, 3–8 (auto), 12 (manual scenarios)
  - §9 Future extensions → deliberately out of scope
- **Types/names:** `DIARY_LOCAL_PATH` / `DIARY_GIT_REMOTE` used consistently across scripts, SKILL.md, and README. Commit message format `diary(<project>): <date>` used identically in spec, script, and test.
- **One open design point:** `work_hours` heuristic depends on reading `~/.claude/projects/` jsonl mtimes. SKILL.md flags this as best-effort; tests do not cover it because it is Claude-side. Noted and acceptable.
