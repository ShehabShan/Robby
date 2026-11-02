--!strict
-- T-051a2 offline package-only check for the PLAY build. No runtime execution or publication.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local mode, candidatePath, outputPath, revision = table.unpack(process.args)
assert(mode == "stage" or mode == "verify", "unknown mode")
assert(type(revision) == "string" and #revision == 40 and not string.find(revision, "[^a-f0-9]"), "revision")
local expected = roblox.deserializePlace(fs.readFile(candidatePath))
local server = expected:GetService("ServerScriptService"):FindFirstChild("WindStepPlay")
local client = expected:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("WindStepPlayInput")
assert(server and server.ClassName == "Script", "play server entry")
assert(client and client.ClassName == "LocalScript", "play client entry")
assert(not server.Disabled and not client.Disabled, "play entries must be enabled")
local universe, place = server:GetAttribute("TestUniverseId"), server:GetAttribute("TestPlaceId")
assert(type(universe) == "number" and universe > 0 and universe ~= 10773761715, "test universe")
assert(type(place) == "number" and place > 0 and place ~= 95587500384127, "test place")
local entries = 0
for _, item in expected:GetDescendants() do
	assert(item.Name ~= "WindStepTest" and item.Name ~= "OwnerTestView", "harness/panel must be absent")
	if item:IsA("Script") or item:IsA("LocalScript") then
		assert(item == server or item == client, "unexpected executable")
		entries += 1
	end
end
assert(entries == 2, "entry count")
server:SetAttribute("SourceRevision", revision)
local bytes = roblox.serializePlace(expected)
if mode == "stage" then
	fs.writeFile(outputPath, bytes)
else
	assert(fs.readFile(outputPath) == bytes, "staged play package differs from exact rebuild")
end
print("LOCAL PLAY PACKAGE " .. mode .. " PASS; NOT publication approval")
