local Config = require("../src/shared/Config")
local Combat = require("../src/shared/Combat")
local Rewind = require("../src/shared/Rewind")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local C = Config.Combat

local function lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

return {
	["chain: five steps then wraps to 1"] = function()
		local chain = Combat.newChain()
		local t = 0
		for i = 1, C.chain.steps do
			eq(Combat.press(chain, t, C.chain), i, `step {i}`)
			t += C.chain.recovery + 0.001 -- float-safe spacing
		end
		eq(Combat.press(chain, t, C.chain), 1, "wrap")
	end,
	["chain: presses during recovery are ignored"] = function()
		local chain = Combat.newChain()
		eq(Combat.press(chain, 0, C.chain), 1)
		eq(Combat.press(chain, C.chain.recovery / 2, C.chain), nil, "too soon")
		eq(chain.step, 1, "unchanged")
	end,
	["chain: a late press restarts the chain"] = function()
		local chain = Combat.newChain()
		Combat.press(chain, 0, C.chain)
		Combat.press(chain, C.chain.recovery, C.chain)
		eq(Combat.press(chain, C.chain.recovery + C.chain.window + 0.01, C.chain), 1)
	end,

	["parry: only inside the window, with cooldown"] = function()
		local p = Combat.newParry()
		eq(Combat.parries(p, 0), false, "never opened")
		eq(Combat.parry(p, 5, C.parry), true)
		eq(Combat.parries(p, 5 + C.parry.window / 2), true, "inside")
		eq(Combat.parries(p, 5 + C.parry.window + 0.01), false, "late")
		eq(Combat.parries(p, 4.99), false, "before")
		eq(Combat.parry(p, 5 + C.parry.cooldown / 2, C.parry), false, "cooldown")
	end,
	["guard: blocks, breaks on empty meter or guard-break"] = function()
		local g = Combat.newGuard(C.guard)
		eq(Combat.hitGuard(g, 10, false), "open", "not guarding")
		Combat.setGuard(g, true)
		eq(Combat.hitGuard(g, 10, false), "blocked")
		eq(g.meter, C.guard.max - 10)
		eq(Combat.hitGuard(g, C.guard.max, false), "broken", "emptied")
		eq(g.up, false)
		Combat.setGuard(g, true)
		eq(g.up, false, "cannot guard on empty meter")
		Combat.regenGuard(g, 1000, 10, C.guard)
		eq(g.meter, C.guard.max, "regen capped")
		Combat.setGuard(g, true)
		eq(Combat.hitGuard(g, 1, true), "broken", "guard-break hit")
	end,
	["rewind: lookback is clamped to 250 ms"] = function()
		eq(Rewind.checkTime(10, 0.1), 9.9)
		eq(Rewind.checkTime(10, 2), 9.75, "cap")
		eq(Rewind.checkTime(10, -1), 10, "negative")
		eq(Rewind.checkTime(10, 0 / 0), 9.75, "nan")
	end,
	["rewind: interpolates and trims to the window"] = function()
		local buf = Rewind.new(1)
		eq(Rewind.at(buf, 0), nil, "empty")
		for i = 0, 40 do
			Rewind.record(buf, i * 0.05, i)
		end
		eq(buf.samples[1].t >= 1, true, "trimmed to 1 s")
		eq(math.abs(Rewind.at(buf, 1.525, lerp) - 30.5) < 1e-6, true, "lerp")
		eq(Rewind.at(buf, 1.525), 30, "older neighbour")
		eq(Rewind.at(buf, 0), buf.samples[1].v, "clamp old")
		eq(Rewind.at(buf, 99), 40, "clamp new")
		Rewind.record(buf, 0.5, -1)
		eq(buf.samples[#buf.samples].v, 40, "time going back is ignored")
	end,
}
