--!strict
-- Immutable presentation bounds captured from the authorized (possibly woven) move.
-- No damage authority, base-content lookup, world pose, or clock ownership.
local CastGeometry = {}
export type Snapshot = {
	kind: string,
	centreMode: string,
	radius: number,
	range: number,
	speed: number,
	count: number,
	spreadDeg: number,
	hitboxX: number,
	hitboxY: number,
	hitboxZ: number,
}
local FIELDS = table.freeze({
	"kind",
	"centreMode",
	"radius",
	"range",
	"speed",
	"count",
	"spreadDeg",
	"hitboxX",
	"hitboxY",
	"hitboxZ",
})
local function nonnegative(n: any): boolean
	return type(n) == "number" and n == n and n >= 0 and n < math.huge
end
function CastGeometry.valid(g: any): boolean
	if type(g) ~= "table" then
		return false
	end
	for _, name in { "radius", "range", "speed", "count", "spreadDeg", "hitboxX", "hitboxY", "hitboxZ" } do
		if not nonnegative(g[name]) then
			return false
		end
	end
	local shot = g.kind == "Projectile" or g.kind == "Volley"
	if shot then
		return g.centreMode == "Trajectory"
			and g.radius == 0
			and g.range > 0
			and g.speed > 0
			and g.hitboxX > 0
			and g.hitboxY > 0
			and g.hitboxZ > 0
			and g.count >= 1
			and g.count <= 16
			and g.count % 1 == 0
			and g.spreadDeg < 180
			and (g.kind == "Volley" or (g.count == 1 and g.spreadDeg == 0))
	end
	if g.speed ~= 0 or g.count ~= 0 or g.spreadDeg ~= 0 or g.hitboxX ~= 0 or g.hitboxY ~= 0 or g.hitboxZ ~= 0 then
		return false
	end
	if g.kind == "Zone" then
		return g.centreMode == "Fixed" and g.radius > 0 and g.range > 0
	elseif g.kind == "Burst" then
		return g.centreMode == "CasterAtRelease" and g.radius > 0 and g.range == 0
	end
	return g.kind == "Self" and g.centreMode == "None" and g.radius == 0 and g.range == 0
end
function CastGeometry.copy(g: Snapshot): Snapshot
	local out: any = {}
	for _, name in FIELDS do
		out[name] = (g :: any)[name]
	end
	return table.freeze(out)
end
function CastGeometry.same(a: Snapshot?, b: Snapshot?): boolean
	if not a or not b then
		return a == b
	end
	for _, name in FIELDS do
		if (a :: any)[name] ~= (b :: any)[name] then
			return false
		end
	end
	return true
end
function CastGeometry.capture(move: any, defaultHitbox: any): Snapshot?
	local d = if type(move) == "table" then move.delivery else nil
	if type(d) ~= "table" or type(d.params) ~= "table" then
		return nil
	end
	local p = d.params
	local g: any = {
		kind = d.kind,
		centreMode = "None",
		radius = 0,
		range = 0,
		speed = 0,
		count = 0,
		spreadDeg = 0,
		hitboxX = 0,
		hitboxY = 0,
		hitboxZ = 0,
	}
	if d.kind == "Projectile" or d.kind == "Volley" then
		local hb = p.hitbox or defaultHitbox
		if type(hb) ~= "table" then
			return nil
		end
		g.centreMode, g.range, g.speed = "Trajectory", p.range, p.speed
		g.count = if d.kind == "Volley" then p.count else 1
		g.spreadDeg = if d.kind == "Volley" then p.spreadDeg else 0
		g.hitboxX, g.hitboxY, g.hitboxZ = hb.x, hb.y, hb.z
	elseif d.kind == "Zone" then
		g.centreMode, g.radius, g.range = "Fixed", p.radius, p.range
	elseif d.kind == "Burst" then
		g.centreMode, g.radius = "CasterAtRelease", p.radius
	end
	return if CastGeometry.valid(g) then CastGeometry.copy(g) else nil
end
return CastGeometry
