-- T-051a: inspect the built play place (build/play-test/WindStepPlay.rbxl). Asserts the R dash
-- wiring is present and the automated harness / blocking owner panel are absent.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local game = roblox.deserializePlace(fs.readFile("build/play-test/WindStepPlay.rbxl"))
local failures = 0
local function check(ok: boolean, msg: string)
	if not ok then
		failures += 1
		print("FAIL " .. msg)
	end
end
local function find(path: { string }): any
	local node: any = game
	for _, name in path do
		node = if node then node:FindFirstChild(name) else nil
	end
	return node
end

local server = find({ "ServerScriptService", "WindStepPlay" })
check(server ~= nil and server.ClassName == "Script" and not server.Disabled, "enabled play server script")
check(server and server:GetAttribute("TestUniverseId") == 0, "unbound build has no target")
check(server and server:FindFirstChild("WindStepDriver") ~= nil, "driver bundled")
check(server and server:FindFirstChild("WindStepClearance") ~= nil, "clearance bundled")
check(find({ "ReplicatedStorage", "Shared", "WindStep" }) ~= nil, "motion module")
check(find({ "ReplicatedStorage", "Shared", "WindStepPlay" }) ~= nil, "play gate module")
local client = find({ "StarterPlayer", "StarterPlayerScripts", "WindStepPlayInput" })
check(client ~= nil and client.ClassName == "LocalScript", "client input script")
check(client and string.find(client.Source, "KeyCode.R", 1, true) ~= nil, "R binding")
check(client and string.find(client.Source, "FireServer", 1, true) ~= nil, "server request")
check(server and string.find(server.Source, "Driver.prepare", 1, true) ~= nil, "WindStepDriver dash")
check(find({ "ServerScriptService", "WindStepTest" }) == nil, "no automated harness")
for _, item in game:GetDescendants() do
	check(item.Name ~= "OwnerTestView" and item.Name ~= "WindStepOwner", "no blocking owner panel: " .. item.Name)
end
check(find({ "Workspace", "Ground" }) ~= nil and find({ "Workspace", "WallNorth" }) ~= nil, "ground and walls")
print(`wind-step-play-place: {failures} failures`)
process.exit(if failures == 0 then 0 else 1)
