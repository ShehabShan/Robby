"""T-057e (D-418): check in the real engine whether AssetIds.images textures fetch.
Runs ContentProvider:PreloadAsync on every image id in src/shared/AssetIds.luau inside an Open Cloud
Luau Execution task on an existing Saved place version. Read-only (no upload).
Usage: python3 scripts/texture_probe.py <savedVersion>"""
import json, os, re, sys, time
sys.path.insert(0, os.path.dirname(__file__))
from cloud_test import call, U, P

def ids():
    src = open("src/shared/AssetIds.luau").read()
    block = src.split("AssetIds.images = {", 1)[1].split("}", 1)[0]
    return re.findall(r"(\w+)\s*=\s*(\d+)", block)

def script(pairs):
    items = ",".join(f'{{"{n}",{i}}}' for n, i in pairs)
    return f"""
local CP = game:GetService("ContentProvider")
local out = {{}}
for _, p in {{{items}}} do
	local d = Instance.new("Decal")
	d.Texture = "rbxassetid://" .. p[2]
	local st = "?"
	local ok, err = pcall(function()
		CP:PreloadAsync({{d}}, function(_, s) st = s.Name end)
	end)
	table.insert(out, p[1] .. "=" .. (ok and st or ("ERR " .. tostring(err))))
end
return table.concat(out, " ")
"""

def main():
    v = int(sys.argv[1])
    st, task = call("POST", f"/cloud/v2/universes/{U}/places/{P}/versions/{v}/luau-execution-session-tasks",
                    json.dumps({"script": script(ids()), "timeout": "120s"}).encode(),
                    desc="Robby T-057e: check crescent textures load (read-only)")
    if st != 200:
        print("task:", st, task); sys.exit(1)
    path = "/cloud/v2/" + task["path"]
    for _ in range(60):
        time.sleep(3)
        st, task = call("GET", path, desc="Poll the texture check task")
        if isinstance(task, dict) and task.get("state") in ("COMPLETE", "FAILED", "CANCELLED"):
            break
    print("state:", task.get("state"), "output:", json.dumps(task.get("output")), "error:", task.get("error"))

if __name__ == "__main__":
    main()
