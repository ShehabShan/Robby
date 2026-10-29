#!/usr/bin/env bash
# OLU budget meter (works inside a PromptQL VM; costs no OLU itself).
#   bash scripts/olu.sh start   -> record a baseline (ONLY when reusing a bot/VM for a new session)
#   bash scripts/olu.sh         -> print OLU used this session and what to do
# Fresh bot: no baseline file exists, so the whole bot total counts (from 0).
set -euo pipefail
cd "$(dirname "$0")/.."
CAP=50
WRAP=43
HARD=45
if [ -z "${PROMPTQL_PLATFORM_API_URL:-}" ] || [ -z "${PROMPTQL_THREAD_ID:-}" ]; then
	echo "OLU: n/a (not running in a PromptQL VM)"
	exit 0
fi
body=$(jq -n --arg t "$PROMPTQL_THREAD_ID" \
	'{query: ("query { a: olu_usage_aggregate(where:{thread_id:{_eq:\"" + $t + "\"}}){ aggregate { sum { olus } } } }")}')
total=$(curl -s "$PROMPTQL_PLATFORM_API_URL/v1/graphql" \
	-H "Authorization: Bearer $PROMPTQL_USER_JWT" -H "Content-Type: application/json" -d "$body" \
	| jq -r '.data.a.aggregate.sum.olus // "0"')
mkdir -p .cache
if [ "${1:-}" = "start" ]; then
	echo "$total" >.cache/olu_baseline
	echo "OLU baseline set (bot total so far: $total). Budget: $CAP, wrap-up at $WRAP, close-out by $HARD."
	exit 0
fi
base=$(cat .cache/olu_baseline 2>/dev/null || echo 0)
used=$(awk -v a="$total" -v b="$base" 'BEGIN{printf "%.1f", a-b}')
status=$(awk -v u="$used" -v w="$WRAP" -v h="$HARD" 'BEGIN{
	if (u >= h) print "EMERGENCY: one-line STATE update + commit + push NOW";
	else if (u >= w) print "WRAP UP: stop new work, do close-out";
	else if (u >= 30) print "FINISH CURRENT STEP: no new task";
	else print "OK"}')
echo "OLU this session: $used / $CAP -> $status"