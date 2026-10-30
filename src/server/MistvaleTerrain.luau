--!strict
-- Mistvale terrain (T-021a, D-100): writes the code-generated start valley (MistvaleLayout) with
-- Terrain:WriteVoxels at server start, before players spawn. Adds a Workspace.MistvaleAnchors folder of
-- invisible ground markers (hub, zone1, spawn) for hub assembly (T-021c).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MistvaleLayout = require(ReplicatedStorage.Shared.MistvaleLayout)

local MistvaleTerrain = {}

local CHUNK = 32 -- columns per side per WriteVoxels call

local cache: { [string]: any } = {}
local function material(name: string): any
	local m = cache[name]
	if not m then
		m = (Enum.Material :: any)[name]
		cache[name] = m
	end
	return m
end

local function anchors(layout: MistvaleLayout.Layout)
	local folder = Instance.new("Folder")
	folder.Name = "MistvaleAnchors"
	for _, a in MistvaleLayout.anchors(layout) do
		local p = Instance.new("Part")
		p.Name = a.name
		p.Size = Vector3.new(1, 1, 1)
		p.Position = Vector3.new(a.x, a.y + 0.5, a.z)
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Transparency = 1
		p.Parent = folder
	end
	folder.Parent = workspace
end

function MistvaleTerrain.start()
	local layout = MistvaleLayout.DEFAULT
	local terrain = workspace.Terrain
	local started = os.clock()
	local n = MistvaleLayout.columnCount(layout)
	for ix = 0, n - 1, CHUNK do
		for iz = 0, n - 1, CHUNK do
			local c =
				MistvaleLayout.buildChunk(layout, ix, iz, math.min(CHUNK, n - ix), math.min(CHUNK, n - iz), material)
			local region = Region3.new(Vector3.new(c.min.x, c.min.y, c.min.z), Vector3.new(c.max.x, c.max.y, c.max.z))
			terrain:WriteVoxels(region, layout.voxel, c.materials :: any, c.occupancy)
		end
	end
	anchors(layout)
	workspace:SetAttribute("MistvaleBuilt", true)
	print(string.format("[Mistvale] terrain written in %.2fs", os.clock() - started))
end

return MistvaleTerrain
