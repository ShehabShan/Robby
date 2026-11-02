-- Synthetic policy tests only. NOT engine execution evidence.
local Policy = require("./published/WindStepPublishedPolicy")
local Canonical = require("./studio/WindStepEvidence")
local fs = require("@lune/fs")
local count = 0
local function test(name, fn)
	fn()
	count += 1
	print("PASS " .. name)
end
local target = { universeId = 123, placeId = 456, ownerUserId = 7738981129 }
local env = {
	studio = false,
	running = true,
	server = true,
	optIn = true,
	players = 1,
	playerUserId = 7738981129,
	universeId = 123,
	placeId = 456,
	placeVersion = 1,
	jobId = "SYNTHETIC-NOT-ROBLOX",
}
local function rows()
	local result = {}
	local function add(name, kind)
		local distance = if kind == "wall" then 4 else if kind == "cancel" then 3 else 14
		table.insert(result, {
			name = name,
			kind = kind,
			committed = true,
			clean = true,
			restored = true,
			phaseOK = true,
			distance = distance,
			maxX = distance,
			elapsed = 0.24,
			minDt = 0.02,
			maxDt = 0.02,
			pairs = 12,
			maxYError = 0,
			maxYDip = 0,
			maxSide = 0,
			commandedDistance = distance,
			lastSpeed = 0,
			simulatedSeconds = 0.24,
			cancelled = kind == "cancel",
			velocityKept = kind == "cancel",
		})
	end
	for _, name in { "travel-auto", "travel-player", "travel-server" } do
		add(name, "travel")
	end
	for _, kind in { "wall", "fall", "cancel" } do
		add(kind, kind)
	end
	for i = 1, 100 do
		add("lifetime-" .. i, "travel")
	end
	return result
end
test("exact live admission; no Studio impersonation", function()
	assert(Policy.guard(target, env))
	assert(not Canonical.guard(false, true, true, true, 1))
	for key, value in
		{
			studio = true,
			running = false,
			server = false,
			optIn = false,
			players = 0,
			playerUserId = 1,
			universeId = 124,
			placeId = 457,
			placeVersion = 0,
			jobId = "",
		}
	do
		local changed = table.clone(env)
		changed[key] = value
		assert(not Policy.guard(target, changed), key)
		changed[key] = nil
		assert(not Policy.guard(target, changed), "missing " .. key)
	end
	local changed = table.clone(env)
	changed.players = 2
	assert(not Policy.guard(target, changed))
end)
test("unconfigured production and invalid targets refuse", function()
	for _, invalid in { 0, -1, 1.5, math.huge, 0 / 0, "123", false } do
		for _, key in { "universeId", "placeId", "ownerUserId" } do
			local changed = table.clone(target)
			changed[key] = invalid
			assert(not Policy.target(changed), key)
		end
	end
	for key, value in { universeId = 10773761715, placeId = 95587500384127, ownerUserId = 1 } do
		local changed = table.clone(target)
		changed[key] = value
		assert(not Policy.target(changed), key)
	end
	assert(not Policy.target({}) and not Policy.target(nil))
end)
test("all admission combinations fail closed", function()
	for mask = 0, 15 do
		for _, players in { 0, 1, 2 } do
			local changed = table.clone(env)
			changed.studio = bit32.band(mask, 1) == 0
			changed.running = bit32.band(mask, 2) ~= 0
			changed.server = bit32.band(mask, 4) ~= 0
			changed.optIn = bit32.band(mask, 8) ~= 0
			changed.players = players
			assert(Policy.guard(target, changed) == (mask == 15 and players == 1))
		end
	end
end)
test("truthful published kind and first-slice-only result", function()
	local report = Policy.finish(target, env, rows(), true, Canonical)
	assert(report.matrixPassed and report.passed == 106 and report.expected == 106)
	assert(report.kind == "WindStep isolated published dynamics")
	assert(report.environment.studio == false and report.environment == env)
	assert(not report.dynamicsAccepted and #report.remaining == 3)
	assert(not Policy.finish(target, env, rows(), false, Canonical).matrixPassed)
	local changed = table.clone(env)
	changed.players = 2
	assert(not Policy.finish(target, changed, rows(), true, Canonical).matrixPassed)
end)
test("same canonical tolerances and complete case set; every omission or failure refuses", function()
	local studio = { studio = true, running = true, server = true, optIn = true, players = 1 }
	assert(Canonical.finish(studio, rows(), true).matrixPassed)
	for i = 1, 106 do
		for _, mode in { "missing", "failed", "duplicate", "unknown", "wrong-kind" } do
			local changed = rows()
			if mode == "missing" then
				table.remove(changed, i)
			elseif mode == "failed" then
				changed[i].distance = 99
			elseif mode == "duplicate" then
				changed[i].name = changed[if i == 1 then 2 else 1].name
			elseif mode == "unknown" then
				changed[i].name = "unknown"
			else
				changed[i].kind = "unknown"
			end
			local live = Policy.finish(target, env, changed, true, Canonical)
			local original = Canonical.finish(studio, changed, true)
			assert(not live.matrixPassed and live.matrixPassed == original.matrixPassed)
			assert(live.passed == original.passed and live.expected == original.expected)
		end
	end
end)
test("no game build inclusion or environment side effects", function()
	local project = fs.readFile("default.project.json")
	assert(not string.find(project, "tests/published", 1, true))
	local original = table.clone(env)
	Policy.finish(target, env, rows(), true, Canonical)
	for key, value in original do
		assert(env[key] == value)
	end
end)
print("Published policy groups: " .. count .. " (synthetic only)")
