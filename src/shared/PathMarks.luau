--!strict
-- Path Marks (T-020b, D-089): Marks are earned by landing hits with a Path's moves. They boost that Path's moves
-- (`DamageMath.marksBoost`, soft-capped) and cause Friction on opposed Paths (`Loom.friction`, floored at −20 %). Pure.

local DamageMath = require("./DamageMath")
local Loom = require("./Loom")

local PathMarks = {}

-- "Path.Moon" tag → "path.moon"; nil when the move has no Path tag.
function PathMarks.pathOf(move: any): string?
	for _, t in (move and move.tags) or {} do
		local p = string.match(t, "^Path%.(%a+)$")
		if p then
			return "path." .. string.lower(p)
		end
	end
	return nil
end

-- Adds Marks for `hits` damaging hits with a move of `path`; returns the new total.
function PathMarks.award(data: any, cfg: any, path: string?, hits: number): number
	if not path or hits <= 0 then
		return 0
	end
	data.marks = data.marks or {}
	local v = math.min(cfg.Marks.max, (data.marks[path] or 0) + cfg.Marks.perHit * hits)
	data.marks[path] = v
	return v
end

-- Damage mods for a move of `path`: boost from own Marks, Friction from opposed Marks.
function PathMarks.hitMods(cfg: any, marks: { [string]: number }?, path: string?): (number, number)
	if not path then
		return 0, 0
	end
	local own = (marks and marks[path]) or 0
	return DamageMath.marksBoost(own), Loom.friction(cfg, path, marks)
end

return PathMarks
