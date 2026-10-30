--!strict
-- Academy Rank test credit (T-023c, D-168). Pure: a boss kind with a `rankTest` id records that test as
-- passed in the killer's profile `trials` table ({ [id] = { at, count } }). `credit` returns true only on
-- the first pass, so the caller can show a one-time cue. No Roblox services.
local RankTest = {}

export type Entry = { at: number, count: number }

function RankTest.passed(data: any, id: string): boolean
	if type(data) ~= "table" or type(data.trials) ~= "table" then
		return false
	end
	return type(data.trials[id]) == "table"
end

function RankTest.credit(data: any, bossKind: any, now: number): boolean
	if type(data) ~= "table" or type(bossKind) ~= "table" then
		return false
	end
	local id = bossKind.rankTest
	if type(id) ~= "string" then
		return false
	end
	if type(data.trials) ~= "table" then
		data.trials = {}
	end
	local entry = data.trials[id]
	if type(entry) == "table" then
		entry.count = (if type(entry.count) == "number" then entry.count else 1) + 1
		return false
	end
	data.trials[id] = { at = now, count = 1 }
	return true
end

return RankTest
