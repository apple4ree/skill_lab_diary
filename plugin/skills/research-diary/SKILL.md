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
