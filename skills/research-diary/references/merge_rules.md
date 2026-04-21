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
