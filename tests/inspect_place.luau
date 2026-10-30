-- T-005 local check (.ai/SPIKE.md §6.2): opens build/Robby.rbxl with Lune and asserts that
-- Rojo put the scripts and modules where the game expects them. Run: `lune run tests/inspect_place.luau`.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local game = roblox.deserializePlace(fs.readFile("build/Robby.rbxl"))
local failures = 0

local function expect(path: { string }, className: string)
	local node: any = game
	for _, name in path do
		node = if node then node:FindFirstChild(name) else nil
	end
	local label = table.concat(path, ".")
	if node and node.ClassName == className then
		print("PASS " .. label .. " (" .. className .. ")")
	else
		failures += 1
		print("FAIL " .. label .. " expected " .. className .. ", got " .. (if node then node.ClassName else "nothing"))
	end
end

expect({ "ReplicatedStorage", "Shared", "Config" }, "ModuleScript")
expect({ "ReplicatedStorage", "Shared", "Qi" }, "ModuleScript")
expect({ "ReplicatedStorage", "Shared", "Deliveries", "Projectile" }, "ModuleScript")
expect({ "ServerScriptService", "Server" }, "Script")
expect({ "ServerScriptService", "Server", "Abilities" }, "ModuleScript")
expect({ "ServerScriptService", "Server", "Dummy" }, "ModuleScript")
expect({ "StarterPlayer", "StarterPlayerScripts", "Client" }, "LocalScript")
expect({ "StarterPlayer", "StarterPlayerScripts", "Client", "AbilityInput" }, "ModuleScript")
expect({ "StarterPlayer", "StarterPlayerScripts", "Client", "CrescentFx" }, "ModuleScript")

expect({ "ReplicatedStorage", "Shared", "MistvaleLayout" }, "ModuleScript")
expect({ "ServerScriptService", "Server", "MistvaleTerrain" }, "ModuleScript")
if game:GetService("Workspace").StreamingEnabled == true then
	print("PASS Workspace.StreamingEnabled")
else
	failures += 1
	print("FAIL Workspace.StreamingEnabled")
end

local stale = game:GetService("ReplicatedStorage"):FindFirstChild("Shared")
if stale and stale:FindFirstChild("RoundState") then
	failures += 1
	print("FAIL obby sample RoundState still present")
end

print(if failures == 0 then "INSPECT: PASS" else "INSPECT: FAIL (" .. failures .. ")")
process.exit(if failures == 0 then 0 else 1)
