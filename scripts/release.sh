#!/usr/bin/env bash
# Free claims of cut-off sessions so their tasks can be picked up again (D-134). Run on main, clean tree.
# A claim is stale when its branch had no push (save.sh) for STALE_MIN minutes (default 120) since the claim.
# The branch is kept: its work waits for adoption (AGENTS.md §9).
# Usage: bash scripts/release.sh          (release stale claims only)
#        bash scripts/release.sh S25      (owner says S25 died: release it now)
#        bash scripts/release.sh <bot id or bot link>   (owner says that PromptQL bot stopped)
set -uo pipefail
cd "$(dirname "$0")/.."
mins="${STALE_MIN:-120}"
force="${1:-}"
force="${force%%\?*}"; force="${force%/}"; force="${force##*/}" # bot link -> bot id
f=.ai/CLAIMS.md
[ "$(git branch --show-current)" = main ] || { echo "RELEASE: run on main"; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "RELEASE: tree not clean, run save.sh first"; exit 1; }
for try in 1 2 3; do
	git pull -q --rebase origin main || { echo "RELEASE: cannot update main"; exit 1; }
	git fetch -q --prune origin '+refs/heads/session/*:refs/remotes/origin/session/*' 2>/dev/null
	now=$(date -u +%s)
	gone=""
	while IFS='|' read -r _ s task br _d claimed bot _rest; do
		s=$(echo "$s" | xargs); task=$(echo "$task" | xargs); br=$(echo "$br" | xargs); bot=$(echo "$bot" | xargs)
		c=$(date -u -d "$(echo "$claimed" | xargs)" +%s 2>/dev/null || echo 0)
		p=$(git log -1 --format=%ct "origin/$br" 2>/dev/null || echo 0)
		last=$((c > p ? c : p))
		age=$(((now - last) / 60))
		if [ "$s" = "$force" ] || { [ ${#force} -ge 8 ] && [[ $bot == "$force"* ]]; } || [ "$age" -ge "$mins" ]; then
			echo "RELEASE: $s $task (last activity ${age} min ago) -> released, branch $br kept for adoption"
			case " $gone " in *" $s "*) ;; *) gone="$gone $s" ;; esac
		else
			echo "RELEASE: $s $task (last activity ${age} min ago) -> active, kept"
		fi
	done < <(grep -E '^\| *S[0-9]+ *\|' "$f")
	[ -n "$gone" ] || { echo "RELEASE: nothing stale"; exit 0; }
	for s in $gone; do sed -i "/^| *$s *|/d" "$f"; done
	git add "$f" && git commit -q -m "release stale claims:$gone (branches kept)"
	git push -q origin HEAD:main 2>/dev/null && { echo "RELEASE: pushed"; exit 0; }
	git reset -q --hard HEAD~1
	sleep $((RANDOM % 6 + 1))
done
echo "RELEASE: push to main failed 3 times; run release.sh again"
exit 1