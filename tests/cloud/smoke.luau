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

-- Luau Execution is not a running server (RunService:IsRunning() == false), so Blink returns no-op stubs and
-- creates no remote instances (D-060). There, check the Net API loads; remote instances are checked when running.
if game:GetService("RunService"):IsRunning() then
	local remotes = waitFor(function()
		return ReplicatedStorage:FindFirstChild("BLINK_RELIABLE_REMOTE")
			and ReplicatedStorage:FindFirstChild("BLINK_UNRELIABLE_REMOTE")
	end, 10)
	check("blink remotes", remotes ~= nil)
else
	local server = game:GetService("ServerScriptService"):FindFirstChild("Server")
	local ok, net = pcall(function()
		return require(server.Net)
	end)
	local api = ok
		and type(net) == "table"
		and type(net.CastRequest.On) == "function"
		and type(net.Action.On) == "function"
		and type(net.HitFx.FireAll) == "function"
		and type(net.CastFx.FireAll) == "function"
	check("blink remotes (API; instances need a running server)", api == true)
end

-- T-021a: Mistvale terrain is written and walkable (ground under spawn, zone 1 and the path).
local srv = game:GetService("ServerScriptService"):FindFirstChild("Server")
if not workspace:GetAttribute("MistvaleBuilt") then
	local built, err = pcall(function()
		require(srv.MistvaleTerrain).start()
	end)
	check("manual start of MistvaleTerrain", built, err)
end
-- Ground check reads the written voxels (D-167): Luau Execution sessions do not step physics, so terrain
-- collision is not built and raycasts miss it (S31 probe: voxels present, Raycast nil).
for _, p in { { "spawn", 0, 0, 0 }, { "path", 40, -140, 4 }, { "zone1", 80, -280, 8 } } do
	local r = Region3.new(Vector3.new(p[2], -64, p[3]), Vector3.new(p[2] + 4, 200, p[3] + 4)):ExpandToGrid(4)
	local mats, occ = workspace.Terrain:ReadVoxels(r, 4)
	local top = nil
	for y = 1, occ.Size.Y do
		if occ[1][y][1] > 0.5 then
			top = y
		end
	end
	local y = top and (r.CFrame.Position.Y - r.Size.Y / 2 + top * 4)
	local ok = y ~= nil and math.abs(y - p[4]) < 6 and mats[1][top][1] ~= Enum.Material.Water
	check("terrain ground at " .. p[1], ok, y)
end
check("StreamingEnabled", workspace.StreamingEnabled == true)

local ok, DamageMath = pcall(function()
	return require(ReplicatedStorage.Shared.DamageMath)
end)
local Config = ok and require(ReplicatedStorage.Shared.Config)
local dmg = ok and DamageMath.compute({ base = Config.Abilities.CrescentCut.baseDamage, rank = 1 })
check("damageFor(1) == 20", dmg == 20, dmg)

if humanoid and dmg then
	local before = humanoid.Health
	humanoid:TakeDamage(dmg)
	check("dummy HP -20", before - humanoid.Health == 20, string.format("%d -> %d", before, humanoid.Health))
end

local okMock, mockVersion = pcall(function()
	local ProfileStore = require(game:GetService("ServerScriptService").ServerPackages.ProfileStore)
	local ProfileSchema = require(ReplicatedStorage.Shared.ProfileSchema)
	local store = ProfileStore.New("SmokeTest", ProfileSchema.template())
	local profile = store.Mock:StartSessionAsync("smoke")
	local data = ProfileSchema.load(profile.Data)
	profile:EndSession()
	return data and data.schemaVersion
end)
check("mock profile v1 (ProfileStore)", okMock and mockVersion == 1, mockVersion)

-- T-016b: a fresh profile gets the starter loadout; a move of an unequipped Kith is refused.
local okLoadout, loadoutResult = pcall(function()
	require(game:GetService("ServerScriptService").Server.LoadoutService)
	local Loadout = require(ReplicatedStorage.Shared.Loadout)
	local Registry = require(ReplicatedStorage.Shared.Registry)
	local All = require(ReplicatedStorage.Shared.Content.All)
	local built = Registry.build(All.content(Config))
	local data: any = require(ReplicatedStorage.Shared.ProfileSchema).template()
	Loadout.prepare(data, Config, built)
	-- Starter order comes from Config.Loadout.starter (D-194: Rimeshard first), so find Crescent's slot by uid.
	local starterOk = Loadout.canCast(data.loadout, data.kith, built, "move.crescent_cut")
		and Loadout.canCast(data.loadout, data.kith, built, "move.rime.needle")
	local crescentSlot = table.find(data.loadout.slots, "starter.crescent")
	if not crescentSlot then
		return "no starter.crescent slot"
	end
	Loadout.unequip(data.loadout, crescentSlot)
	local refused = not Loadout.canCast(data.loadout, data.kith, built, "move.crescent_cut")
	local rimeStillOk = Loadout.canCast(data.loadout, data.kith, built, "move.rime.needle")
	return starterOk and refused and rimeStillOk
end)
check("loadout gates casts (starter ok, unequipped refused)", okLoadout and loadoutResult == true, loadoutResult)

local allPass = true
for _, r in results do
	print(r)
	if r:sub(1, 4) ~= "PASS" then
		allPass = false
	end
end
print(allPass and "CLOUD: PASS" or "CLOUD: FAIL")
return allPass, table.concat(results, " | ")
