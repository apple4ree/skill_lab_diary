#!/usr/bin/env bash
# Ensure the per-project diary directory exists and is a git repository.
# The diary lives at $(pwd)/research-diary/ (a nested git repo inside each project).
#
# Env (optional):
#   DIARY_LOCAL_PATH  explicit path override (default: $(pwd)/research-diary)
#   DIARY_REMOTE_URL  if set, auto-configure this URL as 'origin' on first init
#                     and initialize the repo on a branch named after the project
#                     (basename of $(pwd), or contents of ./.diary-project-name).

set -u

local_path="${DIARY_LOCAL_PATH:-$(pwd)/research-diary}"
remote_url="${DIARY_REMOTE_URL:-}"

resolve_branch() {
    if [ -f "./.diary-project-name" ]; then
        tr -d '[:space:]' < "./.diary-project-name"
    else
        basename "$(pwd)"
    fi
}

if [ ! -e "$local_path" ]; then
    mkdir -p "$local_path"
    if [ -n "$remote_url" ]; then
        branch=$(resolve_branch)
        git -C "$local_path" init -q -b "$branch" || exit $?
        git -C "$local_path" remote add origin "$remote_url" || exit $?
    else
        git -C "$local_path" init -q -b main || exit $?
    fi
    exit 0
fi

# Path exists; verify it is a git repo root (not merely inside one)
if [ -d "$local_path/.git" ] || [ -f "$local_path/.git" ]; then
    exit 0
fi

echo "diary_setup: $local_path exists but is not a git repository" >&2
exit 1
