--!strict
-- Mistvale terrain layout (T-021a, D-100). Pure: a height + surface-material field for the start valley
-- (hub village floor, hunting zone 1, the dirt path between them, a river and a cliff rim that encloses the map).
-- No Roblox services. The server (MistvaleTerrain) turns chunks of it into Terrain:WriteVoxels calls.

local MistvaleLayout = {}

export type Area = { name: string, x: number, z: number, radius: number, height: number }
export type Path = { from: string, to: string, width: number }
export type Layout = {
	size: number, -- the map spans [-size/2, size/2] on x and z (studs)
	voxel: number, -- WriteVoxels resolution (studs)
	floor: number, -- bottom of the terrain (y)
	waterLevel: number,
	seed: number,
	spawn: { x: number, z: number },
	plazaRadius: number, -- cobblestone square around the hub centre
	areas: { Area }, -- flat areas: the hub first, then hunting zones
	paths: { Path },
	river: { x: number, swing: number, wave: number, width: number, depth: number, bankRise: number },
	rim: { start: number, height: number }, -- cliffs rise from `start` (fraction of half-size) to the edge
	hills: { base: number, amp: number, scale: number },
}
export type Chunk = {
	min: { x: number, y: number, z: number },
	max: { x: number, y: number, z: number },
	materials: { { { any } } },
	occupancy: { { { number } } },
}

MistvaleLayout.DEFAULT = {
	size = 1024,
	voxel = 4,
	floor = -24,
	waterLevel = -4,
	seed = 7,
	spawn = { x = 0, z = 0 },
	plazaRadius = 28,
	areas = {
		{ name = "hub", x = 0, z = 0, radius = 160, height = 0 },
		{ name = "zone1", x = 80, z = -280, radius = 120, height = 8 },
		{ name = "arena", x = -170, z = -260, radius = 50, height = 12 }, -- boss arena (T-023, D-140)
	},
	paths = { { from = "hub", to = "zone1", width = 16 }, { from = "zone1", to = "arena", width = 12 } },
	river = { x = 300, swing = 25, wave = 90, width = 22, depth = 10, bankRise = 12 },
	rim = { start = 0.8, height = 70 },
	hills = { base = 3, amp = 14, scale = 120 },
} :: Layout

local function clamp01(t: number): number
	return math.clamp(t, 0, 1)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function smoothstep(e0: number, e1: number, x: number): number
	local t = clamp01((x - e0) / (e1 - e0))
	return t * t * (3 - 2 * t)
end

local function hash(ix: number, iz: number, seed: number): number
	local s = math.sin(ix * 127.1 + iz * 311.7 + seed * 74.7) * 43758.5453
	return s - math.floor(s)
end

local function valueNoise(x: number, z: number, seed: number): number
	local ix, iz = math.floor(x), math.floor(z)
	local fx, fz = x - ix, z - iz
	local ux, uz = fx * fx * (3 - 2 * fx), fz * fz * (3 - 2 * fz)
	local a, b = hash(ix, iz, seed), hash(ix + 1, iz, seed)
	local c, d = hash(ix, iz + 1, seed), hash(ix + 1, iz + 1, seed)
	return lerp(lerp(a, b, ux), lerp(c, d, ux), uz)
end

local function fbm(x: number, z: number, seed: number): number
	return (valueNoise(x, z, seed) * 2 + valueNoise(x * 2.3, z * 2.3, seed + 1)) / 3
end

local function area(layout: Layout, name: string): Area
	for _, a in layout.areas do
		if a.name == name then
			return a
		end
	end
	error(`MistvaleLayout: unknown area {name}`)
end

-- Distance from (x, z) to the path centre line, and the path's height there. The height is flat inside both
-- areas and ramps smoothly across the gap, so the path never forms a ridge inside the hub or zone.
local function pathSample(layout: Layout, path: Path, x: number, z: number): (number, number)
	local a, b = area(layout, path.from), area(layout, path.to)
	local dx, dz = b.x - a.x, b.z - a.z
	local len = math.sqrt(dx * dx + dz * dz)
	local s = clamp01(((x - a.x) * dx + (z - a.z) * dz) / (len * len))
	local px, pz = a.x + dx * s, a.z + dz * s
	local dist = math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
	local sA, sB = a.radius * 0.75 / len, 1 - b.radius * 0.75 / len
	return dist, lerp(a.height, b.height, smoothstep(sA, sB, s))
end

local function riverDist(layout: Layout, x: number, z: number): number
	local r = layout.river
	return math.abs(x - (r.x + r.swing * math.sin(z / r.wave)))
end

function MistvaleLayout.heightAt(layout: Layout, x: number, z: number): number
	local hills = layout.hills
	local h = hills.base + hills.amp * fbm(x / hills.scale, z / hills.scale, layout.seed)
	local edge = math.max(math.abs(x), math.abs(z)) / (layout.size / 2)
	if edge > layout.rim.start then
		local t = (edge - layout.rim.start) / (1 - layout.rim.start)
		h += layout.rim.height * t * t
	end
	for _, a in layout.areas do
		local d = math.sqrt((x - a.x) ^ 2 + (z - a.z) ^ 2)
		h = lerp(h, a.height, 1 - smoothstep(a.radius * 0.75, a.radius * 1.25, d))
	end
	for _, path in layout.paths do
		local dist, ph = pathSample(layout, path, x, z)
		h = lerp(h, ph, 1 - smoothstep(path.width * 0.5, path.width * 1.5, dist))
	end
	local r = layout.river
	local dr = riverDist(layout, x, z)
	if dr < r.width then
		h = math.min(h, layout.waterLevel - r.depth * (1 - (dr / r.width) ^ 2))
	elseif dr < r.width * 2 then
		h = math.min(h, layout.waterLevel + (dr - r.width) / r.width * r.bankRise)
	end
	return h
