--!strict
-- Offline evidence policy only. Passing a synthetic report never certifies the engine.
local Evidence = {}
function Evidence.guard(studio: boolean, running: boolean, server: boolean, optIn: boolean, players: number): boolean
	return studio == true and running == true and server == true and optIn == true and players == 1
end
local function finite(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
function Evidence.accept(row: any): boolean
	if type(row) ~= "table" then
		return false
	end
	for _, key in
		{
			"distance",
			"maxX",
			"elapsed",
			"minDt",
			"maxDt",
			"pairs",
			"maxYError",
			"maxYDip",
			"maxSide",
			"commandedDistance",
			"lastSpeed",
			"simulatedSeconds",
		}
	do
		if not finite(row[key]) then
			return false
		end
	end
	if row.committed ~= true or row.clean ~= true or row.restored ~= true or row.phaseOK ~= true then
		return false
	end
	if row.pairs < 1 or row.pairs % 1 ~= 0 or row.minDt <= 0 or row.maxDt > 0.05 or row.maxDt < row.minDt then
		return false
	end
	if
		row.elapsed <= 0
		or row.elapsed > 0.5
		or row.maxSide < 0
		or row.maxYError < 0
		or row.maxYDip < 0
		or (row.kind ~= "fall" and row.maxYDip > 0.2)
		or row.maxX < row.distance
		or row.maxSide > 0.5
		or row.commandedDistance < 0
		or row.commandedDistance > 14.001
		or row.lastSpeed < 0
		or row.lastSpeed > 70.001
		or row.simulatedSeconds <= 0
		or row.simulatedSeconds > 0.29
	then
		return false
	end
	if row.kind == "travel" or row.kind == "fall" then
		return math.abs(row.distance - 14) <= 1
			and row.maxX <= 15
			and math.abs(row.commandedDistance - 14) <= 1
			and (row.kind ~= "fall" or row.maxYError <= 2)
	elseif row.kind == "wall" then
		return row.distance >= 2 and row.maxX <= 5 -- wall near face x6 minus root half width1
	elseif row.kind == "cancel" then
		return row.distance >= 0 and row.maxX < 13 and row.cancelled == true and row.velocityKept == true
	end
	return false
end
-- Death/replacement probe (D-366): the lease must stop within one frame of character removal and
-- leave no WindStep force on the old root or the replacement root. Not counted in the 106-case matrix.
function Evidence.replacement(probe: any): boolean
	if type(probe) ~= "table" then
		return false
	end
	local frames = probe.framesToStop
	return probe.committed == true
		and probe.stopped == true
		and type(frames) == "number"
		and frames == frames
		and frames % 1 == 0
		and frames >= 0
		and frames <= 1
		and probe.oldRootForce == false
		and probe.newRootClean == true
end
function Evidence.finish(environment: any, rows: { any }, cleanup: boolean): any
	local expected = {
		["travel-auto"] = "travel",
		["travel-player"] = "travel",
		["travel-server"] = "travel",
		["wall"] = "wall",
		["fall"] = "fall",
		["cancel"] = "cancel",
	}
	for i = 1, 100 do
		expected["lifetime-" .. i] = "travel"
	end
	local seen, passed = {}, 0
	local valid = Evidence.guard(
		environment.studio,
		environment.running,
		environment.server,
		environment.optIn,
		environment.players
	)
	for _, row in rows do
		if type(row) ~= "table" or not expected[row.name] or seen[row.name] or expected[row.name] ~= row.kind then
			valid = false
		else
			seen[row.name] = true
			if Evidence.accept(row) then
				passed += 1
			else
				valid = false
			end
		end
	end
	for name in expected do
		if not seen[name] then
			valid = false
		end
	end
	return {
		schema = 1,
		kind = "WindStep isolated Studio dynamics",
		environment = environment,
		results = rows,
		passed = passed,
		expected = 106,
		cleanup = cleanup,
		matrixPassed = valid and cleanup == true and #rows == 106,
		-- First slice does NOT cover death/replacement or deliberate frame-rate variation.
		dynamicsAccepted = false,
		remaining = {
			"death/original-root replacement",
			"supported rate variation and final-partial analysis",
			"device/owner feel (separate)",
		},
	}
end
return Evidence
