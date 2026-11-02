--!strict
-- Crescent Cut art-blade rules (T-053a3, D-385). Pure timing, look choice and pool counting. No Roblox services.
-- The client (CrescentFx) builds instances; this module decides scale, fade and how many blades may live.

export type Tunables = {
	look: string, -- "Art" | "Classic"
	growFrom: number, -- start scale of the grow-in
	growTime: number, -- seconds
	dissolveTime: number, -- seconds
	dissolveWiden: number, -- extra width at the end of the dissolve (1 = none)
	rollDeg: number, -- forward roll over the blade's life
	maxLive: number, -- pooled blades per client
}
export type Pool = { live: number, free: number, max: number }

local CrescentLook = {}

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

-- "Art" only when asked for and the slash texture id exists; anything else is the code-built "Classic" look.
function CrescentLook.choose(t: Tunables, textureUrl: string?): string
	if t.look == "Art" and type(textureUrl) == "string" and textureUrl ~= "" then
		return "Art"
	end
	return "Classic"
end

-- Grow-in scale at `age` seconds: growFrom → 1 (ease-out), then 1.
function CrescentLook.scaleAt(t: Tunables, age: number): number
	if not finite(age) or age >= t.growTime or t.growTime <= 0 then
		return 1
	end
	local a = math.max(0, age) / t.growTime
	local e = 1 - (1 - a) * (1 - a)
	return t.growFrom + (1 - t.growFrom) * e
end

-- Forward roll (radians) after `traveled` of `range` studs.
function CrescentLook.rollAt(t: Tunables, traveled: number, range: number): number
	if not (finite(traveled) and finite(range)) or range <= 0 then
		return 0
	end
	return math.rad(t.rollDeg) * math.clamp(traveled / range, 0, 1)
end

-- Dissolve at `age` seconds after it began: (visibility 1 → 0, width 1 → dissolveWiden, done).
function CrescentLook.dissolveAt(t: Tunables, age: number): (number, number, boolean)
	if not finite(age) or t.dissolveTime <= 0 or age >= t.dissolveTime then
		return 0, t.dissolveWiden, true
	end
	local a = math.clamp(age / t.dissolveTime, 0, 1)
	return 1 - a, 1 + (t.dissolveWiden - 1) * a, false
end

-- Where the client blade should stop: at range, or at a world hit closer than range.
function CrescentLook.stopDistance(range: number, worldHit: number?): number
	if type(worldHit) == "number" and finite(worldHit) and worldHit >= 0 and worldHit < range then
		return worldHit
	end
	return range
end

-- Blade visibility after `hits` targets: full before the first, `dim` after (a pierce reads as a pierce).
function CrescentLook.pierceVis(hits: number, dim: number): number
	if type(hits) ~= "number" or hits ~= hits or hits <= 0 then
		return 1
	end
	return math.clamp(dim, 0, 1)
end

function CrescentLook.newPool(max: number): Pool
	return { live = 0, free = 0, max = math.max(1, math.floor(max)) }
end

-- Takes a blade: "reuse" a free one, "new" while under max, or "full" (skip this blade's art).
function CrescentLook.acquire(p: Pool): string
	if p.free > 0 then
		p.free -= 1
		p.live += 1
		return "reuse"
	end
	if p.live + p.free < p.max then
		p.live += 1
		return "new"
	end
	return "full"
end

function CrescentLook.release(p: Pool)
	if p.live > 0 then
		p.live -= 1
		p.free += 1
	end
end

return CrescentLook
