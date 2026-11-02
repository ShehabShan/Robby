#!/usr/bin/env bash
# T-053a4b (D-381): ask Gemini Lyria for a tonal clip via the `__gemini-web-search` integration (curl; httpx
# drops the long chunked reply, D-388). Usage: bash scripts/lyria_tone.sh <out.mp3> "<prompt>" [model]
# Raw clips go to build/sfx/raw (git-ignored); scripts/make_sfx.py cuts and layers them.
set -euo pipefail
out=$1; prompt=$2; model=${3:-lyria-3-clip-preview}
mkdir -p "$(dirname "$out")"
body=$(python3 -c 'import json,sys;print(json.dumps({"contents":[{"parts":[{"text":sys.argv[1]}]}]}))' "$prompt")
code=$(curl -sS --max-time 280 -o "$out.json" -w "%{http_code}" \
  "$PROMPTQL_PLATFORM_API_URL/v1/integration/__gemini-web-search/generativelanguage.googleapis.com/v1beta/models/$model:generateContent" \
  -H "Authorization: Bearer $PROMPTQL_USER_JWT" -H "Content-Type: application/json" \
  -H "X-PromptQL-Description: Robby T-053a4b: Lyria clip $(basename "$out")" -d "$body")
[ "$code" = 200 ] || { echo "FAIL HTTP $code $(head -c 200 "$out.json")"; exit 1; }
python3 - "$out" <<'EOF'
import base64, json, sys
out = sys.argv[1]
for c in json.load(open(out + ".json")).get("candidates", []):
    for p in c.get("content", {}).get("parts", []):
        d = p.get("inlineData")
        if d and d.get("mimeType", "").startswith("audio"):
            open(out, "wb").write(base64.b64decode(d["data"])); print("OK", out); sys.exit(0)
sys.exit("FAIL no audio part")
EOF
rm -f "$out.json"
