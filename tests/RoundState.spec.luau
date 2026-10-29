local RoundState = require("../src/shared/RoundState")

local T = { minPlayers = 1, intermission = 10, race = 60, results = 5 }

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function at(phase: any, timeLeft: number, round: number)
	return { phase = phase, timeLeft = timeLeft, round = round }
end

return {
	["new state is Waiting, round 0"] = function()
		local s = RoundState.new()
		eq(s.phase, "Waiting")
		eq(s.round, 0)
	end,

	["Waiting stays Waiting with no players"] = function()
		local s, entered = RoundState.step(RoundState.new(), 1, 0, false, T)
		eq(s.phase, "Waiting")
		eq(entered, nil, "entered")
	end,

	["Waiting -> Intermission when enough players"] = function()
		local s, entered = RoundState.step(RoundState.new(), 1, 1, false, T)
		eq(s.phase, "Intermission")
		eq(entered, "Intermission", "entered")
		eq(s.timeLeft, 10, "timeLeft")
	end,

	["Intermission counts down"] = function()
		local s, entered = RoundState.step(at("Intermission", 10, 0), 3, 1, false, T)
		eq(s.phase, "Intermission")
		eq(s.timeLeft, 7, "timeLeft")
		eq(entered, nil, "entered")
	end,

	["Intermission -> Racing at zero and increments round"] = function()
		local s, entered = RoundState.step(at("Intermission", 1, 2), 1, 1, false, T)
		eq(s.phase, "Racing")
		eq(entered, "Racing", "entered")
		eq(s.round, 3, "round")
		eq(s.timeLeft, 60, "timeLeft")
	end,

	["Intermission aborts to Waiting when players leave"] = function()
		local s, entered = RoundState.step(at("Intermission", 5, 0), 1, 0, false, T)
		eq(s.phase, "Waiting")
		eq(entered, "Waiting", "entered")
	end,

	["Racing ends early when everyone finished"] = function()
		local s, entered = RoundState.step(at("Racing", 50, 1), 1, 2, true, T)
		eq(s.phase, "Results")
		eq(entered, "Results", "entered")
		eq(s.round, 1, "round")
	end,

	["Racing ends on timeout"] = function()
		local s = RoundState.step(at("Racing", 0.5, 1), 1, 2, false, T)
		eq(s.phase, "Results")
	end,

	["Racing ends when server empties"] = function()
		local s = RoundState.step(at("Racing", 30, 1), 1, 0, false, T)
		eq(s.phase, "Results")
	end,

	["Results -> Intermission with players"] = function()
		local s = RoundState.step(at("Results", 0.5, 1), 1, 1, false, T)
		eq(s.phase, "Intermission")
	end,

	["Results -> Waiting without players"] = function()
		local s = RoundState.step(at("Results", 0.5, 1), 1, 0, false, T)
		eq(s.phase, "Waiting")
	end,
}
