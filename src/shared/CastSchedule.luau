--!strict
-- Current live deadlines, not the future Z wind-up contract. No engine clocks.
local Zone = require("./Deliveries/Zone")
local GuardRing = require("./Deliveries/GuardRing")
local CastSchedule = {}
export type Offsets = { release: number, finish: number }
local function finite(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge and n >= 0
end
function CastSchedule.offsets(move: any, effects: any, maxLifetime: number): Offsets?
	local p, kind = move.delivery.params, move.delivery.kind
	local release, finish = 0, 0
	if kind == "Projectile" or kind == "Volley" then
		if not finite(p.range) or not finite(p.speed) or p.speed == 0 then
			return nil
		end
		finish = p.range / p.speed -- Volley currently releases immediately, including Z.
		local third = p.third
		if kind == "Volley" and type(third) == "table" and finite(p.crossAt) and finite(third.rangeMult) then
			-- Twin Crescent 3rd blade (T-056b, D-405): starts at the cross, flies range × rangeMult
			finish = math.max(finish, (p.crossAt + p.range * third.rangeMult) / p.speed)
		end
	elseif kind == "Zone" then
		if not Zone.validParams(p) then
			return nil
		end
		release, finish = Zone.tickAt(1, p), Zone.tickAt(p.ticks, p)
	elseif kind == "Burst" then
		release = move.telegraph or 0
		finish = release
	elseif kind == "Guard" then
		if not GuardRing.validParams(p) then
			return nil
		end
		finish = p.duration -- open at once; lasts until shattered or `duration` (T-057c2, D-415)
	elseif kind == "Self" then
		for _, id in move.effects.onSelf or {} do
			local effect = effects[id]
			local seconds = if effect then effect.seconds or 0 else 0
			if not finite(seconds) then
				return nil
			end
			finish = math.max(finish, seconds)
		end
	else
		return nil
	end
	if not finite(release) or not finite(finish) or finish < release or finish > maxLifetime then
		return nil
	end
	return { release = release, finish = finish }
end
-- Lifetime resources of a cast: one per projectile; a Scissor volley with a 3rd blade owns one more (T-056b).
function CastSchedule.resources(move: any): number
	local d = move.delivery
	if d.kind ~= "Volley" then
		return 1
	end
	return d.params.count + (if type(d.params.third) == "table" then 1 else 0)
end
return CastSchedule
