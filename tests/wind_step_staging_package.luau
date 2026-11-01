--!strict
-- Offline inspection/tampering fixtures. NEVER execution or real Roblox evidence.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local input, directory = table.unpack(process.args)
local raw = fs.readFile(input)
local place = roblox.deserializePlace(raw)
local server = place:GetService("ServerScriptService").WindStepTest
local client = place:GetService("StarterPlayer").StarterPlayerScripts.WindStepOwner
assert(not server.Disabled and not client.Disabled and server:GetAttribute("RunWindStep") == true)
assert(server:GetAttribute("TestUniverseId") == 123456 and server:GetAttribute("TestPlaceId") == 654321)
assert(server:GetAttribute("TestOwnerUserId") == 7738981129 and not server:GetAttribute("HasRun"))
assert(server.Source == fs.readFile("build/published-test/wind_step.server.luau"))
assert(client.Source == fs.readFile("tests/published/wind_step.client.luau"))
local count = 0
local hashes = serde.decode("json", server:GetAttribute("SourceHashes"))
for path, hash in hashes do
	assert(hash == serde.hash("sha256", fs.readFile(path)), path)
	count += 1
end
assert(count == 17)
assert(server:GetAttribute("GeneratedServerSha256") == serde.hash("sha256", server.Source))
local mutations = {
	["disabled-server"] = function(p)
		p:GetService("ServerScriptService").WindStepTest.Disabled = true
	end,
	["disabled-client"] = function(p)
		p:GetService("StarterPlayer").StarterPlayerScripts.WindStepOwner.Disabled = true
	end,
	["no-opt-in"] = function(p)
		p:GetService("ServerScriptService").WindStepTest:SetAttribute("RunWindStep", false)
	end,
	["wrong-target"] = function(p)
		p:GetService("ServerScriptService").WindStepTest:SetAttribute("TestPlaceId", 99)
	end,
	["replayed"] = function(p)
		p:GetService("ServerScriptService").WindStepTest:SetAttribute("HasRun", true)
	end,
	["changed-worker"] = function(p)
		p:GetService("ServerScriptService").WindStepTest.Source ..= "\n-- changed"
	end,
	["changed-driver"] = function(p)
		p:GetService("ServerScriptService").WindStepTest.WindStepDriver.Source ..= "\n-- changed"
	end,
	["changed-ui"] = function(p)
		p:GetService("StarterPlayer").StarterPlayerScripts.WindStepOwner.OwnerTestView.Source ..= "\n-- changed"
	end,
	["extra-executable"] = function(p)
		local other = roblox.Instance.new("Script")
		other.Name = "Unexpected"
		other.Parent = p:GetService("Workspace")
	end,
	["extra-module"] = function(p)
		local other = roblox.Instance.new("ModuleScript")
		other.Name = "UnexpectedModule"
		other.Parent = p:GetService("ServerScriptService")
	end,
	["changed-scene"] = function(p)
		p:GetService("Workspace").Spawn.Anchored = false
	end,
	["wrong-source-revision"] = function(p)
		p:GetService("ServerScriptService").WindStepTest:SetAttribute("SourceRevision", string.rep("0", 40))
	end,
	["wrong-embedded-hashes"] = function(p)
		p:GetService("ServerScriptService").WindStepTest:SetAttribute("SourceHashes", "{}")
	end,
	["wrong-generated-hash"] = function(p)
		p:GetService("ServerScriptService").WindStepTest:SetAttribute("GeneratedServerSha256", string.rep("0", 64))
	end,
}
for name, mutate in mutations do
	local changed = roblox.deserializePlace(raw)
	mutate(changed)
	fs.writeFile(directory .. "/" .. name .. ".rbxl", roblox.serializePlace(changed))
end
local candidate = roblox.deserializePlace(fs.readFile("build/published-test/WindStepPublishedCandidate.rbxl"))
assert(candidate:GetService("ServerScriptService").WindStepTest.Disabled)
assert(candidate:GetService("ServerScriptService").WindStepTest:GetAttribute("RunWindStep") == false)
assert(candidate:GetService("StarterPlayer").StarterPlayerScripts.WindStepOwner.Disabled)
print("Staging exact-source/enablement inspection PASS; 14 hostile package fixtures; OFFLINE ONLY")
