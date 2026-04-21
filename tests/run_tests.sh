#!/usr/bin/env bash
# Run every tests/test_*.sh file (excluding the helpers) and aggregate exit status.

set -u

THIS_DIR="$(cd "$(dirname "$0")" && pwd)"
FAILED_FILES=()

for f in "$THIS_DIR"/test_*.sh; do
    [ -e "$f" ] || continue
    case "$(basename "$f")" in
        test_helpers.sh) continue ;;
    esac
    echo "=== $(basename "$f") ==="
    if ! bash "$f"; then
        FAILED_FILES+=("$(basename "$f")")
    fi
done

echo ""
if [ ${#FAILED_FILES[@]} -eq 0 ]; then
    echo "All test files passed."
    exit 0
else
    echo "Test files with failures:"
    printf '  - %s\n' "${FAILED_FILES[@]}"
    exit 1
fi
