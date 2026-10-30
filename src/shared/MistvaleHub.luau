--!strict
-- Mistvale hub plan (T-021c, D-147). Pure: where each T-021b kit piece stands in the hub (village around the
-- spawn plaza, gate on the path to zone 1, Binding grove marker), simple code proxies per piece (used until the
-- meshes are uploaded via Open Cloud) and `validate` (flat ground, off the path, spawn clear, no overlaps).
-- Roblox axes: Y up; a piece's front is local -Z; origin at its base centre. No Roblox services.

local MistvaleLayout = require("./MistvaleLayout")

local MistvaleHub = {}

export type Piece = { w: number, d: number, h: number, r: number?, onPath: boolean?, solid: boolean? }
export type Proxy = { shape: string, size: { number }, offset: { number }, color: string }
export type Placement = { piece: string, x: number, y: number, z: number, yaw: number, tag: string? }

MistvaleHub.PALETTE = {
	stone = "#8C7B68",
	mist = "#C9CED6",
	pine = "#3E5B4A",
	moss = "#5E7A52",
	wood = "#6B4A32",
	darkwood = "#3A2A20",
	bark = "#4A3A2C",
	roof = "#2F3A44",
	plaster = "#EDE3CF",
	ink = "#141A24",
	bronze = "#7A6A3A",
	glow = "#F2D59A",
} :: { [string]: string }

-- Footprints from build/art/hub_kit/manifest.json (w = local X, d = local Z, h = height). r = overlap radius
-- (default: half the footprint diagonal; trees use their trunk). solid = false skips the overlap check.
MistvaleHub.PIECES = {
	HubHouseSmall = { w = 17.5, d = 14.1, h = 14.8 },
	HubHouseTall = { w = 21.5, d = 16.1, h = 22.3 },
	HubGate = { w = 17.3, d = 4.1, h = 15.7, onPath = true },
	RestSpot = { w = 12, d = 12, h = 3.7 },
	CrucibleShrine = { w = 16, d = 17.2, h = 16.4 },
	FenceSegment = { w = 8.8, d = 0.8, h = 4.5 },
	FencePost = { w = 0.8, d = 0.8, h = 4.5 },
	StoneLantern = { w = 1.9, d = 1.9, h = 5 },
	PineA = { w = 6.8, d = 6.8, h = 14.3, r = 1.5 },
	PineB = { w = 8.2, d = 8.2, h = 18.4, r = 1.5 },
	PineC = { w = 5.3, d = 5.3, h = 11.2, r = 1.5 },
	RockA = { w = 4.9, d = 3.7, h = 2.8 },
	RockB = { w = 8.7, d = 5.7, h = 4.5 },
	RockC = { w = 2.9, d = 2.6, h = 2 },
	BindingGrove = { w = 24, d = 24, h = 1, solid = false },
} :: { [string]: Piece }

local SPAWN_CLEAR = 8 -- studs kept free around the spawn pad

local function b(
	color: string,
	sx: number,
	sy: number,
	sz: number,
	ox: number,
	oy: number,
	oz: number,
	shape: string?
): Proxy
	return { shape = shape or "Block", size = { sx, sy, sz }, offset = { ox, oy, oz }, color = color }
end

local function pine(w: number, h: number): { Proxy }
	local out = { b("bark", 0.9, h * 0.4, 0.9, 0, h * 0.2, 0) }
	for i = 0, 2 do
		local s = w * (0.9 - 0.25 * i)
		table.insert(out, b("pine", s, h * 0.25, s, 0, h * (0.525 + 0.2 * i), 0))
	end
	return out
end

local function rock(w: number, h: number, d: number): { Proxy }
	return { b("stone", w, h * 0.8, d, 0, h * 0.4, 0), b("moss", w * 0.7, 0.3, d * 0.7, 0, h * 0.85, 0) }
end

local fencePost = b("wood", 0.6, 4, 0.6, 0, 2, 0)

