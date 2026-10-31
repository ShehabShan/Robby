local Status = require("../src/shared/Status")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["status: a grant lasts until its end time"] = function()
		local s = Status.new()
		Status.grant(s, "a", "State.Iframes", 2)
		eq(Status.has(s, "a", "State.Iframes", 1.9), true, "during")
		eq(Status.has(s, "a", "State.Iframes", 2), false, "at end")
		eq(Status.has(s, "b", "State.Iframes", 1), false, "other entity")
	end,
	["status: a shorter grant does not cut a longer one"] = function()
		local s = Status.new()
		Status.grant(s, "a", "State.Iframes", 5)
		Status.grant(s, "a", "State.Iframes", 1)
		eq(Status.has(s, "a", "State.Iframes", 3), true)
	end,
	["status: ward and i-frames block hits; clear removes them"] = function()
		local s = Status.new()
		eq(Status.blocksHit(s, "a", 0), false, "none")
		Status.grant(s, "a", "State.Iframes", 1)
		eq(Status.blocksHit(s, "a", 0.5), true, "iframes")
		Status.grant(s, "b", "State.Iframes", 1)
		eq(Status.blocksHit(s, "b", 0.5), true, "ward")
		Status.grant(s, "c", "State.Other", 1)
		eq(Status.blocksHit(s, "c", 0.5), false, "other tag")
		Status.clear(s, "a")
		eq(Status.blocksHit(s, "a", 0.5), false, "cleared")
	end,
	["status: expiry reports the grant end (T-031)"] = function()
		local s = Status.new()
		eq(Status.expiry(s, "m", "State.Staggered"), -math.huge, "never granted")
		Status.grant(s, "m", "State.Staggered", 3)
		Status.grant(s, "m", "State.Staggered", 2)
		eq(Status.expiry(s, "m", "State.Staggered"), 3, "longer grant kept")
		eq(Status.expiry(s, "m", "State.Other"), -math.huge, "other tag")
	end,
}
