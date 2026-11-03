--!strict
-- Player-side hit reactions (T-057c3, D-419). Pure: no Roblox services.
-- A player's own client owns their character root, so the server cannot push it directly. The server
-- writes a knock (flat velocity + server time) on the victim's character; the victim's client applies it once.
-- A hit that staggers also interrupts the victim's casts still in their wind-up (server time < releaseAt).
local PlayerHitReact = {}

export type Knock = { x: number, z: number, at: number }
export type Windup = { castId: string, casterUserId: number, releaseAt: number }

PlayerHitReact.MAX_SPEED = 60 -- studs/s clamp on any knock the client applies
PlayerHitReact.FRESH_SECONDS = 1 -- a knock older than this (server time) is ignored (late replication)

local function finite(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end

-- Server side: the knock to publish for a flat push (pushX, pushZ) at server time `now`, clamped.
function PlayerHitReact.knock(pushX: number, pushZ: number, now: number): Knock?
	if not (finite(pushX) and finite(pushZ) and finite(now)) then
		return nil
	end
	local mag = math.sqrt(pushX * pushX + pushZ * pushZ)
	if mag < 1e-6 then
		return nil
	end
	local s = math.min(1, PlayerHitReact.MAX_SPEED / mag)
	return { x = pushX * s, z = pushZ * s, at = now }
end

-- Client side: the knock to apply now, or nil (bad, stale, future-skewed or already applied at `lastAt`).
function PlayerHitReact.toApply(x: any, z: any, at: any, now: number, lastAt: number?): Knock?
	if not (finite(x) and finite(z) and finite(at)) then
		return nil
	end
	if lastAt ~= nil and at <= lastAt then
		return nil
	end
	local age = now - at
	if age > PlayerHitReact.FRESH_SECONDS or age < -PlayerHitReact.FRESH_SECONDS then
		return nil
	end
	local k = PlayerHitReact.knock(x, z, at)
	return k
end

-- Server side: castIds of `userId`'s casts still in wind-up at server time `now` (to interrupt on stagger).
function PlayerHitReact.windups(casts: { Windup }, userId: number, now: number): { string }
	local out = {}
	for _, c in casts do
		if c.casterUserId == userId and now < c.releaseAt then
			table.insert(out, c.castId)
		end
	end
	table.sort(out)
	return out
end

return PlayerHitReact
