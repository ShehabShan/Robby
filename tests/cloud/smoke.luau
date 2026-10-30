--!nocheck
-- T-005b cloud smoke test: runs inside the uploaded place via Open Cloud Luau Execution.
-- Checks that the server wiring started (dummy + remotes) and that Crescent Cut rank-1 damage takes 20 HP off the dummy.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function waitFor(fn, seconds)
	local t = 0
	while t < seconds do
		local v = fn()
		if v then
			return v
		end
		t += task.wait(0.25)
	end
	return nil
end

local results = {}
local function check(name, ok, detail)
	table.insert(results, string.format("%s %s %s", ok and "PASS" or "FAIL", name, tostring(detail or "")))
	return ok
end

-- Luau Execution sessions may not auto-run place Scripts, so start the server wiring modules if nothing exists yet.
local autoRan = waitFor(function()
	return workspace:FindFirstChild("TrainingDummy")
end, 3) ~= nil
if not autoRan then
	local server = game:GetService("ServerScriptService"):FindFirstChild("Server")
	local started = pcall(function()
		require(server.Dummy).start()
		require(server.Abilities).start()
	end)
	check("manual start of server modules", started)
end
print("server scripts auto-ran: " .. tostring(autoRan))

local dummy = waitFor(function()
	return workspace:FindFirstChild("TrainingDummy")
end, 10)
check("dummy exists", dummy ~= nil)

local humanoid = dummy and dummy:FindFirstChildOfClass("Humanoid")
check("dummy humanoid", humanoid ~= nil)

local remotes = waitFor(function()
	return ReplicatedStorage:FindFirstChild("Remotes", true)
end, 10)
check("remotes folder", remotes ~= nil, remotes and #remotes:GetChildren() or 0)

local ok, CrescentCut = pcall(function()
	return require(ReplicatedStorage.Shared.Kith.CrescentCut)
end)
local Config = ok and require(ReplicatedStorage.Shared.Config)
local dmg = ok and CrescentCut.damageFor(1, Config.Abilities.CrescentCut)
check("damageFor(1) == 20", dmg == 20, dmg)

if humanoid and dmg then
	local before = humanoid.Health
	humanoid:TakeDamage(dmg)
	check("dummy HP -20", before - humanoid.Health == 20, string.format("%d -> %d", before, humanoid.Health))
end

local allPass = true
for _, r in results do
	print(r)
	if r:sub(1, 4) ~= "PASS" then
		allPass = false
	end
end
print(allPass and "CLOUD: PASS" or "CLOUD: FAIL")
return allPass, table.concat(results, " | ")
