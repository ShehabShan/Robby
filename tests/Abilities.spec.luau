local Tags = require("../src/shared/Tags")
local Effects = require("../src/shared/Effects")
local Moves = require("../src/shared/Moves")
local Registry = require("../src/shared/Registry")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local defs: { [string]: any } = {
	["effect.guard"] = { id = "effect.guard", duration = "Timed", seconds = 2, grantTags = { "State.Guarding" } },
	["effect.bleed"] = {
		id = "effect.bleed",
		duration = "Timed",
		seconds = 3,
		period = 1,
		stack = { cap = 3, by = "target", refresh = true },
		ops = { { kind = "Dmg", params = { amount = 2 } } },
		modifiers = { { attr = "MoveSpeed", bucket = "Boost", value = -0.1 } },
	},
	["effect.mark"] = {
		id = "effect.mark",
		duration = "Timed",
		seconds = 5,
		stack = { cap = 2, by = "source", refresh = false },
	},
	["effect.hit"] = {
		id = "effect.hit",
		duration = "Inst",
		ops = { { kind = "Dmg" } },
		blockTags = { "State.Guarding" },
	},
	["effect.aura"] = { id = "effect.aura", duration = "Pers", period = 0.1, ops = { { kind = "Heal" } } },
	["effect.surge"] = {
		id = "effect.surge",
		duration = "Pers",
		stack = { cap = 2, by = "target", refresh = true },
		modifiers = { { attr = "Power.Moon", bucket = "Surge", value = 1.5 } },
	},
}
local function lookup(id: string): any
	return defs[id]
end

local function ctx(now: number, log: { string }?): any
	return {
		now = now,
		tags = Tags,
		onOp = function(op: any, effect: any, stacks: number)
			if log then
				table.insert(log, `{effect.id}:{op.kind}x{stacks}`)
			end
		end,
	}
end

local function caster(): any
	return { qi = 50, strain = 0, strainMax = 10, hp = 100, cooldowns = {} }
end

local crescent: any = {
	id = "move.crescent_cut",
	trigger = "Press",
	target = "Aim",
	delivery = { kind = "Projectile", params = { speed = 90, range = 60 } },
	costs = { qi = 20, strain = 1 },
	cooldown = 1.5,
	effects = { onHit = { "effect.hit" } },
	tags = { "Path.Moon", "Delivery.Proj" },
	fx = { cast = "fx.crescent.cast", hit = "fx.crescent.hit" },
}

