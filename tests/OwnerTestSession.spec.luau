local S = require("../src/shared/OwnerTestSession")
local function setup()
	local owner = {}
	return S.new(owner, 0), owner
end
local function request(state, owner, now, action, page)
	S.tick(state, now, true)
	return S.request(state, owner, action, page)
end
return {
	owner_identity_and_malformed_input = function()
		local s, owner = setup()
		assert(S.request(s, {}, "start") == nil)
		assert(S.request(s, owner, {}, {}) == nil)
		assert(s.phase == "idle")
		assert(request(s, owner, 0.21, "start", 1) == nil)
		assert(s.phase == "idle")
		local _, token = request(s, owner, 0.42, "start")
		assert(token == 1 and s.phase == "running")
	end,
	one_start_rate_limit_and_immutable_terminal = function()
		local s, owner = setup()
		local _, token = S.request(s, owner, "start")
		assert(token == 1 and S.request(s, owner, "status") == nil)
		assert(request(s, owner, 0.21, "start") == nil)
		assert(not S.finish(s, 2, "{}", true, true))
		assert(S.finish(s, 1, "{}", true, true))
		assert(s.phase == "complete")
		assert(not S.finish(s, 1, "overwrite", false, false))
		assert(not S.cancel(s, "late") and s.report == "{}")
		assert(request(s, owner, 0.42, "start") == nil)
		assert(S.status(s).dynamicsAccepted == false)
	end,
	invalid_environment_and_idle_deadline_close = function()
		for _, mode in { "membership", "timeout", "nan", "backward", "infinity" } do
			local s, owner = setup()
			local now = if mode == "timeout"
				then 120
				else if mode == "nan"
					then 0 / 0
					else if mode == "backward" then -1 else if mode == "infinity" then math.huge else 0
			assert(not S.tick(s, now, mode ~= "membership"))
			assert(s.phase == "closed" and s.cancelled)
			assert(request(s, owner, 121, "start") == nil)
		end
	end,
	running_cancellation_once_and_cleanup_before_report = function()
		for _, mode in { "timeout", "membership", "backward" } do
			local s, owner = setup()
			S.request(s, owner, "start")
			local now = if mode == "timeout" then 600 else if mode == "backward" then -1 else 0
			assert(S.tick(s, now, mode ~= "membership"))
			assert(s.phase == "cancelling" and S.status(s).pages == 0)
			assert(not S.tick(s, 601, false))
			assert(not S.cancel(s, "second"))
			assert(S.finish(s, 1, "failure", true, true))
			assert(s.phase == "failed" and s.report == "failure")
		end
	end,
	completion_and_cleanup_are_separate = function()
		for _, pair in { { true, false }, { false, true }, { false, false } } do
			local s, owner = setup()
			S.request(s, owner, "start")
			assert(S.finish(s, 1, "partial", pair[1], pair[2]))
			assert(s.phase == "failed" and s.cleanup == pair[2])
		end
	end,
	bounded_report_full_byte_roundtrip_and_no_cross_owner_leak = function()
		local s, owner = setup()
		S.request(s, owner, "start")
		local payload = string.rep("a", 11999) .. "☃" .. string.rep("x", S.maxBytes - 12002)
		assert(#payload == S.maxBytes and S.finish(s, 1, payload, true, true))
		local chunks, now = {}, 0
		for page = 1, S.status(s).pages do
			now += 0.21
			local response = request(s, owner, now, "report", page)
			assert(#response.data <= S.pageBytes and response.bytes == #payload)
			table.insert(chunks, response.data)
		end
		assert(table.concat(chunks) == payload)
		assert(request(s, {}, now + 1, "report", 1) == nil)
		for _, page in { 0, -1, 0.5, 0 / 0, math.huge, 1000, "1", {} } do
			now += 2
			assert(request(s, owner, now, "report", page) == nil)
		end
	end,
	empty_oversized_nonstring_reports_fail_closed = function()
		for _, payload in { "", string.rep("x", S.maxBytes + 1), {}, false } do
			local s, owner = setup()
			S.request(s, owner, "start")
			assert(not S.finish(s, 1, payload, true, true))
			assert(s.phase == "failed" and S.status(s).pages == 0)
		end
	end,
	progress_monotone_bounded_and_token_bound = function()
		local s, owner = setup()
		S.progress(s, 0, 30)
		assert(s.progress == 0)
		S.request(s, owner, "start")
		S.progress(s, 1, 40)
		for _, n in { 39, 107, -1, 2.5, 0 / 0, math.huge } do
			S.progress(s, 1, n)
		end
		S.progress(s, 2, 100)
		assert(s.progress == 40)
		S.progress(s, 1, 106)
		assert(s.progress == 106)
		S.cancel(s, "cancelled")
		S.progress(s, 1, 20)
		assert(s.progress == 106)
	end,
	turnovers_are_independent = function()
		for _ = 1, 100 do
			local s, owner = setup()
			S.request(s, owner, "start")
			S.finish(s, 1, "{}", true, true)
			assert(s.phase == "complete")
		end
	end,
}
