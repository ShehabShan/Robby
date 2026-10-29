#!/usr/bin/env bash
# Commit + rebase + push in one step, then show the OLU meter.
# Usage: bash scripts/save.sh "R-011: short message"
set -uo pipefail
cd "$(dirname "$0")/.."
msg="${1:?usage: save.sh \"TASK-ID: message\"}"
git add -A
if git diff --cached --quiet; then
	echo "SAVE: nothing new to commit"
else
	git commit -q -m "$msg"
fi
git pull -q --rebase origin main 2>&1 | tail -2
if out=$(git push -q origin HEAD:main 2>&1); then
	echo "SAVE: pushed $(git log --oneline -1)"
else
	echo "SAVE: PUSH FAILED: $(echo "$out" | tail -3)"
	exit 1
fi
bash scripts/olu.sh || true