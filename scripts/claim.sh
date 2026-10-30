#!/usr/bin/env bash
# Claim a task so parallel sessions never collide (D-087). Needs a clean tree (run save.sh first).
# Usage: bash scripts/claim.sh T-020a ["note"]
# First claim (on main): reserves the next session number S<n> + 10 decision IDs in .ai/CLAIMS.md, pushes that to
# main, then creates and pushes branch session/S<n>. Later claims (on session/S<n>) add a row for the same session.
set -uo pipefail
cd "$(dirname "$0")/.."
task="${1:?usage: claim.sh TASK-ID [note]}"
note="${2:-}"
f=.ai/CLAIMS.md
cur=$(git branch --show-current)
maxnum() { grep -oE "$1" | grep -oE '[0-9]+' | sed 's/^0*//' | sort -n | tail -1; }
[ -z "$(git status --porcelain)" ] || { echo "CLAIM: tree not clean, run save.sh first"; exit 1; }
for try in 1 2 3 4 5 6 7 8; do
	git checkout -q main && git pull -q --rebase origin main || { echo "CLAIM: cannot update main"; git checkout -q "$cur"; exit 1; }
	row=$(grep -E "^\| *S[0-9]+ *\| *$task *\|" "$f")
	[ -z "$row" ] || { echo "CLAIM: $task is taken: $row (pick a free task from STATE.md Parallel lanes)"; git checkout -q "$cur"; exit 1; }
	if [[ $cur == session/S* ]]; then
		s=${cur#session/}
		d=$(grep -E "^\| *$s *\|" "$f" | head -1 | cut -d'|' -f5 | xargs)
	else
		a=$(maxnum '^## S[0-9]+' <.ai/SESSION_LOG.md)
		b=$(maxnum '^\| *S[0-9]+' <"$f")
		s="S$(($(printf '%s\n' "${a:-0}" "${b:-0}" | sort -n | tail -1) + 1))"
		a=$(maxnum 'D-[0-9]+' <.ai/DECISIONS.md)
		b=$(maxnum '\.\.D-[0-9]+' <"$f")
		lo=$(($(printf '%s\n' "${a:-0}" "${b:-0}" | sort -n | tail -1) + 1))
		d=$(printf 'D-%03d..D-%03d' "$lo" $((lo + 9)))
	fi
	[ -z "$(tail -c1 "$f")" ] || echo >>"$f"
	echo "| $s | $task | session/$s | $d | $(date -u '+%Y-%m-%d %H:%M') | ${PROMPTQL_THREAD_ID:-unknown} | $note |" >>"$f"
	git add "$f" && git commit -q -m "$s: claim $task"
	git push -q origin HEAD:main 2>/dev/null && break
	git reset -q --hard HEAD~1
	sleep $((RANDOM % 6 + 1)) # another bot pushed first; wait, re-read, retry
	[ "$try" = 8 ] && { echo "CLAIM: push to main failed 8 times"; git checkout -q "$cur"; exit 1; }
done
if [[ $cur == session/S* ]]; then
	git checkout -q "$cur"
else
	git checkout -q -b "session/$s" && git push -q -u origin "session/$s" 2>/dev/null
fi
echo "CLAIM: $s has $task on branch session/$s (your decision IDs: $d)"