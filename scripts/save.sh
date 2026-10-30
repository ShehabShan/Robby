#!/usr/bin/env bash
# Commit + push in one step, then show the OLU meter.
# On a session branch (D-087) it pushes that branch; on main it rebases on main and pushes main.
# Usage: bash scripts/save.sh "R-011: short message"
set -uo pipefail
cd "$(dirname "$0")/.."
msg="${1:?usage: save.sh \"TASK-ID: message\"}"
b=$(git branch --show-current)
git add -A
if git diff --cached --quiet; then
	echo "SAVE: nothing new to commit"
else
	git commit -q -m "$msg"
fi
if [ "$b" = main ]; then
	if ! git pull -q --rebase origin main >/tmp/save_pull.log 2>&1; then
		git rebase --abort >/dev/null 2>&1 || true
		echo "SAVE: REBASE CONFLICT, local commit kept, not pushed: $(tail -3 /tmp/save_pull.log)"
		exit 1
	fi
	out=$(git push -q origin HEAD:main 2>&1)
else
	out=$(git push -q --force-with-lease -u origin "HEAD:$b" 2>&1) # only this session writes its branch
fi
if [ $? -eq 0 ]; then
	echo "SAVE: pushed $b $(git log --oneline -1)"
else
	echo "SAVE: PUSH FAILED: $(echo "$out" | tail -3)"
	exit 1
fi
bash scripts/olu.sh || true