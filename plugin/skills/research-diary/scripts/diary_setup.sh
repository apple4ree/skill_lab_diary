#!/usr/bin/env bash
# Ensure the local diary directory exists and is a git repository.
# Env:
#   DIARY_LOCAL_PATH  (default: ~/research-diary)
#   DIARY_GIT_REMOTE  (optional; if set and local path absent, clone from it)

set -u

local_path="${DIARY_LOCAL_PATH:-$HOME/research-diary}"
remote="${DIARY_GIT_REMOTE:-}"

if [ ! -e "$local_path" ]; then
    if [ -n "$remote" ]; then
        git clone "$remote" "$local_path"
        exit $?
    fi
    mkdir -p "$local_path"
    git -C "$local_path" init -q -b main
    exit $?
fi

# Path exists; verify it is a git repo (not merely inside one)
if [ -d "$local_path/.git" ] || [ -f "$local_path/.git" ]; then
    exit 0
fi

echo "diary_setup: $local_path exists but is not a git repository" >&2
exit 1
