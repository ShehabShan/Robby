--!strict
-- Burst delivery (T-027b, D-175): instant selection of marked targets within `radius` of the caster (Shatter hits only
-- Chilled targets). Pure: the caller passes candidate positions and a mark count per target.

local Burst = {}

export type Params = { radius: number, maxTargets: number }
export type Candidate = { id: string, x: number, z: number, marks: number }

function Burst.validParams(p: any): boolean
	return type(p) == "table"
		and type(p.radius) == "number"
		and p.radius > 0
		and type(p.maxTargets) == "number"
		and p.maxTargets >= 1
end

-- Marked candidates inside the radius, nearest first, capped at maxTargets. Unmarked targets are never hit.
function Burst.select(cx: number, cz: number, candidates: { Candidate }, params: Params): { Candidate }
	local r2 = params.radius * params.radius
	local picked: { { c: Candidate, d2: number } } = {}
	for _, c in candidates do
		if c.marks > 0 then
			local dx, dz = c.x - cx, c.z - cz
			local d2 = dx * dx + dz * dz
			if d2 <= r2 then
				table.insert(picked, { c = c, d2 = d2 })
			end
		end
	end
	table.sort(picked, function(a, b)
		return a.d2 < b.d2
	end)
	local out = {}
	for i = 1, math.min(#picked, params.maxTargets) do
		table.insert(out, picked[i].c)
	end
	return out
end

return Burst
