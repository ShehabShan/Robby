# Robby image generation helper: PromptQL built-in Gemini (gemini-3-pro-image).
# Runs in the PromptQL PROGRAM RUNTIME (run_program), not the VM: the VM HTTP route
# (/v1/integration/__gemini-web-search/...) dropped every image response with
# "incomplete chunked read" (S114). Copy this file to the bot-local filesystem,
# set PROMPT / REFS / OUT_ID, run it, then pull the artifact into the VM, convert to PNG.
import json, base64
from executor import aio

MODEL = "gemini-3-pro-image"
URL = f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
REFS = ["icon-crescent-cut.png"]  # bot artifact ids of style references (upload repo PNGs as artifacts first)
OUT_ID = "gen-output"
PROMPT = """The attached image is a style reference from the same game icon set. Match its style. Do not copy its shape. Make this new icon:
<main prompt>
Negative prompt: <negative list>"""

async def main():
    parts = []
    for r in REFS:
        parts.append({"inlineData": {"mimeType": "image/png", "data": base64.b64encode(await aio.get_artifact(r)).decode()}})
    parts.append({"text": PROMPT})
    body = {"contents": [{"role": "user", "parts": parts}],
            "generationConfig": {"responseModalities": ["TEXT", "IMAGE"], "imageConfig": {"aspectRatio": "1:1"}}}
    # body must be a dict, NOT json.dumps(...) (a string gives HTTP 400 "Root element must be a message")
    r = await aio.run_http(url=URL, method="POST", headers={"Content-Type": "application/json"}, body=body,
                           integration="__gemini-web-search", description=f"Generate Robby asset {OUT_ID} with {MODEL}")
    data = r.get("body")
    if isinstance(data, (bytes, str)):
        data = json.loads(data)
    for p in data.get("candidates", [{}])[0].get("content", {}).get("parts", []):
        d = p.get("inlineData") or p.get("inline_data")
        if d:
            img = base64.b64decode(d["data"])
            ct = "image/png" if img[:4] == b"\x89PNG" else "image/jpeg"  # usually JPEG; convert to PNG before saving to assets/source
            await aio.store_artifact(identifier=OUT_ID, title=OUT_ID, artifact_type="file", data=img,
                                     metadata={"file": {"file_name": OUT_ID + (".png" if ct == "image/png" else ".jpg"), "content_type": ct}})
            print("stored", len(img), ct); return
    print("no image:", json.dumps(data)[:400])