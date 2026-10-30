--!strict
-- RimeshardSim (T-027g, D-182): pure, time-stepped combat sim for the balance pass (R-028 §3).
-- Compares Crescent Cut with the Rimeshard rotation (Needle chain, Z Shard Fan, X Rime Fall, C Shatter) against
-- stationary targets. Qi, cooldowns, Chill stacks/expiry and zone ticks follow `Config`; travel time, misses, dodges
-- and the target's own attacks are ignored, so numbers are a ceiling, not a playtest. Run `scripts/rime_balance.luau`.

local Frost = require("./Frost")

local Sim = {}

export type Target = { hp: number, stacks: number, chillUntil: number }
export type Result = { ttk: number?, damage: number, casts: { [string]: number } }
export type Opts = { maxSeconds: number?, dt: number?, finisherRecovery: number? }

local DEFAULT_MAX = 300
local DEFAULT_DT = 0.05
local FALL_CAST_LOCK = 0.3 -- the caster is busy for the palm-raise, not the whole zone telegraph

function Sim.targets(hp: number, n: number): { Target }
	local list: { Target } = {}
	for _ = 1, n do
		table.insert(list, { hp = hp, stacks = 0, chillUntil = 0 })
	end
	return list
end

local function alive(targets: { Target }): { Target }
	local out: { Target } = {}
	for _, t in targets do
		if t.hp > 0 then
			table.insert(out, t)
		end
	end
	return out
end

local function hit(t: Target, dmg: number, res: Result)
	local dealt = math.min(dmg, t.hp)
	t.hp -= dealt
	res.damage += dealt
end

local function chill(t: Target, now: number, cfg: any)
	t.stacks = math.min(t.stacks + 1, cfg.maxStacks)
	t.chillUntil = now + cfg.seconds
end

local function count(res: Result, key: string)
	res.casts[key] = (res.casts[key] or 0) + 1
end

-- Crescent Cut spam: cast whenever cooldown and Qi allow; each blade pierces up to maxHits targets.
function Sim.crescent(cfg: any, targets: { Target }, opts: Opts?): Result
	local o: Opts = opts or {}
	local c = cfg.Abilities.CrescentCut
	local dt, maxS = o.dt or DEFAULT_DT, o.maxSeconds or DEFAULT_MAX
	local res: Result = { ttk = nil, damage = 0, casts = {} }
	local now, qi, ready = 0, cfg.Qi.max, 0
	while now < maxS do
		local live = alive(targets)
		if #live == 0 then
			res.ttk = now
			return res
		end
		if now >= ready and qi >= c.cost then
			for i = 1, math.min(c.maxHits, #live) do
				hit(live[i], c.baseDamage, res)
			end
			qi -= c.cost
			ready = now + c.cooldown
			count(res, "crescent")
		end
		qi = math.min(cfg.Qi.max, qi + cfg.Qi.regen * dt)
		now += dt
	end
	return res
end

-- Rimeshard rotation: Shatter when the primary target is Rimed → Rime Fall → Shard Fan → Needle chain.
function Sim.rimeshard(cfg: any, targets: { Target }, opts: Opts?): Result
	local o: Opts = opts or {}
	local r = cfg.Abilities.Rimeshard
	local n, fan, fall, sh, ch = r.needle, r.shardFan, r.rimeFall, r.shatter, r.chill
	local finisherRecovery = o.finisherRecovery or n.finisherRecovery
	local dt, maxS = o.dt or DEFAULT_DT, o.maxSeconds or DEFAULT_MAX
	local res: Result = { ttk = nil, damage = 0, casts = {} }
	local now, qi = 0, cfg.Qi.max
	local cd = { fan = 0, fall = 0, shatter = 0 }
	local busyUntil, nextPress, step = 0, 0, 0
	local ticks: { number } = {} -- pending Rime Fall tick times (all targets stand in the zone)
	while now < maxS do
		local live = alive(targets)
		if #live == 0 then
			res.ttk = now
			return res
		end
		for _, t in live do
			if now > t.chillUntil then
				t.stacks = 0
			end
		end
		local due = 0
		for i, at in ticks do
			if at <= now then
				due = i
			end
		end
		for _ = 1, due do
			table.remove(ticks, 1)
			for _, t in live do
				hit(t, fall.damagePerTick, res)
				chill(t, now, ch)
			end
		end
		if now >= busyUntil then
			local primary = live[1]
			if now >= cd.shatter and qi >= sh.cost and primary.stacks >= ch.maxStacks then
				for i = 1, math.min(sh.maxTargets, #live) do
					local t = live[i]
					local out = Frost.shatter(t.stacks, ch, sh)
					hit(t, out.damage, res)
					t.stacks = 0
				end
				qi -= sh.cost
				cd.shatter = now + sh.cooldown
				busyUntil = now + sh.telegraph
				count(res, "shatter")
			elseif now >= cd.fall and qi >= fall.cost then
				for i = 1, fall.ticks do
					local frac = if fall.ticks == 1 then 0 else (i - 1) / (fall.ticks - 1)
					table.insert(ticks, now + fall.delay + fall.duration * frac)
				end
				qi -= fall.cost
				cd.fall = now + fall.cooldown
				busyUntil = now + FALL_CAST_LOCK
				count(res, "fall")
			elseif now >= cd.fan and qi >= fan.cost then
				local shards = fan.count
				for _, t in live do
					local k = math.min(fan.perTargetCap, shards)
					for _ = 1, k do
						hit(t, fan.damage, res)
						chill(t, now, ch)
					end
					shards -= k
					if shards <= 0 then
						break
					end
				end
				qi -= fan.cost
				cd.fan = now + fan.cooldown
				busyUntil = now + fan.telegraph
				count(res, "fan")
			elseif now >= nextPress then
				step += 1
				if step < n.chain.steps then
					hit(primary, n.damage, res)
					chill(primary, now, ch)
					nextPress = now + n.chain.recovery
					count(res, "needle")
				else
					local shards = if qi >= n.finisher.cost then n.finisher.shards else 1
					for _ = 1, shards do
						hit(primary, n.damage, res)
						chill(primary, now, ch)
					end
					if shards > 1 then
						qi -= n.finisher.cost
					end
					step = 0
					nextPress = now + finisherRecovery
					count(res, "finisher")
				end
			end
		end
		qi = math.min(cfg.Qi.max, qi + cfg.Qi.regen * dt)
		now += dt
	end
	return res
end

return Sim