local PROXIES: { [string]: { Proxy } } = {
	HubHouseSmall = {
		b("stone", 16, 1, 12, 0, 0.5, 0),
		b("plaster", 14, 8, 10, 0, 5, 0),
		b("ink", 3, 5, 0.3, 0, 3.6, -5.1),
		b("roof", 17.5, 1, 14, 0, 9.5, 0),
		b("roof", 12, 4, 8, 0, 12, 0),
	},
	HubHouseTall = {
		b("stone", 20, 1.2, 14, 0, 0.6, 0),
		b("plaster", 18, 8, 12, 0, 5.2, 0),
		b("ink", 3.6, 5.4, 0.3, 0, 3.9, -6.1),
		b("roof", 21.5, 1, 16, 0, 9.7, 0),
		b("plaster", 13, 6, 8, 0, 13.2, 0),
		b("roof", 16.5, 1, 11.5, 0, 16.7, 0),
		b("roof", 11, 4, 6, 0, 19.2, 0),
	},
	HubGate = {
		b("darkwood", 16.4, 1, 1.1, 0, 12.6, 0),
		b("darkwood", 1.2, 12, 1.2, -6, 7.2, 0),
		b("darkwood", 1.2, 12, 1.2, 6, 7.2, 0),
		b("darkwood", 15, 0.9, 0.9, 0, 10.4, 0),
		b("roof", 17.3, 1.4, 4, 0, 13.8, 0),
	},
	RestSpot = {
		b("stone", 12, 0.6, 12, 0, 0.3, 0),
		b("mist", 9.2, 0.5, 9.2, 0, 0.85, 0),
		b("stone", 1.6, 1.6, 1.6, 0, 1.9, 0),
		b("glow", 1.4, 1.4, 1.4, 0, 3, 0, "Ball"),
		b("glow", 0.7, 0.6, 0.7, 3.7, 2.9, 3.7),
		b("glow", 0.7, 0.6, 0.7, -3.7, 2.9, 3.7),
		b("glow", 0.7, 0.6, 0.7, 3.7, 2.9, -3.7),
		b("glow", 0.7, 0.6, 0.7, -3.7, 2.9, -3.7),
	},
	CrucibleShrine = {
		b("stone", 16, 0.8, 16, 0, 0.4, 0),
		b("stone", 13, 0.6, 13, 0, 1.1, 0),
		b("darkwood", 0.9, 8, 0.9, 4.5, 5.8, 4.5),
		b("darkwood", 0.9, 8, 0.9, -4.5, 5.8, 4.5),
		b("darkwood", 0.9, 8, 0.9, 4.5, 5.8, -4.5),
		b("darkwood", 0.9, 8, 0.9, -4.5, 5.8, -4.5),
		b("roof", 16, 1.2, 16, 0, 10.8, 0),
		b("roof", 10, 3.4, 10, 0, 13.1, 0),
		b("stone", 4, 1.2, 4, 0, 2.4, 0),
		b("bronze", 3, 3, 3, 0, 4.4, 0, "Ball"),
		b("glow", 2.2, 0.1, 2.2, 0, 5.4, 0),
	},
	FenceSegment = {
		b("wood", 0.6, 4, 0.6, -4, 2, 0),
		b("wood", 0.6, 4, 0.6, 4, 2, 0),
		b("wood", 8, 0.4, 0.3, 0, 1.4, 0),
		b("wood", 8, 0.4, 0.3, 0, 3.2, 0),
	},
	FencePost = { fencePost },
	StoneLantern = {
		b("stone", 1.6, 0.5, 1.6, 0, 0.25, 0),
		b("stone", 0.7, 2.2, 0.7, 0, 1.6, 0),
		b("glow", 0.8, 0.9, 0.8, 0, 3.45, 0),
		b("stone", 1.9, 0.7, 1.9, 0, 4.25, 0),
	},
	PineA = pine(6.8, 14.3),
	PineB = pine(8.2, 18.4),
	PineC = pine(5.3, 11.2),
	RockA = rock(4.9, 2.8, 3.7),
	RockB = rock(8.7, 4.5, 5.7),
	RockC = rock(2.9, 2, 2.6),
	BindingGrove = { b("moss", 24, 1, 24, 0, 0.5, 0, "Marker") },
}

function MistvaleHub.proxies(piece: string): { Proxy }
	return PROXIES[piece] or {}
end

local function area(layout: MistvaleLayout.Layout, name: string): MistvaleLayout.Area
	for _, a in layout.areas do
		if a.name == name then
			return a
		end
	end
	error(`MistvaleHub: unknown area {name}`)
end

-- Distance from (x, z) to the edge of the nearest path core (negative = on the path).
function MistvaleHub.pathDist(layout: MistvaleLayout.Layout, x: number, z: number): number
	local best = math.huge
	for _, path in layout.paths do
		local a, c = area(layout, path.from), area(layout, path.to)
		local dx, dz = c.x - a.x, c.z - a.z
		local s = math.clamp(((x - a.x) * dx + (z - a.z) * dz) / (dx * dx + dz * dz), 0, 1)
		local d = math.sqrt((x - a.x - dx * s) ^ 2 + (z - a.z - dz * s) ^ 2) - path.width / 2
		best = math.min(best, d)
	end
	return best
