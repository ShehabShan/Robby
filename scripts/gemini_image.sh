#!/usr/bin/env bash
# T-057a (D-409): ask a Gemini image model for a PNG via the `__gemini-web-search` integration (curl, like
# lyria_tone.sh). Usage: bash scripts/gemini_image.sh <out.png> "<prompt>" [model]
# Raw images go to build/art/ (git-ignored); scripts/process_vfx.py turns picked ones into upload crops.
set -euo pipefail
out=$1; prompt=$2; model=${3:-gemini-3-pro-image}
mkdir -p "$(dirname "$out")"
REFS="${REFS:-}" python3 -c '
import base64, json, os, sys
parts = [{"inlineData": {"mimeType": "image/png" if f.endswith(".png") else "image/jpeg",
          "data": base64.b64encode(open(f, "rb").read()).decode()}} for f in os.environ["REFS"].split()]
parts.append({"text": sys.argv[1]})
print(json.dumps({"contents": [{"parts": parts}], "generationConfig": {"responseModalities": ["IMAGE"]}}))' "$prompt" > "$out.req" 
code=$(curl -sS --max-time 280 -o "$out.json" -w "%{http_code}" \
  "$PROMPTQL_PLATFORM_API_URL/v1/integration/__gemini-web-search/generativelanguage.googleapis.com/v1beta/models/$model:generateContent" \
  -H "Authorization: Bearer $PROMPTQL_USER_JWT" -H "Content-Type: application/json" \
  -H "X-PromptQL-Description: Robby T-057a: Gemini image $(basename "$out")" --data-binary @"$out.req"); rm -f "$out.req"
[ "$code" = 200 ] || { echo "FAIL HTTP $code $(head -c 200 "$out.json")"; exit 1; }
python3 - "$out" <<'EOF'
import base64, json, sys
out = sys.argv[1]
for c in json.load(open(out + ".json")).get("candidates", []):
    for p in c.get("content", {}).get("parts", []):
        d = p.get("inlineData")
        if d and d.get("mimeType", "").startswith("image"):
            open(out, "wb").write(base64.b64decode(d["data"])); print("OK", out, d["mimeType"]); sys.exit(0)
sys.exit("FAIL no image part")
EOF
rm -f "$out.json"
