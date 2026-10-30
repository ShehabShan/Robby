--!strict
-- Binding tug-of-war (T-017a, GDD "Binding", D-070). Pure: a duel state stepped by time.
-- The player channels Qi to push the bar up; the wild Kith pushes back in pulses scaled by its Will;
-- stopping the channel lets the bar slide back. Shards top up Qi (with a cooldown).
-- Bar full = bound; bar empty after the grace time, or the time limit = the Kith flees.
-- A guided bind (first bind, becomes the Heart Kith) cannot fail.

local Binding = {}

export type Duel = {
	progress: number, -- 0..1
	qi: number,
	will: number,
	t: number,
	pulseIn: number,
	shardReadyAt: number,
	guided: boolean,
	result: string?, -- nil while running, "bound" | "fled"
}

function Binding.new(cfg: any, will: number, qi: number, guided: boolean?): Duel
	local c = cfg.Binding
	return {
		progress = c.start,
		qi = qi,
		will = math.max(will, 0),
		t = 0,
		pulseIn = c.pulseEvery,
		shardReadyAt = 0,
		guided = guided == true,
		result = nil,
	}
end

-- Advances the duel by `dt` seconds. `channel` = the player holds the channel input this step.
function Binding.step(d: Duel, cfg: any, dt: number, channel: boolean): Duel
	if d.result ~= nil or dt <= 0 then
		return d
	end
	local c = cfg.Binding
	local willFactor = 1 + d.will * c.willWeight
	local delta: number
	if channel and d.qi > 0 then
		local spend = math.min(d.qi, c.qiPerSecond * dt)
		d.qi -= spend
		delta = (c.channelRate * (spend / (c.qiPerSecond * dt))) / willFactor * dt
	else
		delta = -c.slideRate * dt
	end
	d.pulseIn -= dt
	if d.pulseIn <= 0 then
		d.pulseIn += c.pulseEvery
		delta -= c.pulseStrength * willFactor
	end
	d.t += dt
	d.progress = math.clamp(d.progress + delta, 0, 1)
	if d.guided then
		d.progress = math.max(d.progress, c.guidedFloor)
	end
	if d.progress >= 1 then
		d.result = "bound"
	elseif not d.guided and ((d.progress <= 0 and d.t >= c.grace) or d.t >= c.timeLimit) then
		d.result = "fled"
	end
	return d
end

-- Spends one Shard to refill Qi. Returns false while on cooldown, when finished, or with no Shards.
function Binding.useShard(d: Duel, cfg: any, shards: number, qiMax: number): boolean
	local c = cfg.Binding
	if d.result ~= nil or shards < 1 or d.t < d.shardReadyAt then
		return false
	end
	d.qi = math.min(qiMax, d.qi + c.shardQi)
	d.shardReadyAt = d.t + c.shardCooldown
	return true
end

return Binding
