--!strict
-- Beast AI brain (T-022a, D-124). Pure state machine, no services: the server feeds distances each tick and
-- acts on the output (move, show telegraph, resolve the strike). Every attack telegraphs for at least
-- `Config.Beasts.minTelegraph` (0.4 s) before it lands; a parry stagger cancels the wind-up.
-- States: Idle → Chase → Windup (telegraph) → Recover → Chase; Return (leash, heals); Staggered.

local BeastBrain = {}

export type Kind = {
	name: string,
	rank: number,
	hp: number,
	speed: number,
	aggro: number, -- studs: notices a target this close
	leash: number, -- studs from home: gives up and returns
	range: number, -- strike reach
	arcDot: number, -- facing dot needed to hit (-1 = all round slam)
	telegraph: number, -- wind-up seconds before the strike lands
	recover: number,
	cooldown: number,
	damage: number,
	shards: number,
	wildKith: string?,
}
export type Brain = { kind: string, state: string, since: number, lastStrike: number, staggerUntil: number }
export type Input = { now: number, targetDist: number?, homeDist: number }
export type Output = { state: string, move: string?, telegraph: boolean, strike: boolean, heal: boolean }

local HOME_EPS = 4

function BeastBrain.new(kind: string, now: number): Brain
	return { kind = kind, state = "Idle", since = now, lastStrike = -math.huge, staggerUntil = 0 }
end

local function enter(b: Brain, state: string, now: number)
	b.state = state
	b.since = now
end

function BeastBrain.step(b: Brain, k: Kind, input: Input): Output
	local now, dist = input.now, input.targetDist
	local out: Output = { state = b.state, move = nil, telegraph = false, strike = false, heal = false }
	if b.state == "Staggered" then
		if now < b.staggerUntil then
			return out
		end
		enter(b, "Chase", now)
	end
	if b.state ~= "Return" and b.state ~= "Windup" and input.homeDist > k.leash then
		enter(b, "Return", now)
	end
	if b.state == "Return" then
		if input.homeDist <= HOME_EPS then
			enter(b, "Idle", now)
			out.heal = true
		else
			out.move = "home"
		end
	elseif b.state == "Idle" then
		if dist and dist <= k.aggro then
			enter(b, "Chase", now)
		end
	end
	if b.state == "Chase" then
		if not dist or dist > k.aggro * 1.5 then
			enter(b, "Return", now)
			out.move = "home"
		elseif dist <= k.range and now - b.lastStrike >= k.cooldown then
			enter(b, "Windup", now)
		else
			out.move = if dist > k.range * 0.8 then "target" else nil
		end
	end
	if b.state == "Windup" then
		out.telegraph = true
		if now - b.since >= k.telegraph then
			out.strike = true
			b.lastStrike = now
			enter(b, "Recover", now)
		end
	elseif b.state == "Recover" and now - b.since >= k.recover then
		enter(b, "Chase", now)
	end
	out.state = b.state
	return out
end

-- Parry / guard break: cancels a wind-up and freezes the beast for `seconds`.
function BeastBrain.stagger(b: Brain, now: number, seconds: number)
	b.staggerUntil = math.max(b.staggerUntil, now + seconds)
	enter(b, "Staggered", now)
end

-- Does a strike that lands now hit a target `dist` away at facing dot `dot` (beast forward · to-target)?
function BeastBrain.hits(k: Kind, dist: number, dot: number): boolean
	return dist <= k.range + 1 and dot >= k.arcDot
end

function BeastBrain.validate(cfg: any): { string }
	local errors = {}
	for id, k in cfg.Beasts.kinds do
		if string.sub(id, 1, 6) ~= "beast." then
			table.insert(errors, `{id}: id must start with beast.`)
		end
		if k.telegraph < cfg.Beasts.minTelegraph then
			table.insert(errors, `{id}: telegraph {k.telegraph} < {cfg.Beasts.minTelegraph}`)
		end
		if k.leash <= k.aggro or k.hp <= 0 or k.damage <= 0 then
			table.insert(errors, `{id}: bad numbers`)
		end
	end
	table.sort(errors)
	return errors
end

return BeastBrain
