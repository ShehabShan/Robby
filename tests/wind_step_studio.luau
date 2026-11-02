-- Offline checks of policy, disabled guards and packaged boundaries. NOT engine evidence.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local process = require("@lune/process")
local luau = require("@lune/luau")
local Evidence = require("./studio/WindStepEvidence")
local count = 0
local function test(name, fn)
	fn()
	count += 1
	print("PASS " .. name)
end
local function row(name, kind)
	return {
		name = name or "travel-auto",
		kind = kind or "travel",
		committed = true,
		clean = true,
		restored = true,
		phaseOK = true,
		distance = 14,
		maxX = 14,
		elapsed = 0.24,
		minDt = 1 / 60,
		maxDt = 1 / 60,
		pairs = 15,
		maxYError = 0,
		maxYDip = 0,
		maxSide = 0,
		commandedDistance = 14,
		lastSpeed = 1,
		simulatedSeconds = 0.25,
	}
end
local env = { studio = true, server = true, running = true, optIn = true, players = 1 }
local function rows()
	local result = {}
	for _, mode in { "auto", "player", "server" } do
		table.insert(result, row("travel-" .. mode))
	end
	local wall = row("wall", "wall")
	wall.distance, wall.maxX = 4.8, 4.8
	table.insert(result, wall)
	table.insert(result, row("fall", "fall"))
	local cancel = row("cancel", "cancel")
	cancel.distance, cancel.maxX, cancel.cancelled, cancel.velocityKept = 3, 3, true, true
	table.insert(result, cancel)
	for i = 1, 100 do
		table.insert(result, row("lifetime-" .. i))
	end
	return result
