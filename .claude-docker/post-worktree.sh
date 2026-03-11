#!/bin/bash
# Post-worktree setup hook for claude-docker
# Runs inside the newly created worktree directory.
# The worktree and branch already exist; this initializes submodules and repo branches.

set -euo pipefail

branch=$(git rev-parse --abbrev-ref HEAD)
./scripts/ws init
./scripts/ws foreach "git checkout -b ws/$branch || true"
