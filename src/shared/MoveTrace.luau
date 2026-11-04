--!strict
-- MoveTrace (T-059b, D-466): pure per-tick movement recorder for the plan's test criteria (`.ai/MOVEMENT_PLAN.md` §6).
-- A ring buffer of rows (input press/release + consumed tick, mode, grounded, clearance, velocity, stamina,
-- air-dash charges, camera FOV) with a CSV dump and a short summary. No game services here.
local MoveTrace = {}

export type Row = {
	t: number, -- seconds since the trace started
	input: string?, -- e.g. "jump+", "q-", "slam+" (press +, release -); several joined by "|"
	consumed: string?, -- action that fired this tick (MoveRules Result)
	mode: string,
	grounded: boolean,
	clearance: number,
	vx: number,
	vy: number,
	vz: number,
	stamina: number,
	charges: number,
	fov: number,
}

export type Trace = {
	capacity: number,
	rows: { Row },
	head: number, -- index of the oldest row once full
	dropped: number,
}

MoveTrace.COLUMNS = "t,input,consumed,mode,grounded,clearance,vx,vy,vz,hspeed,stamina,charges,fov"

function MoveTrace.new(capacity: number): Trace
	assert(capacity >= 1, "capacity >= 1")
	return { capacity = capacity, rows = {}, head = 1, dropped = 0 }
end

function MoveTrace.record(tr: Trace, row: Row)
	if #tr.rows < tr.capacity then
		table.insert(tr.rows, row)
	else
		tr.rows[tr.head] = row
		tr.head = tr.head % tr.capacity + 1
		tr.dropped += 1
	end
end

-- Rows oldest → newest.
function MoveTrace.ordered(tr: Trace): { Row }
	local out = {}
	local n = #tr.rows
	for k = 0, n - 1 do
		table.insert(out, tr.rows[(tr.head - 1 + k) % n + 1])
	end
	return out
end

local function hspeed(r: Row): number
	return math.sqrt(r.vx * r.vx + r.vz * r.vz)
end

local function f2(x: number): string
	return string.format("%.2f", x)
end

function MoveTrace.line(r: Row): string
	return table.concat({
		string.format("%.3f", r.t),
		r.input or "",
		r.consumed or "",
		r.mode,
		if r.grounded then "1" else "0",
		f2(r.clearance),
		f2(r.vx),
		f2(r.vy),
		f2(r.vz),
		f2(hspeed(r)),
		f2(r.stamina),
		tostring(r.charges),
		f2(r.fov),
	}, ",")
end

-- CSV with a header row.
function MoveTrace.dump(tr: Trace): string
	local lines = { MoveTrace.COLUMNS }
	for _, r in MoveTrace.ordered(tr) do
		table.insert(lines, MoveTrace.line(r))
	end
	return table.concat(lines, "\n")
end

export type Summary = {
	rows: number,
	seconds: number,
	maxHSpeed: number,
	maxFall: number, -- largest downward speed (positive number)
	airSeconds: number,
	consumed: { [string]: number },
	dropped: number,
}

function MoveTrace.summary(tr: Trace): Summary
	local rows = MoveTrace.ordered(tr)
	local s: Summary = {
		rows = #rows,
		seconds = 0,
		maxHSpeed = 0,
		maxFall = 0,
		airSeconds = 0,
		consumed = {},
		dropped = tr.dropped,
	}
	for i, r in rows do
		s.maxHSpeed = math.max(s.maxHSpeed, hspeed(r))
		s.maxFall = math.max(s.maxFall, -r.vy)
		if r.consumed then
			s.consumed[r.consumed] = (s.consumed[r.consumed] or 0) + 1
		end
		local nxt = rows[i + 1]
		if nxt and not r.grounded then
			s.airSeconds += nxt.t - r.t
		end
	end
	if #rows > 1 then
		s.seconds = rows[#rows].t - rows[1].t
	end
	return s
end

-- One-line human summary, e.g. for the output window.
function MoveTrace.summaryLine(tr: Trace): string
	local s = MoveTrace.summary(tr)
	local names = {}
	for k in s.consumed do
		table.insert(names, k)
	end
	table.sort(names)
	local parts = {}
	for _, k in names do
		table.insert(parts, `{k}={s.consumed[k]}`)
	end
	return `[MoveTrace] rows={s.rows} s={f2(s.seconds)} maxH={f2(s.maxHSpeed)} maxFall={f2(s.maxFall)} air={f2(
		s.airSeconds
	)} dropped={s.dropped} {table.concat(parts, " ")}`
end

return MoveTrace
