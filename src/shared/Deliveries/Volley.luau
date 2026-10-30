--!strict
-- Volley delivery (T-027b, D-175): n projectiles in a horizontal fan, each a `Projectile`, with a per-target hit cap
-- across the whole volley (Shard Fan: 5 shards, a target takes at most 2). Pure: reads only Move params.

local Projectile = require("./Projectile")

local Volley = {}

export type Params = {
	count: number,
	spreadDeg: number,
	perTargetCap: number,
	speed: number,
	range: number,
	maxHits: number,
}
export type State = { shards: { Projectile.State }, perTarget: { [string]: number } }

function Volley.validParams(p: any): boolean
	return Projectile.validParams(p)
		and type(p.count) == "number"
		and p.count >= 1
		and p.count <= 16
		and type(p.spreadDeg) == "number"
		and p.spreadDeg >= 0
		and p.spreadDeg < 180
		and type(p.perTargetCap) == "number"
		and p.perTargetCap >= 1
end

-- Flattened unit directions for each shard, evenly spaced across the spread and centred on the aim.
function Volley.directions(aimX: number, aimZ: number, params: Params): { { x: number, z: number } }
	local fx, fz, ok = Projectile.flatten(aimX, aimZ)
	if not ok then
		return {}
	end
	local out = {}
	local n = params.count
	local base = math.atan2(fz, fx)
	local spread = math.rad(params.spreadDeg)
	for i = 1, n do
		local t = if n == 1 then 0 else (i - 1) / (n - 1) - 0.5
		local a = base + t * spread
		table.insert(out, { x = math.cos(a), z = math.sin(a) })
	end
	return out
end

function Volley.new(params: Params): State
	local shards = {}
	for _ = 1, params.count do
		table.insert(shards, Projectile.new())
	end
	return { shards = shards, perTarget = {} }
end

-- Advances every live shard. Returns the number of shards still travelling.
function Volley.step(s: State, dt: number, params: Params): number
	local live = 0
	for _, shard in s.shards do
		Projectile.step(shard, dt, params)
		if not shard.done then
			live += 1
		end
	end
	return live
end

-- Shard `index` hits targetId: honours the shard's own hit rules and the volley-wide per-target cap.
function Volley.registerHit(s: State, index: number, targetId: string, params: Params): boolean
	local shard = s.shards[index]
	if shard == nil or (s.perTarget[targetId] or 0) >= params.perTargetCap then
		return false
	end
	if not Projectile.registerHit(shard, targetId, params) then
		return false
	end
	s.perTarget[targetId] = (s.perTarget[targetId] or 0) + 1
	return true
end

return Volley