end
test("all guard combinations refuse except explicit single-player Studio Play", function()
	for mask = 0, 15 do
		for _, players in { 0, 1, 2 } do
			assert(
				Evidence.guard(
					bit32.band(mask, 1) ~= 0,
					bit32.band(mask, 2) ~= 0,
					bit32.band(mask, 4) ~= 0,
					bit32.band(mask, 8) ~= 0,
					players
				) == (mask == 15 and players == 1)
			)
		end
	end
end)
test("every named case is mandatory, failures cannot be hidden by counters", function()
	assert(Evidence.finish(env, rows(), true).matrixPassed)
	assert(not Evidence.finish(env, rows(), true).dynamicsAccepted)
	for i = 1, 106 do
		local all = rows()
		table.remove(all, i)
		assert(not Evidence.finish(env, all, true).matrixPassed)
		all = rows()
		all[i].clean = false
		assert(not Evidence.finish(env, all, true).matrixPassed)
	end
end)
test("duplicate unknown renamed and malformed cases refuse", function()
	for _, mode in { "duplicate", "unknown", "kind", "malformed" } do
		local all = rows()
		if mode == "duplicate" then
			all[2] = all[1]
		elseif mode == "unknown" then
			all[1].name = "other"
		elseif mode == "kind" then
			all[1].kind = "cancel"
		else
			all[1] = false
		end
		assert(not Evidence.finish(env, all, true).matrixPassed)
	end
	assert(not Evidence.finish(env, rows(), false).matrixPassed)
end)
test("force simulation ownership cleanup and cancellation cannot be bypassed", function()
	for _, flag in { "committed", "clean", "restored", "phaseOK" } do
		local r = row()
		r[flag] = false
		assert(not Evidence.accept(r))
	end
	local r = rows()[6]
	r.velocityKept = false
	assert(not Evidence.accept(r))
	r = rows()[6]
	r.cancelled = false
	assert(not Evidence.accept(r))
end)
test("bad intervals, nonfinite metrics, missing physics and incorrect displacement refuse", function()
	for key, value in { distance = 0, maxX = 16, elapsed = 0.7, minDt = 0, maxDt = 0.051, pairs = 0, maxSide = 0.6 } do
		local r = row()
		r[key] = value
		assert(not Evidence.accept(r), key)
	end
	for _, key in
		{
			"distance",
			"maxX",
			"elapsed",
			"minDt",
			"maxDt",
			"pairs",
			"maxYError",
			"maxYDip",
			"maxSide",
			"commandedDistance",
			"lastSpeed",
			"simulatedSeconds",
		}
	do
		for _, value in { 0 / 0, math.huge, "14" } do
			local r = row()
			r[key] = value
			assert(not Evidence.accept(r), key)
		end
	end
	local r = row("wall", "wall")
	r.distance, r.maxX = 4, 5.1
	assert(not Evidence.accept(r))
	r = row("fall", "fall")
	r.maxYError = 2.1
	assert(not Evidence.accept(r))
	for _, kind in { "travel", "wall", "cancel" } do
		r = row(kind, kind)
		r.maxYDip = 0.59 -- version5 mid-dash dip must be caught (D-364)
		assert(not Evidence.accept(r), kind)
	end
	r = row("fall", "fall")
	r.maxYDip = 3
	assert(Evidence.accept(r))
	-- Rate variation / final partial step (D-365): supported rates accepted, unsupported or inconsistent rejected.
	for _, rate in { { 1 / 240, 1 / 240, 60 }, { 1 / 30, 1 / 30, 8 }, { 1 / 240, 1 / 30, 20 } } do
		r = row()
		r.minDt, r.maxDt, r.pairs = rate[1], rate[2], rate[3]
		assert(Evidence.accept(r), "rate " .. rate[3])
	end
	r = row()
	r.maxDt = 0.06
	assert(not Evidence.accept(r))
	r = row()
	r.minDt, r.maxDt = 1 / 30, 1 / 60
	assert(not Evidence.accept(r))
	r = row()
	r.distance, r.maxX, r.commandedDistance, r.simulatedSeconds = 13.2, 13.2, 13.1, 0.29
	assert(Evidence.accept(r), "final partial within tolerance")
	r.commandedDistance = 12.9 -- version3/4-sized deficit stays a failure
	assert(not Evidence.accept(r))
	r = row()
	r.simulatedSeconds = 0.3
	assert(not Evidence.accept(r))
end)
test("real harness returns before acquiring fixture or driver when not opted in", function()
	local source = fs.readFile("tests/studio/wind_step.server.luau")
	for _, mode in { "not-studio", "not-running", "client", "not-opted" } do
		local ran = false
		local runService = {
			IsStudio = function()
				return mode ~= "not-studio"
			end,
			IsRunning = function()
				return mode ~= "not-running"
			end,
			IsServer = function()
				return mode ~= "client"
			end,
		}
		local chunk = luau.load(source, {
			environment = {
				game = {
					GetService = function(_, name)
						return if name == "RunService" then runService else {}
					end,
				},
				script = {
					Evidence = {},
					GetAttribute = function()
						return mode ~= "not-opted"
					end,
				},
				require = function()
					return Evidence
				end,
				warn = function()
					ran = true
				end,
				Instance = {
					new = function()
						error("must not acquire")
					end,
				},
			},
		})
		chunk()
		assert(ran)
	end
end)
test("Studio bootstrap uses public engine version at ordinary Script identity", function()
	local source = fs.readFile("tests/studio/wind_step.server.luau")
	local reachedGuard, calls = false, 0
	local run = {
		IsStudio = function()
			return true
		end,
		IsServer = function()
			return true
		end,
		IsRunning = function()
			return true
		end,
		GetRobloxVersion = function()
			error("RobloxScriptSecurity")
		end,
	}
	local chunk = luau.load(source, {
		environment = {
			version = function()
				calls += 1
				return "PUBLIC-SYNTHETIC"
			end,
			game = {
				PlaceVersion = 0,
				GetService = function(_, name)
					return if name == "RunService"
						then run
						else if name == "Players"
							then {
								GetPlayers = function()
									return { {} }
								end,
							}
							else {}
				end,
			},
			script = {
				Evidence = {},
				GetAttribute = function(_, name)
					return name == "RunWindStep"
				end,
			},
			require = function()
				return {
					guard = function()
						reachedGuard = true
						return false -- stop after environment construction; never run physics here
					end,
				}
			end,
			workspace = { Gravity = 196.2 },
			task = { wait = function() end },
			warn = function() end,
			Instance = {
				new = function()
					error("must not acquire")
				end,
			},
		},
	})
	chunk()
	assert(reachedGuard and calls == 1, "public version must reach ordinary Script admission")
end)
test("boolean environment and cleanup gates cannot be truthy strings", function()
	for _, key in { "studio", "running", "server", "optIn", "players" } do
		local invalid = table.clone(env)
		invalid[key] = "true"
		assert(not Evidence.finish(invalid, rows(), true).matrixPassed)
	end
	assert(not Evidence.finish(env, rows(), "true").matrixPassed)
end)
local isolated = roblox.deserializePlace(fs.readFile("build/WindStepTest.rbxl"))
local default = roblox.deserializePlace(fs.readFile("build/Robby.rbxl"))
test("isolated build disabled, actual source exact; no gameplay startup or client", function()
	local script = isolated:GetService("ServerScriptService"):FindFirstChild("WindStepTest")
	assert(script and script.Disabled and script:GetAttribute("RunWindStep") == false)
	local hashes = serde.decode("json", script:GetAttribute("SourceHashes"))
	for path, hash in hashes do
		assert(serde.hash("sha256", fs.readFile(path)) == hash, path)
	end
	assert(hashes["src/server/WindStepDriver.luau"] and hashes["tests/studio/wind_step.server.luau"])
	local revision = process.exec("git", { "rev-parse", "HEAD" }).stdout:gsub("%s+$", "")
	assert(script:GetAttribute("SourceRevision") == revision)

	assert(script.Source == fs.readFile("tests/studio/wind_step.server.luau"))
	assert(script.WindStepDriver.Source == fs.readFile("src/server/WindStepDriver.luau"))
	assert(script.WindStepClearance.Source == fs.readFile("src/server/WindStepClearance.luau"))
	assert(isolated:GetService("ReplicatedStorage").Shared.WindStep.Source == fs.readFile("src/shared/WindStep.luau"))
	for _, descendant in isolated:GetDescendants() do
		if descendant:IsA("Script") then
			assert(descendant == script)
		end
		assert(not descendant:IsA("LocalScript"))
	end
end)
test("default build does not contain harness or evidence module", function()
	for _, descendant in default:GetDescendants() do
		assert(descendant.Name ~= "WindStepTest" and descendant.Name ~= "Evidence")
	end
end)
print("wind-step-studio: " .. count .. " offline groups PASS; NO real dynamics evidence")
