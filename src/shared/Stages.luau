--!strict
-- Stages core (T-018c, D-075, GDD "Rank up"): each Rank has 4 Stages (First, Second, Third, Peak) shown as a
-- Core Shell (mist → water → stone → crystal). Progress points fill the Stage bar and carry over; a full Peak
-- means the Rank breakthrough trial is ready (T-018e). Refine (at a rest spot only) turns Shards 1:1 into points.
-- Pure; works on the profile (`data.rank`, `data.stage`, `data.stageProgress`). Path Marks join with T-020.

local Stages = {}

Stages.NAMES = { "First", "Second", "Third", "Peak" }
Stages.SHELL = { "mist", "water", "stone", "crystal" }

-- Fixes missing / bad fields so old saves keep working.
function Stages.ensure(data: any)
	local n = #Stages.NAMES
	if typeof(data.stage) ~= "number" or data.stage ~= data.stage or data.stage < 1 then
		data.stage = 1
	end
	data.stage = math.min(math.floor(data.stage), n)
	local p = data.stageProgress
	if typeof(p) ~= "number" or p ~= p or p < 0 then
		data.stageProgress = 0
	end
end

-- Points needed to fill `stage` of `rank`.
function Stages.cost(cfg: any, rank: number, stage: number): number
	local c = cfg.Stages
	return math.floor(
		c.baseCost * c.rankCostFactor ^ (math.max(rank, 1) - 1) * (1 + c.stageCostStep * (stage - 1)) + 0.5
	)
end

-- True when Peak is full: the breakthrough trial can start.
function Stages.ready(data: any, cfg: any): boolean
	Stages.ensure(data)
	return data.stage == #Stages.NAMES and data.stageProgress >= Stages.cost(cfg, data.rank or 1, data.stage)
end

-- Adds progress points (kills, Refine). Advances Stages with carry-over and stops at a full Peak.
-- Returns the points actually used.
function Stages.gain(data: any, cfg: any, points: number): number
	Stages.ensure(data)
	local used = 0
	local rank = data.rank or 1
	while points > 0 do
		local cost = Stages.cost(cfg, rank, data.stage)
		if data.stageProgress >= cost then
			if data.stage >= #Stages.NAMES then
				break
			end
			data.stage += 1
			data.stageProgress = 0
			continue
		end
		local take = math.min(cost - data.stageProgress, points)
		data.stageProgress += take
		points -= take
		used += take
		if data.stageProgress >= cost and data.stage < #Stages.NAMES then
			data.stage += 1
			data.stageProgress = 0
		end
	end
	return used
end

-- Refine: spends up to `shards` from the wallet into Stage progress. Only at a rest spot. Returns Shards spent.
function Stages.refine(data: any, cfg: any, shards: number, atRest: boolean): number
	if not atRest or shards <= 0 or type(data.wallet) ~= "table" then
		return 0
	end
	local have = data.wallet.shards
	have = if typeof(have) == "number" then have else 0
	local spent = Stages.gain(data, cfg, math.min(math.floor(shards), have))
	data.wallet.shards = have - spent
	return spent
end

export type View = { stage: number, name: string, shell: string, progress: number, ready: boolean }

function Stages.view(data: any, cfg: any): View
	Stages.ensure(data)
	local cost = Stages.cost(cfg, data.rank or 1, data.stage)
	return {
		stage = data.stage,
		name = Stages.NAMES[data.stage],
		shell = Stages.SHELL[data.stage],
		progress = math.min(1, data.stageProgress / cost),
		ready = Stages.ready(data, cfg),
	}
end

return Stages
