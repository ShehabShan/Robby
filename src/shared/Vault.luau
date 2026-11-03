--!strict
-- Vault / ledge climb (T-058f, D-432): pure rules. The client casts forward rays at knee and head height and
-- one ray down onto the obstacle top (double-ray ledge test, R-029); this module classifies the result and
-- gives the launch velocity. Numbers live in `Config.Vault`. No game services here.
local Vault = {}

export type Cfg = {
	reach: number, -- max forward distance to the obstacle face (studs)
	vaultMin: number, -- obstacle top above the feet: vault from here...
	vaultMax: number, -- ...up to here
	climbMax: number, -- above vaultMax up to here is a ledge climb
	clearance: number, -- extra height cleared above the top (studs)
	vaultForward: number, -- min forward speed over a vault (studs/s)
	climbForward: number, -- forward speed after pulling up a ledge
	gravity: number, -- workspace gravity (studs/s²)
	cooldown: number, -- seconds between vaults/climbs
}

export type Probe = {
	faceDist: number?, -- forward hit at knee height (nil = nothing ahead)
	headBlocked: boolean, -- forward hit at the probe's top height (wall too tall / ceiling)
	topHeight: number?, -- obstacle top above the feet, from the downward ray (nil = no top found)
	roomAbove: boolean, -- standing room on top / above the arc
}

export type Kind = "vault" | "climb"

-- What to do with this probe, or nil for a normal jump.
function Vault.classify(c: Cfg, p: Probe): Kind?
	local d, h = p.faceDist, p.topHeight
	if d == nil or h == nil or d > c.reach or d < 0 or h ~= h then
		return nil
	end
	if p.headBlocked or not p.roomAbove then
		return nil
	end
	if h >= c.vaultMin and h <= c.vaultMax then
		return "vault"
	end
	if h > c.vaultMax and h <= c.climbMax then
		return "climb"
	end
	return nil
end

-- Upward speed needed to rise `height` + clearance under gravity.
function Vault.riseSpeed(c: Cfg, height: number): number
	return math.sqrt(2 * c.gravity * math.max(height + c.clearance, 0))
end

-- Launch: (upward speed, forward speed). Vaults keep run speed; climbs pull up slower.
function Vault.launch(c: Cfg, kind: Kind, height: number, speed: number): (number, number)
	local up = Vault.riseSpeed(c, height)
	if kind == "vault" then
		return up, math.max(speed, c.vaultForward)
	end
	return up, c.climbForward
end

return Vault
