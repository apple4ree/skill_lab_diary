---
name: research-diary-setup
description: Use when the user invokes `/research-diary-setup` or asks to configure, set up, or initialize the research-diary plugin. Interactively configures `DIARY_LOCAL_PATH` and `DIARY_GIT_REMOTE` in `~/.claude/settings.json` and initializes the local diary git repo.
---

# Research Diary Setup

One-time interactive configuration for the research-diary plugin. Writes the two environment variables into the user's `~/.claude/settings.json` and initializes the local diary directory.

## When to Activate

- User runs `/research-diary-setup`.
- User says things like "research diary 설정해줘", "연구일지 초기화", "set up research diary", "configure diary plugin".

## Procedure

Execute these steps in order.

### 1. Inspect existing configuration

Read `~/.claude/settings.json` (use Read tool, path `$HOME/.claude/settings.json`). Three cases:

- **File missing**: treat as empty `{}`; note to user "No settings.json found — will create one."
- **File exists, `env.DIARY_LOCAL_PATH` and `env.DIARY_GIT_REMOTE` both unset**: proceed with fresh setup.
- **File exists, one or both already set**: show current values and ask: "Existing configuration found:
  - DIARY_LOCAL_PATH: `<value or 'unset'>`
  - DIARY_GIT_REMOTE: `<value or 'unset'>`

  Reconfigure? (y/N)" — if N, exit cleanly with "Keeping existing configuration."

### 2. Collect `DIARY_GIT_REMOTE`

Ask the user:

> "Enter the GitHub repo URL where your diary entries will be pushed.
> Example: `git@github.com:<you>/research-diary.git`
> Leave blank to use local-only mode (no push)."

Accept whatever they type. Empty string = local-only.

If non-empty, do a light sanity check: it should look like a git URL (starts with `git@`, `https://`, or `ssh://`). If it clearly isn't (e.g., contains spaces, no `:` or `/`), ask again. Don't be overly strict — accept URLs you don't recognize.

### 3. Collect `DIARY_LOCAL_PATH`

Ask:

> "Local path where diaries will be stored [default: `~/research-diary`]:"

Empty input = default. Expand `~` to `$HOME` before saving.

### 4. Build the updated settings.json

Construct the new content:

1. Start from the existing parsed JSON (or `{}` if missing).
2. Ensure an `env` object exists.
3. Set `env.DIARY_LOCAL_PATH` and `env.DIARY_GIT_REMOTE` to the collected values.
4. If `DIARY_GIT_REMOTE` was left blank, **remove the key** (don't set it to `""`) — the plugin treats unset as local-only mode; an empty string would be ambiguous.
5. Preserve all other existing keys in `env` and at the top level verbatim.
6. Write back with 2-space indentation, trailing newline.

Use the Write tool to output the full JSON. Do NOT use Edit with partial string matches — full rewrite is safer for JSON.

### 5. Initialize the local diary directory

Run:

```bash
DIARY_LOCAL_PATH="<collected-path>" DIARY_GIT_REMOTE="<collected-remote-or-empty>" bash "${CLAUDE_PLUGIN_ROOT}/skills/research-diary/scripts/diary_setup.sh"
```

(If `DIARY_GIT_REMOTE` was blank, omit it from the env prefix — do not pass `DIARY_GIT_REMOTE=""`.)

Handle exit codes:
- **0**: directory is ready.
- **1**: the path already exists but isn't a git repo. Report this to the user and ask whether to (a) choose a different path and re-run setup, or (b) `git init` in place manually. Do NOT take destructive action automatically.

### 6. Verify

Confirm:
- `DIARY_LOCAL_PATH` exists and is a git repo (`test -d "$DIARY_LOCAL_PATH/.git"` or equivalent).
- If `DIARY_GIT_REMOTE` was set, `git -C "$DIARY_LOCAL_PATH" remote -v` shows it.

### 7. Summary

Print a concise summary:

```
✓ settings.json updated: ~/.claude/settings.json
  - DIARY_LOCAL_PATH = <value>
  - DIARY_GIT_REMOTE = <value or 'unset (local-only)'>
✓ Local diary repo ready at <DIARY_LOCAL_PATH>
  - Remote: <remote or 'none'>

Next: in any project directory, run /research-diary to write your first entry.
```

## Notes

- This skill only touches `~/.claude/settings.json` (user-global). It does not touch project-level `.claude/settings.json` files.
- Re-running the skill is safe — it reads current state and confirms before overwriting.
- The skill never deletes existing keys besides `DIARY_GIT_REMOTE` (when user chose local-only). Other env vars and top-level settings are preserved.
