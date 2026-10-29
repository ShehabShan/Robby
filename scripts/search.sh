#!/usr/bin/env bash
# Web research via PromptQL's built-in Exa search. Prints a capped answer + up to 5 source URLs.
# Usage: bash scripts/search.sh "question" [max_chars=1500]
set -uo pipefail
q="${1:?usage: search.sh \"question\" [max_chars]}"
max="${2:-1500}"
if [ -z "${PROMPTQL_PLATFORM_API_URL:-}" ]; then
	echo "SEARCH: n/a (not in a PromptQL VM)"
	exit 1
fi
url="$PROMPTQL_PLATFORM_API_URL/v1/integration/__exa-web-search/api.exa.ai/answer"
body=$(jq -n --arg q "$q" '{query: $q}')
resp=$(curl -s -X POST "$url" -H "Authorization: Bearer $PROMPTQL_USER_JWT" -H "Content-Type: application/json" \
	-H "X-PromptQL-Description: Robby research: web search" -d "$body")
echo "$resp" | jq -r --argjson m "$max" \
	'if .answer then "ANSWER: " + (.answer | tostring | .[0:$m]) + "\nSOURCES: " + ([.citations[]?.url][0:5] | join(" | ")) else "SEARCH ERROR: " + (tostring | .[0:300]) end' 2>/dev/null \
	|| echo "SEARCH ERROR: ${resp:0:300}"