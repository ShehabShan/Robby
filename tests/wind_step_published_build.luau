-- Actual generated entry and place inspected offline; never actual physics evidence.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local luau = require("@lune/luau")
local Policy = require("./published/WindStepPublishedPolicy")
local Evidence = require("./studio/WindStepEvidence")
local source = fs.readFile("build/published-test/wind_step.server.luau")
local count = 0
local function test(name, fn)
	fn()
	count += 1
	print("PASS " .. name)
end
test("generated entry refuses before fixture/driver on every unsafe entry", function()
	for _, mode in
		{
			"no-target",
			"production-universe",
			"production-place",
			"studio",
			"client",
			"not-running",
			"not-opted",
			"wrong-universe",
			"wrong-place",
			"foreign-player",
			"two-players",
			"no-player",
			"no-version",
			"no-job",
			"already-ran",
		}
	do
		local attrs = {
			TestUniverseId = 123,
			TestPlaceId = 456,
			TestOwnerUserId = 7738981129,
			RunWindStep = true,
		}
		if mode == "no-target" then
			attrs.TestUniverseId = 0
		end
		if mode == "production-universe" then
			attrs.TestUniverseId = 10773761715
		end
		if mode == "production-place" then
			attrs.TestPlaceId = 95587500384127
		end
		if mode == "not-opted" then
			attrs.RunWindStep = false
		end
		if mode == "already-ran" then
			attrs.HasRun = true
		end
		local clock, warned = 0, false
		local run = {
			IsStudio = function()
				return mode == "studio"
			end,
			IsServer = function()
				return mode ~= "client"
			end,
			IsRunning = function()
				return mode ~= "not-running"
			end,
			GetRobloxVersion = function()
				return "SYNTHETIC"
			end,
		}
		local players = {
			GetPlayers = function()
				if mode == "no-player" then
					return {}
				end
				local owner = { UserId = if mode == "foreign-player" then 1 else 7738981129 }
				return if mode == "two-players" then { owner, owner } else { owner }
			end,
		}
		local chunk = luau.load(source, {
			environment = {
				game = {
					GameId = if mode == "wrong-universe" then 999 else 123,
					PlaceId = if mode == "wrong-place" then 999 else 456,
					PlaceVersion = if mode == "no-version" then 0 else 1,
					JobId = if mode == "no-job" then "" else "SYNTHETIC",
					GetService = function(_, name)
						return if name == "RunService" then run else if name == "Players" then players else {}
					end,
				},
				script = {
					Evidence = "evidence",
					PublishedPolicy = "policy",
					GetAttribute = function(_, name)
						return attrs[name]
					end,
					SetAttribute = function()
						error("must refuse before acquiring")
					end,
				},
				require = function(module)
					assert(module == "evidence" or module == "policy", "driver must not load")
					return if module == "evidence" then Evidence else Policy
				end,
				warn = function()
					warned = true
				end,
				workspace = { Gravity = 196.2 },
				os = {
					clock = function()
						return clock
					end,
				},
				task = {
					wait = function()
						clock += 1
					end,
				},
				Instance = {
					new = function()
						error("must not allocate fixture")
					end,
				},
			},
		})
		chunk()
		assert(warned, mode)
		assert(clock <= 121, "unbounded owner wait")
	end
end)
test("candidate disabled and unconfigured; exact sources and manifest", function()
	local place = roblox.deserializePlace(fs.readFile("build/published-test/WindStepPublishedCandidate.rbxl"))
	local script = place:GetService("ServerScriptService").WindStepTest
	assert(script.Disabled and script:GetAttribute("RunWindStep") == false)
	assert(script:GetAttribute("TestUniverseId") == 0 and script:GetAttribute("TestPlaceId") == 0)
	assert(script.Source == source)
	assert(script.PublishedPolicy.Source == fs.readFile("tests/published/WindStepPublishedPolicy.luau"))
	assert(script.OwnerTestSession.Source == fs.readFile("src/shared/OwnerTestSession.luau"))
	assert(script.OwnerTestAdapter.Source == fs.readFile("tests/published/OwnerTestAdapter.luau"))
	assert(script.OwnerTestTransport.Source == fs.readFile("tests/published/OwnerTestTransport.luau"))
	assert(script.Evidence.Source == fs.readFile("tests/studio/WindStepEvidence.luau"))
	assert(script.WindStepDriver.Source == fs.readFile("src/server/WindStepDriver.luau"))
	assert(script.WindStepClearance.Source == fs.readFile("src/server/WindStepClearance.luau"))
	assert(place:GetService("ReplicatedStorage").Shared.WindStep.Source == fs.readFile("src/shared/WindStep.luau"))
	local manifest = serde.decode("json", fs.readFile("build/published-test/manifest.json"))
	assert(manifest.publishReady == false and manifest.dynamicsAccepted == false)
	assert(manifest.generatedServerSha256 == serde.hash("sha256", source))
	assert(script:GetAttribute("GeneratedServerSha256") == manifest.generatedServerSha256)
	assert(
		manifest.placeSha256
			== serde.hash("sha256", fs.readFile("build/published-test/WindStepPublishedCandidate.rbxl"))
	)
	for path, hash in manifest.sourceHashes do
		assert(hash == serde.hash("sha256", fs.readFile(path)), path)
	end
	for _, item in place:GetDescendants() do
		assert(not item:IsA("LocalScript"))
		if item:IsA("Script") then
			assert(item == script)
		end
	end
end)
test("normal and Studio builds stay isolated", function()
	for _, path in { "build/Robby.rbxl", "build/WindStepTest.rbxl" } do
		local place = roblox.deserializePlace(fs.readFile(path))
		for _, item in place:GetDescendants() do
			assert(item.Name ~= "PublishedPolicy")
			assert(item:GetAttribute("TestUniverseId") == nil)
		end
	end
end)
print("Published candidate groups: " .. count .. " (offline only)")
