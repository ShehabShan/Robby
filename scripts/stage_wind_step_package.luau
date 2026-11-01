--!strict
-- Offline package-only transformation. No runtime execution or publication.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local mode, candidatePath, outputPath, revision = table.unpack(process.args)
assert(mode == "stage" or mode == "verify", "unknown mode")
assert(type(revision) == "string" and #revision == 40 and not string.find(revision, "[^a-f0-9]"), "revision")
local expected = roblox.deserializePlace(fs.readFile(candidatePath))
local server = expected:GetService("ServerScriptService").WindStepTest
local client = expected:GetService("StarterPlayer").StarterPlayerScripts.WindStepOwner
assert(server.ClassName == "Script" and client.ClassName == "LocalScript", "entry classes changed")
assert(
	server.Disabled and client.Disabled and server:GetAttribute("RunWindStep") == false,
	"candidate must be disabled"
)
assert(not server:GetAttribute("HasRun"), "candidate already ran")
local universe, place, owner =
	server:GetAttribute("TestUniverseId"), server:GetAttribute("TestPlaceId"), server:GetAttribute("TestOwnerUserId")
assert(type(universe) == "number" and universe > 0 and universe ~= 10773761715, "test universe")
assert(type(place) == "number" and place > 0 and place ~= 95587500384127, "test place")
assert(owner == 7738981129, "test owner")
local entries = 0
for _, item in expected:GetDescendants() do
	if item:IsA("Script") or item:IsA("LocalScript") then
		assert(item == server or item == client, "unexpected executable")
		entries += 1
	end
end
assert(entries == 2, "entry count")
-- The only differences permitted from a freshly reconstructed candidate.
server.Disabled = false
client.Disabled = false
server:SetAttribute("RunWindStep", true)
server:SetAttribute("SourceRevision", revision)
local bytes = roblox.serializePlace(expected)
if mode == "stage" then
	fs.writeFile(outputPath, bytes)
else
	local actual = fs.readFile(outputPath)
	-- No untrusted code is executed. Exact bytes include all instances, properties,
	-- attributes and module sources; no permissive traversal can hide extra scripts.
	assert(actual == bytes, "staged package differs from exact rebuilt enabled test")
end
print("LOCAL PACKAGE " .. mode .. " PASS; NOT publication/dynamics acceptance")
