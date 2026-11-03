local R = require("../src/shared/PlayerHitReact")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["knock keeps a small push and clamps a huge one"] = function()
		local k = R.knock(30, 0, 10) :: any
		eq(k.x, 30, "x")
		eq(k.z, 0, "z")
		eq(k.at, 10, "at")
		local big = R.knock(0, -600, 1) :: any
		eq(big.z, -R.MAX_SPEED, "clamped")
		eq(R.knock(0, 0, 1), nil, "zero push")
		eq(R.knock(0 / 0, 1, 1), nil, "nan")
	end,
	["client applies a fresh knock once"] = function()
		local k = R.toApply(20, 5, 100, 100.2, nil) :: any
		eq(k.x, 20, "applied")
		eq(R.toApply(20, 5, 100, 100.3, 100), nil, "same knock twice")
		eq((R.toApply(20, 5, 101, 101.1, 100) :: any).at, 101, "newer knock")
	end,
	["client ignores stale, skewed and bad knocks"] = function()
		eq(R.toApply(20, 0, 100, 102, nil), nil, "stale")
		eq(R.toApply(20, 0, 105, 100, nil), nil, "future")
		eq(R.toApply("x", 0, 100, 100, nil), nil, "bad type")
		eq((R.toApply(0, 999, 100, 100, nil) :: any).z, R.MAX_SPEED, "client clamps too")
	end,
	["only the victim's casts still in wind-up are interrupted"] = function()
		local casts = {
			{ castId = "b", casterUserId = 7, releaseAt = 12 },
			{ castId = "a", casterUserId = 7, releaseAt = 11 },
			{ castId = "c", casterUserId = 7, releaseAt = 9 }, -- already released
			{ castId = "d", casterUserId = 8, releaseAt = 12 }, -- someone else
		}
		local w = R.windups(casts, 7, 10)
		eq(#w, 2, "count")
		eq(w[1], "a", "sorted 1")
		eq(w[2], "b", "sorted 2")
		eq(#R.windups(casts, 7, 12), 0, "at release")
	end,
}
