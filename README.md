# research-diary-plugin

A Claude Code plugin that writes structured per-project research diaries from your current session and stores them inside each project, in the project's own nested `research-diary/` git repo.

Designed for lab-wide deployment: one plugin install per researcher, zero global configuration required. Per-project isolation is the design goal — each project's diary is self-contained.

## What It Does

Invoke `/research-diary` at the end of (or during) a research session and Claude will:

1. Survey the current session's conversation.
2. Extract structured fields: Goal, Hypothesis, Experiments, Done, Results, Decisions & Rationale, Discarded, Blockers, Next.
3. Write `./research-diary/<today>.md` inside the current project directory.
4. If a diary already exists for today, merge the new content (append by default; ask for confirmation before modifying existing entries).
5. Commit to the project's local `research-diary/` nested git repo. Never pushes unless you've manually configured a remote inside that nested repo.

Project name (used only inside the diary's frontmatter for cross-project grep) = basename of the current working directory. Override with a `.diary-project-name` file.

## Install

This repo is a single-plugin marketplace. Install in two steps:

```bash
/plugin marketplace add apple4ree/skill_lab_diary
/plugin install research-diary-plugin@skill_lab_diary
```

Note: the first argument is `owner/repo` (no `github:` prefix).

Later updates: `/plugin marketplace update skill_lab_diary` then reinstall.

## Usage

No configuration needed. In any project directory:

```
$ cd ~/some-project
$ claude
> ... do your research work ...
> /research-diary
```

On first use, the plugin creates `./research-diary/` and `git init`s it. Subsequent invocations append to today's file or create the next day's.

Re-run later the same day to append; Claude will ask before modifying existing entries (e.g., moving a resolved Blocker to Done).

### Optional: back up a project's diary to a remote

`research-diary/` is a nested git repo separate from your project's own git. To back it up somewhere:

```bash
cd research-diary
git remote add origin git@github.com:<you>/some-project-diary.git
git push -u origin main
```

Once a remote exists, every `/research-diary` call pushes automatically (push failures are non-fatal — the local commit always succeeds).

## File Format

`./research-diary/YYYY-MM-DD.md` with YAML frontmatter and Markdown sections. See `plugin/skills/research-diary/references/diary_format.md` for the full schema and example.

## Development

### Running tests

```bash
bash tests/run_tests.sh
```

Tests cover the two shell scripts (`diary_setup.sh`, `diary_commit.sh`). Merge behavior is driven by Claude at runtime; see `plugin/skills/research-diary/references/test_scenarios.md` for manual regression scenarios.

### Layout

```
.
├── .claude-plugin/marketplace.json   # marketplace index
├── plugin/                           # the plugin itself
│   ├── .claude-plugin/plugin.json   # plugin manifest
│   └── skills/
│       └── research-diary/
│           ├── SKILL.md
│           ├── scripts/
│           │   ├── diary_setup.sh
│           │   └── diary_commit.sh
│           └── references/
│               ├── diary_format.md
│               ├── merge_rules.md
│               └── test_scenarios.md
├── tests/
├── docs/superpowers/{specs,plans}/
└── README.md
```

## License

TBD by the lab.
