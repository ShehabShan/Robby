--!strict
-- Crucible focus mini-game core (T-019b, D-082): a needle ping-pongs across a 0..1 bar; each of `rounds` rounds has
-- a zone. One press per round: in zone = 1, near miss = partial (falls to 0 over `nearMiss`), no press within
-- `roundSeconds` = 0. Focus = the average, fed to `Crucible.odds`. Pure; the server owns zones and the clock.

export type Focus = {
	zones: { number },
	round: number,
	roundStart: number,
	scores: { number },
	done: boolean,
}

local CrucibleFocus = {}

-- Zone centre for a server random in [0,1), kept fully on the bar.
function CrucibleFocus.zoneFor(cfg: any, roll: number): number
	local w = cfg.Crucible.focus.zoneWidth
	return w / 2 + math.clamp(roll, 0, 1) * (1 - w)
end

function CrucibleFocus.new(cfg: any, rolls: { number }, now: number): Focus
	local zones = {}
	for i = 1, cfg.Crucible.focus.rounds do
		zones[i] = CrucibleFocus.zoneFor(cfg, rolls[i] or 0.5)
	end
	return { zones = zones, round = 1, roundStart = now, scores = {}, done = false }
end

-- Needle position 0..1 at `now` (0 → 1 → 0 …).
function CrucibleFocus.needle(f: Focus, cfg: any, now: number): number
	local p = (math.max(0, now - f.roundStart) / cfg.Crucible.focus.sweepSeconds) % 2
	return if p <= 1 then p else 2 - p
end

function CrucibleFocus.score(cfg: any, pos: number, centre: number): number
	local c = cfg.Crucible.focus
	local d, half = math.abs(pos - centre), c.zoneWidth / 2
	if d <= half then
		return 1
	elseif d <= half + c.nearMiss then
		return 0.5 * (1 - (d - half) / c.nearMiss)
	end
	return 0
end

local function advance(f: Focus, cfg: any, now: number)
	f.round += 1
	f.roundStart = now
	if f.round > cfg.Crucible.focus.rounds then
		f.done = true
	end
end

-- Scores a press for the current round; nil when finished.
function CrucibleFocus.press(f: Focus, cfg: any, now: number): number?
	if f.done then
		return nil
	end
	local s = CrucibleFocus.score(cfg, CrucibleFocus.needle(f, cfg, now), f.zones[f.round])
	f.scores[f.round] = s
	advance(f, cfg, now)
	return s
end

-- Times out rounds with no press.
function CrucibleFocus.step(f: Focus, cfg: any, now: number)
	local limit = cfg.Crucible.focus.roundSeconds
	while not f.done and now - f.roundStart >= limit do
		f.scores[f.round] = 0
		advance(f, cfg, f.roundStart + limit)
	end
end

function CrucibleFocus.result(f: Focus, cfg: any): number
	local n, sum = cfg.Crucible.focus.rounds, 0
	for i = 1, n do
		sum += f.scores[i] or 0
	end
	return sum / n
end

return CrucibleFocus
