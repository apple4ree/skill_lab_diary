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

## Next (다음 액션)
- Write SKILL.md orchestration procedure.
```
