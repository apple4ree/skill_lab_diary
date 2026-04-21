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

This repo is a single-plugin marketplace. Install in two steps:

```bash
/plugin marketplace add apple4ree/skill_lab_diary
/plugin install research-diary-plugin@skill_lab_diary
```

Note: the first argument is `owner/repo` (no `github:` prefix).

(Later updates: `/plugin marketplace update skill_lab_diary` then reinstall.)

## Configure

### Option A — Interactive setup (recommended)

After installing, run:

```
/research-diary-setup
```

Claude will prompt you for your diary repo URL and local path, write the values into `~/.claude/settings.json`, and initialize the local diary directory. You can re-run it later to change the configuration.

### Option B — Manual

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
├── .claude-plugin/marketplace.json   # marketplace index
├── plugin/                            # the plugin itself
│   ├── .claude-plugin/plugin.json    # plugin manifest
│   └── skills/
│       ├── research-diary/
│       │   ├── SKILL.md
│       │   ├── scripts/
│       │   │   ├── diary_setup.sh
│       │   │   └── diary_commit.sh
│       │   └── references/
│       │       ├── diary_format.md
│       │       ├── merge_rules.md
│       │       └── test_scenarios.md
│       └── research-diary-setup/
│           └── SKILL.md
├── tests/
├── docs/superpowers/{specs,plans}/
└── README.md
```

## License

TBD by the lab.
