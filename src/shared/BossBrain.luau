--!strict
-- Boss AI (T-023a, D-137). Pure: no services, tested under Lune; the server (T-023b) owns physics and hits.
-- A boss runs a fixed, readable attack pattern (Config.Bosses.kinds[id].pattern). Below `phase2At` of its
-- HP it switches to `pattern2` and recovers faster, but every attack still winds up for at least
-- Config.Bosses.minTelegraph seconds, so it stays readable and dodgeable at Rank 1–2.

local BossBrain = {}

local HOME_EPS = 3

export type Brain = {
	kind: string,
	state: string, -- Idle | Chase | Windup | Recover | Staggered | Return
	since: number,
	phase: number, -- 1 or 2
	index: number, -- position in the current pattern
	attack: string?, -- attack being wound up / recovered from
	lastStrike: number,
	staggerUntil: number,
}
export type Input = { now: number, targetDist: number?, homeDist: number, hpFrac: number }
export type Output = {
	state: string,
	move: string?,
	attack: string?,
	telegraph: boolean,
	strike: boolean,
	heal: boolean,
	phaseChanged: boolean,
}

function BossBrain.new(kind: string, now: number): Brain
	return {
		kind = kind,
		state = "Idle",
		since = now,
		phase = 1,
		index = 1,
		attack = nil,
		lastStrike = -math.huge,
		staggerUntil = 0,
	}
end

local function enter(b: Brain, state: string, now: number)
	b.state = state
	b.since = now
end

local function pattern(b: Brain, k: any): { string }
	return if b.phase == 2 then k.pattern2 else k.pattern
end

-- The attack the boss will use next.
function BossBrain.nextAttack(b: Brain, k: any): string
	local p = pattern(b, k)
	return p[((b.index - 1) % #p) + 1]
end

function BossBrain.step(b: Brain, k: any, input: Input): Output
	local now, dist = input.now, input.targetDist
	local out: Output = {
		state = b.state,
		move = nil,
		attack = nil,
		telegraph = false,
		strike = false,
		heal = false,
		phaseChanged = false,
	}
	if b.phase == 1 and input.hpFrac <= k.phase2At then
		b.phase = 2
		b.index = 1
		out.phaseChanged = true
	end
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
			b.phase, b.index, b.attack = 1, 1, nil
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
		local id = BossBrain.nextAttack(b, k)
		local a = k.attacks[id]
		if not dist or dist > k.aggro * 1.5 then
			enter(b, "Return", now)
			out.move = "home"
		elseif dist <= a.range and now - b.lastStrike >= k.gap then
			b.attack = id
			enter(b, "Windup", now)
		else
			out.move = if dist > a.range * 0.8 then "target" else nil
		end
	end
	if b.state == "Windup" and b.attack then
		local a = k.attacks[b.attack]
		out.telegraph = true
		out.attack = b.attack
		if now - b.since >= a.telegraph then
			out.strike = true
			b.lastStrike = now
			b.index += 1
			enter(b, "Recover", now)
		end
	elseif b.state == "Recover" and b.attack then
		local a = k.attacks[b.attack]
		local rec = a.recover * (if b.phase == 2 then k.phase2Recover else 1)
		if now - b.since >= rec then
			enter(b, "Chase", now)
		end
	end
	out.state = b.state
	return out
end

-- Parry / guard break: cancels a wind-up (the pattern does not advance) and freezes the boss.
function BossBrain.stagger(b: Brain, now: number, seconds: number)
	enter(b, "Staggered", now)
	b.attack = nil
	b.staggerUntil = now + seconds
end

-- Does attack `a` reach a target at `dist` studs, `dot` = facing · direction-to-target?
function BossBrain.hits(a: any, dist: number, dot: number): boolean
	return dist <= a.range and dot >= a.arcDot
end

-- Config.Bosses → list of problems (empty = valid).
function BossBrain.validate(cfg: any): { string }
	local errs: { string } = {}
	local floor = cfg.minTelegraph or 0.4
	for id, k in cfg.kinds do
		if not (typeof(k.phase2At) == "number" and k.phase2At > 0 and k.phase2At < 1) then
			table.insert(errs, `{id}: phase2At must be in (0, 1)`)
		end
		for aid, a in k.attacks do
			if typeof(a.telegraph) ~= "number" or a.telegraph < floor then
				table.insert(errs, `{id}.{aid}: telegraph below {floor}`)
			end
		end
		for _, key in { "pattern", "pattern2" } do
			local p = k[key]
			if typeof(p) ~= "table" or #p == 0 then
				table.insert(errs, `{id}: {key} empty`)
			else
				for _, aid in p do
					if k.attacks[aid] == nil then
						table.insert(errs, `{id}: {key} uses unknown attack {aid}`)
					end
				end
			end
		end
	end
	table.sort(errs)
	return errs
end

return BossBrain
