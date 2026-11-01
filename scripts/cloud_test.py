"""T-005b: upload build/Robby.rbxl as a Saved (unpublished) version, then run tests/cloud/smoke.luau
as an Open Cloud Luau Execution task and print the result. Usage: python3 scripts/cloud_test.py"""
import json, os, sys, time, urllib.request, urllib.error
sys.path.insert(0, os.path.dirname(__file__))
import cloud_runner

U, P = "10773761715", "95587500384127"
BASE = os.environ["PROMPTQL_PLATFORM_API_URL"] + "/v1/integration/roblox-open-cloud/apis.roblox.com"
JWT = os.environ["PROMPTQL_USER_JWT"]

def call(method, path, body=None, ctype="application/json", desc="Robby cloud test (T-005b)", timeout=120):
    req = urllib.request.Request(BASE + path, data=body, method=method, headers={
        "Authorization": f"Bearer {JWT}", "Content-Type": ctype, "X-PromptQL-Description": desc})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()[:500]

def main():
    if len(sys.argv) > 1:  # reuse an already uploaded version: python3 scripts/cloud_test.py <version>
        v = int(sys.argv[1])
    else:
        data = open("build/Robby.rbxl", "rb").read()
        st, res = call("POST", f"/universes/v1/{U}/places/{P}/versions?versionType=Saved", data,
                       "application/octet-stream", "Upload the Robby build as a Saved (unpublished) place version",
                       timeout=600)  # S12: 120s timed out twice on upload in S11
        print("upload:", st, res)
        if st != 200:
            sys.exit(1)
        v = res["versionNumber"]
    script = cloud_runner.build()  # T-010: all Lune specs + packages + smoke, in the real engine
    st, task = call("POST", f"/cloud/v2/universes/{U}/places/{P}/versions/{v}/luau-execution-session-tasks",
                    json.dumps({"script": script, "timeout": "120s"}).encode(),
                    desc="Run the Robby smoke test script on the uploaded place version")
    print("task:", st, task if st != 200 else task.get("path"))
    if st != 200:
        sys.exit(1)
    path = "/cloud/v2/" + task["path"]
    for _ in range(60):
        time.sleep(3)
        st, task = call("GET", path, desc="Poll the smoke test task")
        state = task.get("state") if isinstance(task, dict) else None
        if state in ("COMPLETE", "FAILED", "CANCELLED"):
            break
    print("state:", state)
    print("output:", json.dumps(task.get("output"), indent=1) if isinstance(task, dict) else task)
    if isinstance(task, dict) and task.get("error"):
        print("error:", task["error"])
    st, logs = call("GET", path + "/logs", desc="Read the smoke test logs")
    print("logs:", st, str(logs)[:1500])
    print("VERSION:", v)

if __name__ == "__main__":
    main()
