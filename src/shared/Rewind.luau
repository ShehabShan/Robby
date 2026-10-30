--!strict
-- Server rewind buffer (SCHEMAS §9, D-050, T-013a): a short history of one entity's positions.
-- The server records at 20 Hz for 1 s and checks melee hits at `now − min(ping estimate, 250 ms)`;
-- client timestamps are never used. Generic over the stored value; `lerp` is injected (Vector3:Lerp
-- on the server), so the module stays pure and Lune-testable.

export type Sample = { t: number, v: any }
export type Buffer = { seconds: number, samples: { Sample } }

local Rewind = {}

Rewind.MAX_LOOKBACK = 0.25

function Rewind.new(seconds: number): Buffer
	return { seconds = seconds, samples = {} }
end

-- Appends a sample (times must not go backwards; older ones are dropped) and trims to the window.
function Rewind.record(buf: Buffer, t: number, v: any)
	local s = buf.samples
	local last = s[#s]
	if last and t < last.t then
		return
	end
	table.insert(s, { t = t, v = v })
	while #s > 1 and s[1].t < t - buf.seconds do
		table.remove(s, 1)
	end
end

-- The time to check a hit at: now − ping, with ping clamped to [0, MAX_LOOKBACK].
function Rewind.checkTime(now: number, ping: number, cap: number?): number
	local limit = cap or Rewind.MAX_LOOKBACK
	if ping ~= ping then
		ping = limit
	end
	return now - math.clamp(ping, 0, limit)
end

-- Value at time t: clamped to the oldest/newest sample, interpolated with `lerp` when given,
-- otherwise the older neighbour. nil when the buffer is empty.
function Rewind.at(buf: Buffer, t: number, lerp: ((a: any, b: any, alpha: number) -> any)?): any
	local s = buf.samples
	local n = #s
	if n == 0 then
		return nil
	end
	if t <= s[1].t then
		return s[1].v
	end
	if t >= s[n].t then
		return s[n].v
	end
	for i = 1, n - 1 do
		local a, b = s[i], s[i + 1]
		if t >= a.t and t < b.t then
			if lerp and b.t > a.t then
				return lerp(a.v, b.v, (t - a.t) / (b.t - a.t))
			end
			return a.v
		end
	end
	return s[n].v
end

return Rewind
