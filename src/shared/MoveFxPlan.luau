--!strict
-- Movement VFX plan (T-058i, D-440; reference: owner movement video, research/notes/R-031-movement-video.md).
-- Pure: decides WHEN cosmetic movement effects fire. The client (MoveFxClient) builds the parts/particles.

export type Tuning = {
	dustMinSpeed: number, -- studs/s; footstep dust only when running faster than this
	streakMinSpeed: number, -- studs/s; ambient speed streaks only when this fast
	streakEveryMin: number, -- seconds between speed streaks (random in [min, max])
	streakEveryMax: number,
}

export type DashEvent = "start" | "arcs" | "finish"

local MoveFxPlan = {}

-- Footstep dust on a footfall: only on the ground and only while running.
function MoveFxPlan.dustOnStep(t: Tuning, speed: number, floorMaterialName: string): boolean
	return floorMaterialName ~= "Air" and speed >= t.dustMinSpeed
end

-- Seconds until the next ambient speed streak; r in [0, 1).
function MoveFxPlan.streakDelay(t: Tuning, r: number): number
	return t.streakEveryMin + math.clamp(r, 0, 1) * (t.streakEveryMax - t.streakEveryMin)
end

function MoveFxPlan.streaksOn(t: Tuning, speed: number, sprinting: boolean): boolean
	return sprinting and speed >= t.streakMinSpeed
end

-- Dash attribute change → effects. Start: dust ring (+ wind arcs on side dodge). End: smoke puff.
function MoveFxPlan.dashEvents(prev: string?, now: string?): { DashEvent }
	local out: { DashEvent } = {}
	if now ~= nil and now ~= prev then
		table.insert(out, "start")
		if now == "side" then
			table.insert(out, "arcs")
		end
	elseif now == nil and prev ~= nil then
		table.insert(out, "finish")
	end
	return out
end

return MoveFxPlan
