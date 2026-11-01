--!strict
-- Pure bounded reader for the single original owner channel; no gameplay authority.
local Client = {}
local MAX, PAGE = 524288, 12000
export type State = {
	phase: string,
	progress: number,
	reason: string?,
	bytes: number,
	pages: number,
	nextAt: number,
	deadline: number,
	lastNow: number,
	start: boolean,
	started: boolean,
	pending: number?,
	attempts: number,
	chunks: { string },
	report: string?,
	failed: boolean,
}
local function integer(n: any, low: number, high: number): boolean
	return type(n) == "number" and n == n and n % 1 == 0 and n >= low and n <= high
end
local function fail(s: State, why: string)
	s.failed, s.reason = true, why
	table.clear(s.chunks)
end
function Client.new(now: number): State
	return {
		phase = "connecting",
		progress = 0,
		bytes = 0,
		pages = 0,
		nextAt = now,
		deadline = now + 750,
		lastNow = now,
		start = false,
		started = false,
		attempts = 0,
		chunks = {},
		failed = false,
	}
end
function Client.start(s: State): boolean
	if s.failed or s.phase ~= "idle" or s.started then
		return false
	end
	s.start, s.started = true, true
	return true
end
function Client.next(s: State, now: number): (string?, number?)
	if type(now) ~= "number" or now ~= now or now < s.lastNow or now >= s.deadline then
		fail(s, "Reader expired; keep any copied report and rejoin a fresh test server.")
	end
	s.lastNow = now
	if s.failed or s.report or now < s.nextAt then
		return nil, nil
	end
	s.nextAt = now + 1 -- below server rate cap; no burst retry or automatic start
	if s.start then
		s.start = false
		return "start", nil
	end
	if s.pages > 0 then
		local page = #s.chunks + 1
		if s.pending ~= page then
			s.pending, s.attempts = page, 0
		end
		s.attempts += 1
		if s.attempts > 3 then
			fail(s, "Report transfer timed out; partial JSON is not evidence.")
			return nil, nil
		end
		return "report", page
	end
	return "status", nil
end
function Client.receive(s: State, message: any)
	if s.failed or s.report or type(message) ~= "table" then
		return
	end
	if message.phase ~= nil then
		local phases = { idle = true, running = true, cancelling = true, complete = true, failed = true, closed = true }
		if
			not phases[message.phase]
			or not integer(message.progress, 0, 106)
			or not integer(message.bytes, 0, MAX)
			or not integer(message.pages, 0, math.ceil(MAX / PAGE))
			or message.pages ~= math.ceil(message.bytes / PAGE)
			or message.dynamicsAccepted ~= false
			or (message.reason ~= nil and (type(message.reason) ~= "string" or #message.reason > 512))
		then
			fail(s, "Invalid server status.")
			return
		end
		if s.pages > 0 then
			return
		end -- immutable report snapshot; ignore late status
		if message.progress < s.progress then
			fail(s, "Progress regressed.")
			return
		end
		s.phase, s.progress, s.reason = message.phase, message.progress, message.reason
		if s.phase ~= "idle" then
			s.started = true
		end
		if message.pages > 0 then
			if s.phase ~= "complete" and s.phase ~= "failed" then
				fail(s, "Report before cleanup.")
				return
			end
			s.bytes, s.pages = message.bytes, message.pages
		elseif s.phase == "closed" or s.phase == "failed" then
			fail(s, message.reason or "Session closed without report.")
		end
		return
	end
	if message.page ~= s.pending then
		return
	end -- stale/unrequested packets never append
	local expected = math.min(PAGE, s.bytes - (#s.chunks * PAGE))
	if
		message.pages ~= s.pages
		or message.bytes ~= s.bytes
		or type(message.data) ~= "string"
		or #message.data ~= expected
		or expected <= 0
	then
		fail(s, "Invalid report page.")
		return
	end
	table.insert(s.chunks, message.data)
	s.pending, s.attempts = nil, 0
	if #s.chunks == s.pages then
		local joined = table.concat(s.chunks)
		if #joined ~= s.bytes or utf8.len(joined) == nil then
			fail(s, "Invalid full report encoding.")
			return
		end
		s.report = joined -- JSON validation by engine adapter only after complete byte assembly
		table.clear(s.chunks)
	end
end
function Client.displayPages(report: string): { string }
	assert(#report <= MAX and utf8.len(report) ~= nil, "bounded UTF-8 report required")
	local result, start = {}, 1
	while start <= #report do
		local finish = math.min(start + 5999, #report)
		while finish < #report and string.byte(report, finish + 1) >= 128 and string.byte(report, finish + 1) < 192 do
			finish -= 1
		end
		table.insert(result, string.sub(report, start, finish))
		start = finish + 1
	end
	return result
end
return Client
