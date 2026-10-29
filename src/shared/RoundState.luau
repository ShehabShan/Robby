--!strict
-- Pure round state machine: Waiting -> Intermission -> Racing -> Results -> ...
-- No Roblox services; the server feeds it time, player count and finish status.

export type Phase = "Waiting" | "Intermission" | "Racing" | "Results"

export type Timings = {
	minPlayers: number,
	intermission: number,
	race: number,
	results: number,
}

export type State = {
	phase: Phase,
	timeLeft: number,
	round: number,
}

local RoundState = {}

function RoundState.new(): State
	return { phase = "Waiting", timeLeft = 0, round = 0 }
end

local function enter(state: State, phase: Phase, timings: Timings): State
	local duration = 0
	local round = state.round
	if phase == "Intermission" then
		duration = timings.intermission
	elseif phase == "Racing" then
		duration = timings.race
		round += 1
	elseif phase == "Results" then
		duration = timings.results
	end
	return { phase = phase, timeLeft = duration, round = round }
end

-- Advances the state by `dt` seconds.
-- Returns the new state and the phase entered during this step (nil if unchanged).
function RoundState.step(
	state: State,
	dt: number,
	playerCount: number,
	allFinished: boolean,
	timings: Timings
): (State, Phase?)
	local enough = playerCount >= timings.minPlayers

	if state.phase == "Waiting" then
		if enough then
			return enter(state, "Intermission", timings), "Intermission"
		end
		return state, nil
	end

	local timeLeft = state.timeLeft - dt
	local ticked: State = { phase = state.phase, timeLeft = timeLeft, round = state.round }

	if state.phase == "Intermission" then
		if not enough then
			return enter(state, "Waiting", timings), "Waiting"
		elseif timeLeft <= 0 then
			return enter(state, "Racing", timings), "Racing"
		end
	elseif state.phase == "Racing" then
		if timeLeft <= 0 or allFinished or playerCount == 0 then
			return enter(state, "Results", timings), "Results"
		end
	elseif state.phase == "Results" then
		if timeLeft <= 0 then
			local nextPhase: Phase = if enough then "Intermission" else "Waiting"
			return enter(state, nextPhase, timings), nextPhase
		end
	end

	return ticked, nil
end

return RoundState
