#!/usr/bin/env bash
# Commit (and optionally push) a diary file in the current project's research-diary repo.
# Usage: diary_commit.sh <YYYY-MM-DD>
#
# Env (for testing/override):
#   DIARY_LOCAL_PATH  explicit path to use instead of $(pwd)/research-diary
#
# Exit codes:
#   0 on successful local commit (push failure does NOT fail this script)
#   non-zero on local commit failure or misuse

set -u

if [ $# -ne 1 ]; then
    echo "usage: diary_commit.sh <YYYY-MM-DD>" >&2
    exit 2
fi

date="$1"
local_path="${DIARY_LOCAL_PATH:-$(pwd)/research-diary}"
rel_path="$date.md"

if [ ! -d "$local_path/.git" ] && [ ! -f "$local_path/.git" ]; then
    echo "diary_commit: not a git repo: $local_path" >&2
    exit 1
fi

cd "$local_path" || exit 1

if [ ! -f "$rel_path" ]; then
    echo "diary_commit: file not found: $rel_path" >&2
    exit 1
fi

git add "$rel_path"
git commit -q -m "diary: $date" || exit 1

# Attempt push only if the user has manually configured a remote. Never fail on push error.
if git remote | grep -q .; then
    remote_name=$(git remote | head -1)
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if ! git push -q "$remote_name" "$current_branch" 2>/dev/null; then
        echo "diary_commit: push to $remote_name failed (commit kept locally)" >&2
    fi
fi

exit 0
