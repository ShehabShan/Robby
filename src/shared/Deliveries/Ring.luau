--!strict
-- Ring path (T-053c, D-407): Full Moon Ring's blades as a `Volley` with `curve = "Ring"`. `count` blades sit evenly
-- round the caster (blade 1 on the aim), start `radius` studs out and fly straight outward to `range`.
-- Pure: blade index + distance travelled → position. No Roblox services.

local Ring = {}

export type Params = { curve: string?, count: number, radius: number, range: number }

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

function Ring.isRing(p: any): boolean
	return type(p) == "table" and p.curve == "Ring"
end

-- 2..16 blades, a non-negative start radius, a positive range.
function Ring.validParams(p: any): boolean
	return Ring.isRing(p)
		and finite(p.count)
		and p.count >= 2
		and p.count <= 16
		and p.count % 1 == 0
		and finite(p.radius)
		and p.radius >= 0
		and finite(p.range)
		and p.range > 0
end

-- Outward unit directions (flat), blade 1 along the aim, then evenly every 360/count degrees.
function Ring.directions(aimX: number, aimZ: number, p: Params): { { x: number, z: number } }
	local m = math.sqrt(aimX * aimX + aimZ * aimZ)
	local base = if m > 1e-6 then math.atan2(aimZ, aimX) else 0
	local out = {}
	for i = 1, p.count do
		local a = base + (i - 1) * 2 * math.pi / p.count
		table.insert(out, { x = math.cos(a), z = math.sin(a) })
	end
	return out
end

-- Blade at distance `d` along its outward direction (dx, dz) from centre (ox, oz).
function Ring.point(d: number, p: Params, ox: number, oz: number, dx: number, dz: number): (number, number)
	local r = p.radius + d
	return ox + dx * r, oz + dz * r
end

return Ring
