#!/usr/bin/env bash
# Runs every *_spec.lua file under tests/ with `nvim --headless -l`.
# Exits non-zero on the first failure.
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$TESTS_DIR"

if ! command -v nvim >/dev/null 2>&1; then
  echo "nvim not found in PATH" >&2
  exit 127
fi

shopt -s nullglob
specs=( *_spec.lua )

if [[ ${#specs[@]} -eq 0 ]]; then
  echo "no *_spec.lua files found in $TESTS_DIR" >&2
  exit 1
fi

failed=0
for spec in "${specs[@]}"; do
  echo "==> $spec"
  if ! nvim --headless --clean -u NONE -l "$spec"; then
    failed=$((failed + 1))
    echo "    spec failed: $spec" >&2
  fi
done

if [[ $failed -ne 0 ]]; then
  echo "$failed spec file(s) failed" >&2
  exit 1
fi

echo "all specs passed"