return {
	["effects: timed grants tags then expires"] = function()
		local h = Effects.newHolder()
		eq(Effects.apply(h, defs["effect.guard"], "p1", ctx(0)), true)
		eq(Tags.has(h.tags, "State.Guarding"), true)
		Effects.tick(h, lookup, ctx(1.9))
		eq(#h.active, 1, "still active")
		Effects.tick(h, lookup, ctx(2))
		eq(#h.active, 0, "expired")
		eq(Tags.has(h.tags, "State"), false, "tag removed")
	end,

	["effects: instant runs ops once, blockTags reject"] = function()
		local log = {}
		local h = Effects.newHolder()
		eq(Effects.apply(h, defs["effect.hit"], "p1", ctx(0, log)), true)
		eq(#log, 1)
		eq(#h.active, 0, "instant leaves nothing")
		Effects.apply(h, defs["effect.guard"], "p1", ctx(0))
		eq(Effects.apply(h, defs["effect.hit"], "p2", ctx(0, log)), false, "guard blocks")
		eq(#log, 1)
	end,

	["effects: target stacking caps and refreshes"] = function()
		local h = Effects.newHolder()
		for _ = 1, 5 do
			Effects.apply(h, defs["effect.bleed"], "p" .. tostring(math.random(1, 9)), ctx(0))
		end
		eq(#h.active, 1, "one shared instance")
		eq(h.active[1].stacks, 3, "cap")
		Effects.apply(h, defs["effect.bleed"], "p1", ctx(2))
		eq(h.active[1].endsAt, 5, "refreshed")
	end,

	["effects: source stacking keeps instances apart, no refresh"] = function()
		local h = Effects.newHolder()
		Effects.apply(h, defs["effect.mark"], "a", ctx(0))
		Effects.apply(h, defs["effect.mark"], "b", ctx(0))
		Effects.apply(h, defs["effect.mark"], "a", ctx(1))
		Effects.apply(h, defs["effect.mark"], "a", ctx(2))
		eq(#h.active, 2)
		eq(h.active[1].stacks, 2, "cap 2")
		eq(h.active[1].endsAt, 5, "refresh off")
	end,

	["effects: periodic ops catch up, scale by stacks, stop at expiry"] = function()
		local log = {}
		local h = Effects.newHolder()
		Effects.apply(h, defs["effect.bleed"], "p1", ctx(0))
		Effects.apply(h, defs["effect.bleed"], "p1", ctx(0))
		Effects.tick(h, lookup, ctx(10, log))
		eq(#log, 3, "ticks at 1, 2, 3 only")
		eq(log[1], "effect.bleed:Dmgx2")
		eq(#h.active, 0)
	end,

	["effects: period floor 0.5 s, persistent never expires, remove"] = function()
		local log = {}
		local h = Effects.newHolder()
		Effects.apply(h, defs["effect.aura"], "p1", ctx(0))
		Effects.tick(h, lookup, ctx(2, log))
		eq(#log, 4, "0.1 s period floored to 0.5 s")
		Effects.tick(h, lookup, ctx(1000))
		eq(#h.active, 1, "persistent")
		eq(Effects.remove(h, "effect.aura", lookup, ctx(1000)), 1)
		eq(#h.active, 0)
	end,

	["effects: modifiers scale with stacks"] = function()
		local h = Effects.newHolder()
		Effects.apply(h, defs["effect.bleed"], "p1", ctx(0))
		Effects.apply(h, defs["effect.bleed"], "p1", ctx(0))
		Effects.apply(h, defs["effect.surge"], "p1", ctx(0))
		Effects.apply(h, defs["effect.surge"], "p1", ctx(0))
		local mods = Effects.modifiers(h, lookup)
		eq(#mods, 2)
		eq(math.abs(mods[1].value - -0.2) < 1e-9, true, "boost x2")
		eq(mods[2].value, 2.25, "surge ^2")
	end,

	["effects: retired content is dropped safely"] = function()
		local h = Effects.newHolder()
		table.insert(h.active, { effectId = "effect.gone", sourceUid = "x", stacks = 1 })
		Effects.tick(h, lookup, ctx(0))
		eq(#h.active, 0)
	end,

	["moves: pay costs and cooldown per move"] = function()
		local c = caster()
		eq(Moves.pay(c, crescent, 0), true)
		eq(c.qi, 30)
		eq(c.strain, 1)
		local ok, why = Moves.pay(c, crescent, 1)
		eq(ok, false)
		eq(why, "cooldown")
		eq(Moves.remaining(c, crescent.id, 1), 0.5)
		eq(Moves.pay(c, crescent, 1.5), true, "ready again")
		local _, why2 = Moves.pay(c, crescent, 3)
		eq(why2, "qi")
		eq(c.qi, 10, "unchanged on failure")
	end,

	["moves: strain, hp and uses limits"] = function()
		local c = caster()
		c.strain = 10
		local _, a = Moves.check(c, crescent, 0)
		eq(a, "strain")
		local blood: any = { id = "move.blood", costs = { hp = 100 }, cooldown = 0 }
		local _, b = Moves.check(caster(), blood, 0)
		eq(b, "hp", "never self-kill")
		local pill: any = { id = "move.pill", costs = { uses = 2 }, cooldown = 0 }
		local d = caster()
		eq(Moves.pay(d, pill, 0), true)
		eq(Moves.pay(d, pill, 0), true)
		local _, u = Moves.pay(d, pill, 0)
		eq(u, "uses")
		local bad: any = { id = "move.bad", costs = { qi = -5 }, cooldown = 0 }
		local _, n = Moves.check(caster(), bad, 0)
		eq(n, "badCost")
	end,

	["registry: valid content builds lookups"] = function()
		local effects = {}
		for id, e in defs do
			if id ~= "effect.aura" then -- its 0.1 s period is deliberately invalid (floor test)
				table.insert(effects, e)
			end
		end
		local kith = { { id = "kith.crescent", moves = { "move.crescent_cut" } } }
		local built, errors = Registry.build({ effects = effects, moves = { crescent }, kith = kith })
		eq(#errors, 0, `errors: {table.concat(errors, "; ")}`)
		eq(built.moves["move.crescent_cut"], crescent)
		eq(built.kith["kith.crescent"] ~= nil, true)
	end,

	["registry: reports broken data"] = function()
		local _, errors = Registry.build({
			effects = {
				{ id = "effect.a", duration = "Timed" },
				{ id = "effect.b", duration = "Pers", period = 0.1 },
				{ id = "effect.b", duration = "Inst" },
				{ id = "bad", duration = "Inst" },
			},
			moves = {
				{
					id = "move.x",
					delivery = { kind = "Laser" },
					costs = {},
					cooldown = 1,
					effects = { onHit = { "effect.zzz" } },
				},
				{ id = "move.y", delivery = { kind = "Self" }, cooldown = -1, kith = "kith.none" },
			},
			kith = { { id = "kith.k", moves = { "move.nope" } } },
		})
		local all = table.concat(errors, "\n")
		for _, needle in
			{
				"Timed needs",
				"period must",
				"duplicate",
				"must start",
				"bad delivery",
				"unknown effect",
				"cooldown must",
				"missing costs",
				"unknown kith",
				"unknown move",
			}
		do
			eq(string.find(all, needle, 1, true) ~= nil, true, `missing error "{needle}"`)
		end
	end,
}
