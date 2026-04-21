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
fi

exit 0
