#!/usr/bin/env bash
# Land the current branch on claude/trunk (the project trunk).  Usage: land.sh <label>
set -euo pipefail
label=${1:?usage: land.sh <label>}
T=claude/trunk
for attempt in 1 2 3; do
  git fetch -q origin "$T"
  git merge -q --no-edit "origin/$T" || { echo "CONFLICT merging $T - resolve, re-gate, commit, re-run"; exit 1; }
  if git push -q origin "HEAD:refs/heads/$T"; then echo "LANDED $label on $T ($(git rev-parse --short HEAD))"; exit 0; fi
  echo "trunk moved, retrying ($attempt)"
done
echo "FAILED to land after 3 attempts"; exit 1
