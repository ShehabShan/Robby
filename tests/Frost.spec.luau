local Tags = require("../src/shared/Tags")
local Effects = require("../src/shared/Effects")
local Frost = require("../src/shared/Frost")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local chillCfg = { maxStacks = 3, seconds = 3, slowPerStack = 0.15 }
local shatterCfg = { base = 12, perStack = 8, staggerSeconds = 0.4 }
local chill = Frost.chillEffect(chillCfg)
local defs: { [string]: any } = { [Frost.CHILL_ID] = chill }

local function lookup(id: string): any
	return defs[id]
end
local function ctx(now: number): any
	return { now = now, tags = Tags }
end

return {
	["chill stacks to the cap, slows per stack and tags the target"] = function()
		local h = Effects.newHolder()
		eq(Frost.stacks(h), 0, "no chill")
		for _ = 1, 5 do
			Effects.apply(h, chill, "p1", ctx(0))
		end
		eq(Frost.stacks(h), 3, "capped")
		eq(Tags.has(h.tags, Frost.CHILLED_TAG), true, "tag")
		local mods = Effects.modifiers(h, lookup)
		eq(#mods, 1, "one modifier")
		eq(mods[1].attr, "MoveSpeed")
		eq(math.abs(mods[1].value - -0.45) < 1e-9, true, "−15 % × 3")
	end,
	["chill refreshes on hit and expires after 3 s"] = function()
		local h = Effects.newHolder()
		Effects.apply(h, chill, "p1", ctx(0))
		Effects.apply(h, chill, "p1", ctx(2))
		Effects.tick(h, lookup, ctx(4))
		eq(Frost.stacks(h), 2, "refreshed, still alive at 4 s")
		Effects.tick(h, lookup, ctx(5))
		eq(Frost.stacks(h), 0, "expired")
		eq(Tags.has(h.tags, Frost.CHILLED_TAG), false, "tag removed")
	end,
	["shatter math: 12 + 8 per stack, stagger only when rimed, nothing without chill"] = function()
		eq(Frost.shatter(0, chillCfg, shatterCfg).damage, 0, "no free damage")
		eq(Frost.shatter(1, chillCfg, shatterCfg).damage, 20)
		local s2 = Frost.shatter(2, chillCfg, shatterCfg)
		eq(s2.damage, 28)
		eq(s2.stagger, 0, "not rimed")
		local s3 = Frost.shatter(3, chillCfg, shatterCfg)
		eq(s3.damage, 36, "max 36 (note §2)")
		eq(s3.stagger, 0.4, "rimed staggers")
		eq(Frost.shatter(9, chillCfg, shatterCfg).damage, 36, "clamped to cap")
	end,
	["consume pays out and clears the chill"] = function()
		local h = Effects.newHolder()
		for _ = 1, 3 do
			Effects.apply(h, chill, "p1", ctx(0))
		end
		local r = Frost.consume(h, lookup, ctx(1), chillCfg, shatterCfg)
		eq(r.damage, 36)
		eq(r.stacks, 3)
		eq(Frost.stacks(h), 0, "consumed")
		eq(Tags.has(h.tags, Frost.CHILLED_TAG), false, "tag cleared")
		local again = Frost.consume(h, lookup, ctx(1), chillCfg, shatterCfg)
		eq(again.damage, 0, "second shatter does nothing")
	end,
}
