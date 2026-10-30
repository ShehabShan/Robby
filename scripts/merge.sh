#!/usr/bin/env bash
# Last close-out step of a session (D-087): rebase the session branch on main, require CHECK: PASS, release this
# session's claims in .ai/CLAIMS.md, push to main and delete the branch. Usage: bash scripts/merge.sh
set -uo pipefail
cd "$(dirname "$0")/.."
b=$(git branch --show-current)
[[ $b == session/S* ]] || { echo "MERGE: not on a session/S<n> branch"; exit 1; }
s=${b#session/}
[ -z "$(git status --porcelain)" ] || { echo "MERGE: tree not clean, run save.sh first"; exit 1; }
for try in 1 2 3; do
	git fetch -q origin main
	if ! git rebase -q origin/main >/tmp/merge.log 2>&1; then
		for _ in $(seq 1 60); do # STATE.md / CLAIMS.md: keep main's copy (update STATE on main after merging)
			[ -d .git/rebase-merge ] || [ -d .git/rebase-apply ] || break
			u=$(git diff --name-only --diff-filter=U)
			other=$(echo "$u" | grep -vxE '\.ai/(STATE|CLAIMS)\.md' | grep .)
			if [ -n "$other" ]; then
				echo "MERGE: CONFLICT in: $(echo "$other" | tr '\n' ' ')"
				echo "Keep both sides (main's lines + yours), git add, git rebase --continue, then run merge.sh again."
				exit 1
			fi
			if [ -n "$u" ]; then git checkout -q --ours -- $u && git add $u; fi
			GIT_EDITOR=true git rebase --continue >/dev/null 2>&1 || git rebase --skip >/dev/null 2>&1 || true
		done
	fi
	bash scripts/check.sh >/tmp/merge_check.log 2>&1
	tail -n 1 /tmp/merge_check.log | grep -q "CHECK: PASS" || {
		echo "MERGE: check failed, not merged: $(grep FAIL /tmp/merge_check.log | head -n 3 | tr '\n' ' ')"
		exit 1
	}
	sed -i "/^| *$s *|/d" .ai/CLAIMS.md
	git add -A
	git diff --cached --quiet || git commit -q -m "$s: merge to main, release claims"
	if git push -q origin HEAD:main 2>/dev/null; then
		git push -q origin --delete "$b" 2>/dev/null
		git checkout -q -B main && git branch -q -u origin/main && git branch -q -D "$b"
		echo "MERGE: $b merged into main: $(git log --oneline -1)"
		bash scripts/olu.sh || true
		exit 0
	fi
done
echo "MERGE: push to main failed 3 times (main keeps moving); run merge.sh again"
exit 1