#!/usr/bin/env bash
# Run Rojo and auto-pull new commits every few seconds, so changes pushed to
# GitHub show up in Roblox Studio without manual steps.
# Usage: ./scripts/sync.sh [branch]   (default: main)
set -euo pipefail
cd "$(dirname "$0")/.."
BRANCH="${1:-main}"

git fetch -q origin "$BRANCH"
git checkout -q "$BRANCH"
git pull -q --ff-only origin "$BRANCH" || true

rojo serve &
ROJO_PID=$!
trap 'kill $ROJO_PID 2>/dev/null' EXIT

echo "Rojo running. Auto-pulling '$BRANCH' every 5s. Press Ctrl+C to stop."
while true; do
  sleep 5
  git fetch -q origin "$BRANCH" 2>/dev/null || continue
  if [ "$(git rev-parse HEAD)" != "$(git rev-parse "origin/$BRANCH")" ]; then
    git pull -q --ff-only origin "$BRANCH" && echo "Pulled new changes."
  fi
done
