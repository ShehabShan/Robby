--!strict
-- Pure admission/report policy for a SEPARATE live test. Not part of the game build.
-- The caller supplies the unchanged canonical Studio Evidence module for row tolerances.
local Policy = {}
local PRODUCTION_UNIVERSE, PRODUCTION_PLACE, OWNER = 10773761715, 95587500384127, 7738981129
local function id(value: any): boolean
	return type(value) == "number" and value > 0 and value <= 9007199254740991 and value % 1 == 0
end
function Policy.target(target: any): boolean
	return type(target) == "table"
		and id(target.universeId)
		and id(target.placeId)
		and target.universeId ~= PRODUCTION_UNIVERSE
		and target.placeId ~= PRODUCTION_PLACE
		and target.ownerUserId == OWNER
end
function Policy.guard(target: any, environment: any): boolean
	return Policy.target(target)
		and type(environment) == "table"
		and environment.studio == false
		and environment.running == true
		and environment.server == true
		and environment.optIn == true
		and environment.players == 1
		and environment.playerUserId == target.ownerUserId
		and environment.universeId == target.universeId
		and environment.placeId == target.placeId
		and id(environment.placeVersion)
		and type(environment.jobId) == "string"
		and #environment.jobId > 0
		and #environment.jobId <= 128
end
function Policy.finish(target: any, environment: any, rows: { any }, cleanup: boolean, canonical: any): any
	local expected = {
		["travel-auto"] = "travel",
		["travel-player"] = "travel",
		["travel-server"] = "travel",
		wall = "wall",
		fall = "fall",
		cancel = "cancel",
	}
	for i = 1, 100 do
		expected["lifetime-" .. i] = "travel"
	end
	local seen, passed = {}, 0
	local valid = Policy.guard(target, environment)
	for _, row in rows do
		if type(row) ~= "table" or not expected[row.name] or seen[row.name] or expected[row.name] ~= row.kind then
			valid = false
		else
			seen[row.name] = true
			if canonical.accept(row) then
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
		kind = "WindStep isolated published dynamics",
		environment = environment,
		target = target,
		results = rows,
		passed = passed,
		expected = 106,
		cleanup = cleanup,
		matrixPassed = valid and cleanup == true and #rows == 106,
		dynamicsAccepted = false,
		remaining = {
			"death/original-root replacement",
			"supported rate variation and final-partial analysis",
			"device/owner feel (separate)",
		},
	}
end
return Policy
