--!nocheck
-- S89: real spatial APIs + production clearance, NOT a player/physics simulation test.
local Server = game:GetService("ServerScriptService"):WaitForChild("Server", 10)
local Clearance = require(Server:WaitForChild("WindStepClearance", 10))
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local terrain = workspace.Terrain
local origin = Vector3.new(16384, 2048, 16384)
local extent = Vector3.new(96, 80, 96)
local region = Region3.new(origin - extent / 2, origin + extent / 2):ExpandToGrid(4)
-- Snapshot BEFORE any mutation. A failed snapshot must leave the world untouched.
local originalMaterials, originalOccupancy = terrain:ReadVoxels(region, 4)
local folder, root, overlap, terrainParams
local groups = {}
local results = {}
local function fill(cf, size, material)
	terrain:FillBlock(cf, size, material)
	-- Terrain collision meshing may lag the voxel edit; this is fixture setup only.
	task.wait(0.25)
end
local function record(name, ok, detail)
	table.insert(results, { name = name, ok = ok, detail = tostring(detail or "") })
end
local function reset()
	for _, item in folder:GetChildren() do
		if item ~= root then
			item:Destroy()
		end
	end
	fill(region.CFrame, region.Size, Enum.Material.Air)
	root.CFrame = CFrame.new(origin)
	root.Size = Vector3.new(2, 2, 1)
	root.CollisionGroup = "Default"
	overlap.CollisionGroup = "Default"
	terrainParams.CollisionGroup = "Default"
end
local function part(name, position, size)
	local p = Instance.new("Part")
	p.Name, p.Anchored, p.Size, p.CFrame = name, true, size, CFrame.new(position)
	p.Parent = folder
	return p
end
local function surface(x, z)
	local hit
	local deadline = os.clock() + 3
	repeat
		hit = workspace:Raycast(origin + Vector3.new(x, 25, z), Vector3.new(0, -60, 0), terrainParams)
		if not hit then
			task.wait(0.1)
		end
	until hit or os.clock() >= deadline
	assert(hit, "fixture has no queryable solid surface after bounded mesh wait")
	return hit.Position
end
local function ground(offset)
	fill(CFrame.new(origin + Vector3.new(0, -8 + offset, 0)), Vector3.new(64, 16, 64), Enum.Material.Rock)
end
local function expect(name, expected)
	local actual = Clearance.occupied(root, root.Size, overlap, terrainParams)
	record(name, actual == expected, "occupied=" .. tostring(actual) .. " expected=" .. tostring(expected))
end
local function emptyCertificate(cf)
	-- Diagnostics only; never used for the pass/fail decision or production admission.
	local half = root.Size / 2 + Vector3.new(4, 4, 4)
	local m, o = terrain:ReadVoxels(Region3.new(cf.Position - half, cf.Position + half):ExpandToGrid(4), 4)
	for x, plane in ipairs(o) do
		for y, row in ipairs(plane) do
			for z, amount in ipairs(row) do
				if amount > 0 and m[x][y][z] ~= Enum.Material.Water then
					return false
				end
			end
		end
	end
	return true
end
local function diagnostics(name)
	local descents = {}
	for _, height in { 8, 16 } do
		local cf = root.CFrame + Vector3.new(0, height, 0)
		local hit = workspace:Blockcast(cf, root.Size, Vector3.new(0, -height, 0), terrainParams)
		table.insert(
			descents,
			string.format(
				"%d:empty=%s,hit=%s",
				height,
				tostring(emptyCertificate(cf)),
				hit and tostring(hit.Distance) or "none"
			)
		)
	end
	record(name, true, "rootEmpty=" .. tostring(emptyCertificate(root.CFrame)) .. " " .. table.concat(descents, ";"))
