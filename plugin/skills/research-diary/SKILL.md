---
name: research-diary
description: Use when the user invokes `/research-diary` or asks to write, update, or append a research diary for the current project. Produces a structured per-day Markdown diary inside the current project's `research-diary/` directory (a nested git repo). Per-project isolation — no global config needed.
---

# Research Diary

Write or update a per-project, per-day research diary from the current Claude Code session.

Diaries live inside each project at `$(pwd)/research-diary/<YYYY-MM-DD>.md`. The `research-diary/` directory is a nested git repo isolated from the project's own git history. No global setup is required — the first invocation auto-initializes the directory.

## When to Activate

- User runs `/research-diary`.
- User says things like "오늘 연구일지 써줘", "하루 정리해줘", "write today's research log", "update my diary".

## Procedure

Execute these steps in order. Do not skip steps.

### 1. Ensure the diary directory is ready

Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/research-diary/scripts/diary_setup.sh"
```

This creates `$(pwd)/research-diary/` and `git init`s it if it doesn't exist. If the path exists but isn't a git repo, the script exits 1 — stop and ask the user: "`$(pwd)/research-diary` exists but isn't a git repository. Reinitialize or pick a different layout?" Wait for confirmation.

### 2. Resolve today's date and target path

- `date` = `YYYY-MM-DD` in local timezone.
- `target` = `$(pwd)/research-diary/<date>.md`.

### 3. Decide Case A or Case B

- If `target` does not exist → **Case A (fresh write)**.
- If `target` exists → **Case B (merge)**. Read it now.

### 4. Analyze the current session

Survey the conversation from this session. Extract, per field (see `references/diary_format.md`):

- Goal, Hypothesis, Experiments, Done, Results, Decisions & Rationale, Discarded, Blockers, Next.

**Omit sections whose content is empty** — do not write "- (none)" placeholders.

If the session appears to contain no research-worthy work (pure chit-chat, aimless file browsing), pause and ask: "This session doesn't look like it has notable research work. Create/update the diary anyway?" If they decline, stop without writing.

### 5. For Case B, compute merge

Read `references/merge_rules.md` for the full decision tree. Summary:

- Append new bullets to each section; keep existing content verbatim.
- Identify modification candidates (resolved Blocker, completed Next, corrected Result, contradictions) and present as a diff for per-item user approval. Never apply a modification without explicit `y`.

If the existing file fails to parse, rename it to `${target}.bak`, notify the user, and proceed as Case A.

### 6. Build the frontmatter

- `date`: today.
- `project`: the basename of `$(pwd)` (or contents of `.diary-project-name` if that file exists in the working directory). Used for cross-diary grep, not the directory structure.
- `server`: output of `hostname`.
- `work_hours`: heuristic — start time from the first user message timestamp of the current Claude Code session jsonl (under `~/.claude/projects/`) if readable; otherwise the jsonl's mtime; otherwise omit. End time = now. Format: `HH:MM - HH:MM`.
- `sessions`:
  - Case A → `1`.
  - Case B → existing `sessions` + 1. Append the new range to `work_hours`.

### 7. Write the file

- For Case B, first copy `target` to `${target}.bak`.
- Write the final content with frontmatter + non-empty sections only.

### 8. Commit (and push if the user added a remote)

Run:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/research-diary/scripts/diary_commit.sh" <date>
```

The script commits to the project's `research-diary/` nested repo with message `diary: <date>`. It will push only if the user manually added a git remote (`cd research-diary && git remote add origin ...`). Push failure is non-fatal.

- Exit 0 always means the local commit succeeded.
- Non-zero exit from this script: report to user, do not retry automatically.

### 9. Summarize to the user

Print:

- File path written (e.g. `./research-diary/2026-04-21.md`).
- Case A or Case B (and which modification proposals were applied).
- Push status: succeeded / failed (with one-line reason) / skipped (no remote — default for per-project mode).

## Notes

- Never create diaries for dates other than today.
- Never batch multiple projects in one invocation; `/research-diary` only ever writes to the current directory's `research-diary/`.
- `research-diary/` is a nested git repo; the parent project's git (if any) sees it as an untracked directory. Add it to the project's `.gitignore` if you don't want to see it there.
- `*.bak` files are ignored by the diary repo's `.gitignore`; they exist as safety nets for merge mistakes.
- For backup: each project's diary can have its own remote (`cd research-diary && git remote add origin <url> && git push -u origin main`). No global remote — per-project isolation is the design goal.
