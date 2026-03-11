#!/bin/bash
# Post-worktree setup hook for claude-docker
# Runs inside the newly created worktree directory.
# The worktree and branch already exist; this initializes submodules and repo branches.

set -euo pipefail

branch=$(git rev-parse --abbrev-ref HEAD)

echo "Initializing submodules..."
git submodule update --init --depth 1 --jobs 4

echo "Creating ws/$branch branches in all repos..."
for dir in repos/*/; do
  [ -d "$dir" ] || continue
  repo=$(basename "$dir")
  if [ -d "$dir/.git" ] || [ -f "$dir/.git" ]; then
    (cd "$dir" && git checkout -b "ws/$branch" 2>/dev/null && echo "  ✓ $repo") || \
      echo "  skip $repo"
  fi
done

echo "Done."
