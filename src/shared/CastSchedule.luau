--!strict
-- Current live deadlines, not the future Z wind-up contract. No engine clocks.
local Zone = require("./Deliveries/Zone")
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
	elseif kind == "Zone" then
		if not Zone.validParams(p) then
			return nil
		end
		release, finish = Zone.tickAt(1, p), Zone.tickAt(p.ticks, p)
	elseif kind == "Burst" then
		release = move.telegraph or 0
		finish = release
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
return CastSchedule
