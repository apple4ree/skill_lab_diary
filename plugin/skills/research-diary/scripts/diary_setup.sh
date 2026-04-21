#!/usr/bin/env bash
# Ensure the per-project diary directory exists and is a git repository.
# The diary lives at $(pwd)/research-diary/ (a nested git repo inside each project).
#
# Env (for testing/override):
#   DIARY_LOCAL_PATH  explicit path to use instead of $(pwd)/research-diary

set -u

local_path="${DIARY_LOCAL_PATH:-$(pwd)/research-diary}"

if [ ! -e "$local_path" ]; then
    mkdir -p "$local_path"
    git -C "$local_path" init -q -b main
    exit $?
fi

# Path exists; verify it is a git repo root (not merely inside one)
if [ -d "$local_path/.git" ] || [ -f "$local_path/.git" ]; then
    exit 0
fi

echo "diary_setup: $local_path exists but is not a git repository" >&2
exit 1
