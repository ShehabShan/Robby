--!strict
-- Sprint speed guard (T-026b3b, D-166). Pure server-side check of a player's planar (XZ) speed between
-- position samples. The normal limit is sprint speed; Wind Step opens a short burst window with a
-- higher limit. `tolerance` (×) and `slack` (studs per sample) absorb replication jitter. `strikes`
-- violations in a row ask the caller to correct (move back to the last good position); fewer are flagged.
local SpeedGuard = {}

export type Cfg = {
	sprint: number,
	burstSpeed: number,
	burstSeconds: number,
	tolerance: number,
	slack: number,
	strikes: number,
}

export type State = {
	x: number?,
	z: number?,
	at: number,
	goodX: number?,
	goodZ: number?,
	burstUntil: number,
	strikes: number,
}

export type Verdict = "ok" | "flag" | "correct"

function SpeedGuard.new(): State
	return { x = nil, z = nil, at = 0, goodX = nil, goodZ = nil, burstUntil = -math.huge, strikes = 0 }
end

-- Forget samples (respawn, server teleport): the next sample starts fresh.
function SpeedGuard.reset(state: State)
	state.x, state.z, state.goodX, state.goodZ, state.strikes = nil, nil, nil, nil, 0
end

-- Wind Step accepted at `now`: allow burst speed for `burstSeconds`.
function SpeedGuard.burst(cfg: Cfg, state: State, now: number)
	state.burstUntil = math.max(state.burstUntil, now + cfg.burstSeconds)
end

-- Max planar distance (studs) allowed between a sample at `from` and one at `now`.
function SpeedGuard.allowed(cfg: Cfg, state: State, from: number, now: number): number
	local dt = math.max(now - from, 0)
	local burstTime = math.clamp(state.burstUntil - from, 0, dt)
	local dist = burstTime * math.max(cfg.burstSpeed, cfg.sprint) + (dt - burstTime) * cfg.sprint
	return dist * cfg.tolerance + cfg.slack
end

-- New sample at (x, z). Returns the verdict and, for "correct", the last good position.
function SpeedGuard.check(cfg: Cfg, state: State, x: number, z: number, now: number): (Verdict, number?, number?)
	local px, pz = state.x, state.z
	if px == nil or pz == nil then
		state.x, state.z, state.at = x, z, now
		state.goodX, state.goodZ = x, z
		return "ok", nil, nil
	end
	if now <= state.at then
		return "ok", nil, nil
	end
	local dx, dz = x - px, z - pz
	local dist = math.sqrt(dx * dx + dz * dz)
	local limit = SpeedGuard.allowed(cfg, state, state.at, now)
	state.x, state.z, state.at = x, z, now
	if dist <= limit then
		state.strikes = 0
		state.goodX, state.goodZ = x, z
		return "ok", nil, nil
	end
	state.strikes += 1
	if state.strikes >= cfg.strikes then
		state.strikes = 0
		local gx, gz = state.goodX, state.goodZ
		state.x, state.z = gx, gz -- the next sample is measured from where we put the player back
		return "correct", gx, gz
	end
	return "flag", nil, nil
end

return SpeedGuard
