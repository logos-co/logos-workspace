#!/bin/bash

REPOS_DIR="$(cd "$(dirname "$0")" && pwd)/repos"

for repo in "$REPOS_DIR"/*/; do
  name=$(basename "$repo")
  echo "==> Updating $name"
  cd "$repo" || continue

  # skip if not a git repo
  [ -d ".git" ] || [ -f ".git" ] || continue

  git fetch --all

  if git checkout master 2>/dev/null; then
    branch=master
  elif git checkout main 2>/dev/null; then
    branch=main
  else
    echo "    WARNING: could not checkout master or main, skipping"
    echo ""
    continue
  fi

  git pull origin "$branch"
  echo ""
done