end

-- "hub" / "zone1" / … when inside an area's radius, "path" on a path core, else "wild".
function MistvaleLayout.zoneAt(layout: Layout, x: number, z: number): string
	for _, a in layout.areas do
		if (x - a.x) ^ 2 + (z - a.z) ^ 2 < a.radius ^ 2 then
			return a.name
		end
	end
	for _, path in layout.paths do
		if (pathSample(layout, path, x, z)) < path.width * 0.5 then
			return "path"
		end
	end
	return "wild"
end

-- Surface material name (an Enum.Material name) for the column at (x, z).
function MistvaleLayout.surfaceAt(layout: Layout, x: number, z: number, height: number?): string
	local h = height or MistvaleLayout.heightAt(layout, x, z)
	if riverDist(layout, x, z) < layout.river.width * 1.3 then
		return "Sand"
	end
	local hub = layout.areas[1]
	if (x - hub.x) ^ 2 + (z - hub.z) ^ 2 < layout.plazaRadius ^ 2 then
		return "Cobblestone"
	end
	for _, path in layout.paths do
		if (pathSample(layout, path, x, z)) < path.width * 0.5 then
			return "Ground"
		end
	end
	if h > 26 then
		return "Rock"
	end
	local zone = MistvaleLayout.zoneAt(layout, x, z)
	if zone ~= "hub" and zone ~= "wild" then
		return "LeafyGrass"
	end
	return "Grass"
end

function MistvaleLayout.columnCount(layout: Layout): number
	return layout.size // layout.voxel
end

-- Voxel arrays ([x][y][z]) for nx × nz columns starting at column (ix0, iz0). `material` maps a name to the
-- value WriteVoxels wants (Enum.Material on the server, the name itself in tests).
function MistvaleLayout.buildChunk(
	layout: Layout,
	ix0: number,
	iz0: number,
	nx: number,
	nz: number,
	material: (string) -> any
): Chunk
	local v, half = layout.voxel, layout.size / 2
	local heights, surfaces = {}, {}
	local top = layout.waterLevel
	for i = 1, nx do
		heights[i], surfaces[i] = {}, {}
		for k = 1, nz do
			local x = -half + (ix0 + i - 0.5) * v
			local z = -half + (iz0 + k - 0.5) * v
			local h = MistvaleLayout.heightAt(layout, x, z)
			heights[i][k] = h
			surfaces[i][k] = material(MistvaleLayout.surfaceAt(layout, x, z, h))
			top = math.max(top, h)
		end
	end
	local ny = math.max(1, math.ceil((top - layout.floor) / v))
	local rock, water, air = material("Rock"), material("Water"), material("Air")
	local materials: { { { any } } }, occupancy: { { { number } } } = {}, {}
	for i = 1, nx do
		materials[i], occupancy[i] = {}, {}
		for j = 1, ny do
			local y0 = layout.floor + (j - 1) * v
			local mRow, oRow = {}, {}
			for k = 1, nz do
				local h = heights[i][k]
				local fill = clamp01((h - y0) / v)
				if fill > 0 then
					mRow[k] = if h - y0 > v * 2 then rock else surfaces[i][k]
					oRow[k] = fill
				elseif y0 + v / 2 < layout.waterLevel then
					mRow[k], oRow[k] = water, 1
				else
					mRow[k], oRow[k] = air, 0
				end
			end
			materials[i][j], occupancy[i][j] = mRow, oRow
		end
	end
	local min = { x = -half + ix0 * v, y = layout.floor, z = -half + iz0 * v }
	return {
		min = min,
		max = { x = min.x + nx * v, y = min.y + ny * v, z = min.z + nz * v },
		materials = materials,
		occupancy = occupancy,
	}
end

-- Rough voxel count (solid + water) sampled every `step` columns; compare with the terrain budget.
function MistvaleLayout.voxelEstimate(layout: Layout, step: number): number
	local n, v, half = MistvaleLayout.columnCount(layout), layout.voxel, layout.size / 2
	local total = 0
	for i = 0, n - 1, step do
		for k = 0, n - 1, step do
			local h = MistvaleLayout.heightAt(layout, -half + (i + 0.5) * v, -half + (k + 0.5) * v)
			total += math.ceil((math.max(h, layout.waterLevel) - layout.floor) / v) * step * step
		end
	end
	return total
end

-- Named ground points for later placement work (T-021c): area centres and the spawn.
function MistvaleLayout.anchors(layout: Layout): { { name: string, x: number, y: number, z: number } }
	local out = {}
	for _, a in layout.areas do
		table.insert(out, { name = a.name, x = a.x, y = MistvaleLayout.heightAt(layout, a.x, a.z), z = a.z })
	end
	local s = layout.spawn
	table.insert(out, { name = "spawn", x = s.x, y = MistvaleLayout.heightAt(layout, s.x, s.z), z = s.z })
	return out
end

return MistvaleLayout