end

local function radius(def: Piece): number
	return def.r or math.sqrt(def.w * def.w + def.d * def.d) / 2
end

function MistvaleHub.placements(layout: MistvaleLayout.Layout): { Placement }
	local hub, zone = area(layout, layout.paths[1].from), area(layout, layout.paths[1].to)
	local dx, dz = zone.x - hub.x, zone.z - hub.z
	local len = math.sqrt(dx * dx + dz * dz)
	dx, dz = dx / len, dz / len
	local px, pz = -dz, dx -- across the path
	local pathYaw = math.atan2(-pz, px) -- local X across the path, front towards zone 1
	local out: { Placement } = {}
	local function put(piece: string, x: number, z: number, yaw: number?, tag: string?)
		x, z = hub.x + x, hub.z + z
		local face = yaw or math.atan2(x - hub.x, z - hub.z) -- default: front faces the plaza
		table.insert(
			out,
			{ piece = piece, x = x, y = MistvaleLayout.heightAt(layout, x, z), z = z, yaw = face, tag = tag }
		)
	end
	put("RestSpot", -20, 12, nil, "RestSpot")
	put("CrucibleShrine", 22, 18)
	for i, deg in { 90, 150, -150, -110, -30, 30 } do
		local a = math.rad(deg)
		put(if i % 2 == 1 then "HubHouseSmall" else "HubHouseTall", 62 * math.cos(a), 62 * math.sin(a))
	end
	put("HubGate", dx * 100, dz * 100, pathYaw)
	for _, off in { -22.6, -13.6, 13.6, 22.6 } do
		put("FenceSegment", dx * 100 + px * off, dz * 100 + pz * off, pathYaw)
	end
	for _, r in { 40, 70 } do
		for _, side in { -12, 12 } do
			put("StoneLantern", dx * r + px * side, dz * r + pz * side, pathYaw)
		end
	end
	local gx, gz = -94, 34
	put("BindingGrove", gx, gz, 0, "BindingGrove")
	put("RockB", -100, 50)
	put("RockA", -82, 22)
	put("RockC", -104, 20)
	local pathDeg = math.deg(math.atan2(dz, dx))
	local n = 0
	for deg = -180, 160, 20 do
		local delta = math.abs((deg - pathDeg + 180) % 360 - 180)
		local x, z = 112 * math.cos(math.rad(deg)), 112 * math.sin(math.rad(deg))
		if delta >= 15 and math.sqrt((x - gx) ^ 2 + (z - gz) ^ 2) >= 25 then
			n += 1
			put(({ "PineA", "PineB", "PineC" })[n % 3 + 1], x, z)
		end
	end
	return out
end

-- Problems with a plan (empty = OK): unknown piece, uneven ground, on the path, blocking spawn, overlaps.
function MistvaleHub.validate(layout: MistvaleLayout.Layout, plan: { Placement }): { string }
	local problems = {}
	local spawn = layout.spawn
	for i, p in plan do
		local def = MistvaleHub.PIECES[p.piece]
		if not def then
			table.insert(problems, `#{i} unknown piece {p.piece}`)
			continue
		end
		local r = radius(def)
		local c, s = math.cos(p.yaw), math.sin(p.yaw)
		for _, k in { { 0, 0 }, { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } } do
			local lx, lz = k[1] * def.w / 2, k[2] * def.d / 2
			local h = MistvaleLayout.heightAt(layout, p.x + lx * c + lz * s, p.z - lx * s + lz * c)
			if math.abs(h - p.y) > 0.5 then
				table.insert(problems, `#{i} {p.piece} not on flat ground`)
				break
			end
		end
		if not def.onPath and MistvaleHub.pathDist(layout, p.x, p.z) < r then
			table.insert(problems, `#{i} {p.piece} on the path`)
		end
		if math.sqrt((p.x - spawn.x) ^ 2 + (p.z - spawn.z) ^ 2) < r + SPAWN_CLEAR then
			table.insert(problems, `#{i} {p.piece} blocks spawn`)
		end
		for j = i + 1, #plan do
			local q = plan[j]
			local other = MistvaleHub.PIECES[q.piece]
			if other and def.solid ~= false and other.solid ~= false then
				if math.sqrt((p.x - q.x) ^ 2 + (p.z - q.z) ^ 2) < r + radius(other) then
					table.insert(problems, `#{i} {p.piece} overlaps #{j} {q.piece}`)
				end
			end
		end
	end
	return problems
end

return MistvaleHub
