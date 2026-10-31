--!strict
-- Pure layout for the Rimeshard visuals (T-027e, D-197): shard spreads and Rime Fall drop points.
-- No services, so it is tested under Lune. The client (`client/RimeFx`) turns these into parts.

local RimeFxPlan = {}

RimeFxPlan.MAX_SHARDS = 12 -- per cast (ROADMAP note §6)

-- Yaw angles (degrees) for `count` shards spread evenly over `spreadDeg`, centred on 0; capped at MAX_SHARDS.
function RimeFxPlan.spread(count: number, spreadDeg: number): { number }
	local n = math.clamp(math.floor(count), 0, RimeFxPlan.MAX_SHARDS)
	local out: { number } = {}
	if n == 1 then
		return { 0 }
	end
	for i = 0, n - 1 do
		table.insert(out, -spreadDeg / 2 + spreadDeg * i / (n - 1))
	end
	return out
end

-- The spread minus the shard closest to the centre line (the travel effect already flies that one).
function RimeFxPlan.extras(count: number, spreadDeg: number): { number }
	local all = RimeFxPlan.spread(count, spreadDeg)
	local best, bestAbs = nil, math.huge
	for i, a in all do
		if math.abs(a) < bestAbs then
			best, bestAbs = i, math.abs(a)
		end
	end
	if best then
		table.remove(all, best)
	end
	return all
end

-- Rime Fall drop offsets: the centre plus `count - 1` points on a ring at 0.6 × radius (capped).
function RimeFxPlan.rain(count: number, radius: number): { { x: number, z: number } }
	local n = math.clamp(math.floor(count), 0, RimeFxPlan.MAX_SHARDS)
	local out: { { x: number, z: number } } = {}
	if n == 0 then
		return out
	end
	table.insert(out, { x = 0, z = 0 })
	for i = 1, n - 1 do
		local a = 2 * math.pi * i / (n - 1)
		table.insert(out, { x = math.cos(a) * radius * 0.6, z = math.sin(a) * radius * 0.6 })
	end
	return out
end

-- T-027i polish (D-198..D-201). Hit-pause length per hit kind, in frames at `fps` (default 60).
RimeFxPlan.HIT_PAUSE_FRAMES = { needle = 2, shatter = 3 }

function RimeFxPlan.hitPauseSeconds(kind: string, fps: number?): number
	local frames = RimeFxPlan.HIT_PAUSE_FRAMES[kind] or 0
	return frames / (fps or 60)
end

-- Frost veins for Shatter: indices of `dists` (caster→Chilled target distances) within `radius`,
-- nearest first, at most `maxCount`.
function RimeFxPlan.veins(dists: { number }, radius: number, maxCount: number): { number }
	local idx: { number } = {}
	for i, d in dists do
		if d <= radius then
			table.insert(idx, i)
		end
	end
	table.sort(idx, function(a, b)
		return dists[a] < dists[b]
	end)
	while #idx > math.max(0, math.floor(maxCount)) do
		table.remove(idx)
	end
	return idx
end

return RimeFxPlan
