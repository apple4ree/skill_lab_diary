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
