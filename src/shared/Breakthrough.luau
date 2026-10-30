--!strict
-- Rank breakthrough trial core (T-018e, D-077, GDD "Rank up"): with a full Peak Stage the player cracks the Core
-- Shell in `waves` waves of `crackPerWave` points, each wave within `waveSeconds`. Success = next Rank, Stage
-- First, empty bar. Failure keeps the full Peak and the cracks, which heal at `healPerSecond`, so a quick retry
-- keeps some progress. Pure; server wiring + UI are T-018f.

local Stages = require("./Stages")

export type Trial = { crack: number, wave: number, waveLeft: number, result: string? } -- "cracked" | "failed"

local Breakthrough = {}

-- Crack points left from the last failed trial after healing.
function Breakthrough.carried(data: any, cfg: any, now: number): number
	local b = data.breakthrough
	if type(b) ~= "table" or typeof(b.crack) ~= "number" or typeof(b.failedAt) ~= "number" then
		return 0
	end
	return math.max(0, b.crack - cfg.Breakthrough.healPerSecond * math.max(0, now - b.failedAt))
end

-- A new trial, or nil when the Peak is not full or the Rank is already max.
function Breakthrough.start(data: any, cfg: any, now: number): Trial?
	local c = cfg.Breakthrough
	if (data.rank or 1) >= c.maxRank or not Stages.ready(data, cfg) then
		return nil
	end
	local crack = math.min(Breakthrough.carried(data, cfg, now), c.crackPerWave * c.waves - 1)
	return { crack = crack, wave = math.floor(crack / c.crackPerWave) + 1, waveLeft = c.waveSeconds, result = nil }
end

-- Adds crack points; finishing a wave starts the next with a fresh timer.
function Breakthrough.hit(t: Trial, cfg: any, amount: number)
	local c = cfg.Breakthrough
	if t.result ~= nil or amount <= 0 then
		return
	end
	local total = c.crackPerWave * c.waves
	t.crack += amount
	if t.crack >= total then
		t.crack = total
		t.result = "cracked"
		return
	end
	local w = math.floor(t.crack / c.crackPerWave) + 1
	if w > t.wave then
		t.wave = w
		t.waveLeft = c.waveSeconds
	end
end

function Breakthrough.step(t: Trial, dt: number)
	if t.result ~= nil then
		return
	end
	t.waveLeft -= dt
	if t.waveLeft <= 0 then
		t.result = "failed"
	end
end

-- Crack points from damage the player deals during a trial (moves on the shell / wave enemies, T-018f).
function Breakthrough.crackFor(cfg: any, damage: number): number
	return math.max(0, damage) * cfg.Breakthrough.crackPerDamage
end

export type View = { wave: number, waves: number, crack: number, timeLeft: number }

-- HUD view: current wave, crack (0..1 of the wave) and whole seconds left.
function Breakthrough.view(t: Trial, cfg: any): View
	local c = cfg.Breakthrough
	local inWave = t.crack - (t.wave - 1) * c.crackPerWave
	return {
		wave = t.wave,
		waves = c.waves,
		crack = math.clamp(inWave / c.crackPerWave, 0, 1),
		timeLeft = math.max(0, math.ceil(t.waveLeft)),
	}
end

-- Applies a finished trial to the profile. Returns true on a Rank-up.
function Breakthrough.finish(data: any, t: Trial, now: number): boolean
	if t.result == "cracked" then
		data.rank = (data.rank or 1) + 1
		data.stage = 1
		data.stageProgress = 0
		data.breakthrough = nil
		return true
	elseif t.result == "failed" then
		data.breakthrough = { crack = t.crack, failedAt = now }
	end
	return false
end

return Breakthrough