end
record("ReadVoxels metadata", true, "occupancy.Size=" .. typeof(originalOccupancy.Size))
local ok, err = xpcall(function()
	folder = Instance.new("Folder")
	folder.Name = "WindStepSpatialProbe"
	folder.Parent = workspace
	root = part("ProbeRoot", origin, Vector3.new(2, 2, 1))
	overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { root }
	overlap.RespectCanCollide = true
	overlap.MaxParts = 1
	terrainParams = RaycastParams.new()
	terrainParams.FilterType = Enum.RaycastFilterType.Include
	terrainParams.FilterDescendantsInstances = { terrain }
	terrainParams.RespectCanCollide = true
	terrainParams.IgnoreWater = true

	reset()
	expect("empty air", false)
	for _, offset in { 0, 0.5, 1.5, 3.5 } do
		reset()
		ground(offset)
		root.CFrame = CFrame.new(surface(0, 0) + Vector3.new(0, 1.2, 0))
		expect("flat coarse ground offset " .. offset, false)
		diagnostics("flat API offset " .. offset)
		for _, depth in { 0.05, 0.2, 0.5 } do
			root.CFrame = CFrame.new(surface(0, 0) + Vector3.new(0, 1 - depth, 0))
			expect("penetration offset " .. offset .. " depth " .. depth, true)
		end
	end
	reset()
	fill(
		CFrame.new(origin - Vector3.new(0, 8, 0)) * CFrame.Angles(0, 0, math.rad(15)),
		Vector3.new(64, 16, 64),
		Enum.Material.Rock
	)
	root.CFrame = CFrame.new(surface(0, 0) + Vector3.new(0, 1.6, 0))
	expect("sloping terrain with body clearance", false)
	root.CFrame *= CFrame.Angles(0, math.rad(35), math.rad(10))
	expect("tilted root above slope", false)
	reset()
	ground(0)
	root.CFrame = CFrame.new(origin + Vector3.new(0, 12, 0))
	expect("air above terrain (no dynamics claim)", false)
	reset()
	fill(CFrame.new(origin), Vector3.new(32, 32, 32), Enum.Material.Water)
	expect("water ignored", false)
	reset()
	ground(0)
	local top = surface(0, 0)
	root.CFrame = CFrame.new(top - Vector3.new(0, 3, 0))
	expect("fully embedded terrain", true)
	root.CFrame = CFrame.new(top + Vector3.new(0, 0.8, 0))
	expect("shallow 0.2stud penetration", true)
	diagnostics("penetration API")
	reset()
	ground(1.5)
	root.CFrame = CFrame.new(surface(0, 0) + Vector3.new(0, 1.2, 0))
	fill(CFrame.new(origin + Vector3.new(0, 24, 0)), Vector3.new(64, 4, 64), Enum.Material.Rock)
	expect("high overhang clear seed", false)
	reset()
	ground(1.5)
	root.CFrame = CFrame.new(surface(0, 0) + Vector3.new(0, 1.2, 0))
	-- Low ceiling blocks both certified descent routes; conservative refusal is intended.
	fill(CFrame.new(origin + Vector3.new(0, 8, 0)), Vector3.new(64, 4, 64), Enum.Material.Rock)
	expect("low overhang no clear seed (conservative)", true)
	diagnostics("low overhang API")
	reset()
	part("EmbeddedPart", origin, Vector3.new(1, 1, 1))
	expect("initial part overlap", true)
	reset()
	local blocker = part("DecorativePart", origin, Vector3.new(2, 2, 2))
	blocker.CanCollide = false
	expect("noncollidable part ignored", false)
	reset()
	local stamp = tostring(math.floor(os.clock() * 1000000))
	local a, b = "WindProbeA" .. stamp, "WindProbeB" .. stamp
	for _, name in { a, b } do
		PhysicsService:RegisterCollisionGroup(name)
		table.insert(groups, name)
	end
	PhysicsService:CollisionGroupSetCollidable(a, b, false)
	root.CollisionGroup, overlap.CollisionGroup, terrainParams.CollisionGroup = a, a, a
	part("GroupExcluded", origin, Vector3.new(2, 2, 2)).CollisionGroup = b
	expect("collision-group part exclusion", false)
	PhysicsService:CollisionGroupSetCollidable(a, b, true)
	expect("collision-group part restored", true)
	reset()
	ground(0)
	root.CFrame = CFrame.new(surface(0, 0) - Vector3.new(0, 3, 0))
	PhysicsService:CollisionGroupSetCollidable(a, terrain.CollisionGroup, false)
	root.CollisionGroup, overlap.CollisionGroup, terrainParams.CollisionGroup = a, a, a
	expect("collision-group terrain exclusion", false)
	reset()
	local wall = part("Wall", origin + Vector3.new(5, 0, 0), Vector3.new(1, 8, 8))
	expect("near wall not initial overlap", false)
	wall.CFrame = CFrame.new(origin + Vector3.new(1.2, 0, 0))
	expect("moving blocker now overlaps", true)
	reset()
	for _ = 1, 100 do
		assert(not Clearance.occupied(root, root.Size, overlap, terrainParams), "repeat query changed")
	end
	record("100 spatial queries (not lease lifetimes)", true)
end, debug.traceback)
if not ok then
	record("probe execution", false, err)
end
-- Every cleanup is independent, including when the probe/assertions fail.
local restored, restoreError = pcall(function()
	terrain:WriteVoxels(region, 4, originalMaterials, originalOccupancy)
	local materials, occupancy = terrain:ReadVoxels(region, 4)
	for x, plane in ipairs(originalOccupancy) do
		for y, row in ipairs(plane) do
			for z, amount in ipairs(row) do
				assert(
					materials[x][y][z] == originalMaterials[x][y][z] and math.abs(occupancy[x][y][z] - amount) < 0.0001,
					"terrain restore mismatch"
				)
			end
		end
	end
end)
record("terrain restored and verified", restored, restoreError)
local destroyed, destroyError = pcall(function()
	if folder then
		folder:Destroy()
	end
end)
record("parts cleaned", destroyed, destroyError)
for _, name in groups do
	local removed, removeError = pcall(function()
		PhysicsService:UnregisterCollisionGroup(name)
	end)
	record("collision group cleaned", removed, removeError)
end
local passed, failed = 0, 0
for _, result in results do
	if result.ok then
		passed += 1
	else
		failed += 1
	end
end
return {
	kind = "WindStep spatial only",
	isRunning = RunService:IsRunning(),
	isServer = RunService:IsServer(),
	players = #game:GetService("Players"):GetPlayers(),
	passed = passed,
	failed = failed,
	results = results,
	dynamicsAccepted = false,
}
