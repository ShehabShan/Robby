--!strict
-- T-051a play-mode gate (TEST place only, D-373). Pure: no services, no instances.
-- The server owns cooldown and rate limits; client payload is only a direction hint.
local WindStep = require("./WindStep")

local WindStepPlay = {}

WindStepPlay.COOLDOWN = 1.2 -- seconds between accepted dashes (play-test default)
WindStepPlay.BURST = 4 -- max requests (accepted or not) per window
WindStepPlay.WINDOW = 1 -- seconds

export type Gate = { cooldown: number, readyAt: { [number]: number }, hits: { [number]: { number } } }

local function finite(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end

function WindStepPlay.new(cooldown: number?): Gate
	local c = if finite(cooldown) and (cooldown :: number) >= 0 then cooldown :: number else WindStepPlay.COOLDOWN
	return { cooldown = c, readyAt = {}, hits = {} }
end

-- Returns ok, dx, dz, reason. On ok the cooldown is started; call refund() if the dash then fails to start.
function WindStepPlay.request(
	g: Gate,
	id: number,
	now: number,
	mx: any,
	mz: any,
	fx: any,
	fz: any
): (boolean, number, number, string?)
	if not finite(now) then
		return false, 0, 0, "time"
	end
	local list = g.hits[id] or {}
	g.hits[id] = list
	while #list > 0 and now - list[1] >= WindStepPlay.WINDOW do
		table.remove(list, 1)
	end
	if #list >= WindStepPlay.BURST then
		return false, 0, 0, "rate"
	end
	table.insert(list, now)
	if now < (g.readyAt[id] or -math.huge) then
		return false, 0, 0, "cooldown"
	end
	if not (finite(mx) and finite(mz) and finite(fx) and finite(fz)) then
		return false, 0, 0, "payload"
	end
	local dx, dz, ok = WindStep.direction(mx, mz, fx, fz)
	if not ok then
		return false, 0, 0, "direction"
	end
	g.readyAt[id] = now + g.cooldown
	return true, dx, dz, nil
end

function WindStepPlay.refund(g: Gate, id: number)
	g.readyAt[id] = nil
end

function WindStepPlay.remaining(g: Gate, id: number, now: number): number
	return math.max(0, (g.readyAt[id] or 0) - now)
end

function WindStepPlay.forget(g: Gate, id: number)
	g.readyAt[id] = nil
	g.hits[id] = nil
end

return WindStepPlay
