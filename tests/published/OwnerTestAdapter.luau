--!strict
-- Test-only transport/lifecycle seam; NOT yet wired into the generated candidate.
-- deps.run must cooperate via check(), own unconditional independent cleanup, and
-- return a report table, completion, cleanup only AFTER cleanup. cancelWorker must be non-yielding, idempotent stop(true).
local Adapter = {}
function Adapter.start(policy: any, deps: any): any
	local state = policy.new(deps.owner, deps.clock())
	local subscriptions: { any } = {}
	local stopped, stopSent, stopFailed, ready = false, false, false, false
	local function stopWorker()
		if stopSent then
			return
		end
		stopSent = true
		local ok = pcall(deps.cancelWorker)
		stopFailed = not ok
	end
	local function tick(): boolean
		if stopped then
			return false
		end
		local ok, valid = pcall(deps.valid)
		if policy.tick(state, deps.clock(), ok and valid == true) then
			stopWorker()
		end
		return state.phase == "running"
	end
	local function stop()
		if stopped then
			return
		end
		stopped = true
		if policy.cancel(state, "adapter stopped") then
			stopWorker()
		end
		for i = #subscriptions, 1, -1 do
			pcall(function()
				subscriptions[i]:Disconnect()
			end)
		end
		table.clear(subscriptions)
	end
	local function work(token: number)
		-- Deferred work may have been cancelled before it started.
		local ok, payload, completed, cleanup = pcall(function()
			assert(tick(), "run cancelled before worker start")
			return deps.run(function()
				assert(tick(), "test session cancelled")
			end, function(value)
				policy.progress(state, token, value)
			end)
		end)
		if not ok then
			policy.cancel(state, "worker failed")
			stopWorker()
			-- Deliberately not a canonical evidence report; never invent cleanup success.
			payload, completed, cleanup = { error = "worker failed" }, false, false
		end
		tick()
		cleanup = cleanup == true and not stopFailed
		completed = completed == true and not state.cancelled
		local encodedOk, encoded = pcall(function()
			assert(type(payload) == "table", "worker must return a report table")
			local report = table.clone(payload)
			report.runCompleted, report.cleanup, report.dynamicsAccepted = completed, cleanup, false
			report.matrixPassed = report.matrixPassed == true and completed and cleanup
			if state.reason then
				report.error = state.reason
			end
			return deps.encode(report)
		end)
		if not encodedOk then
			encoded, completed, cleanup = '{"error":"report encoding failed","dynamicsAccepted":false}', false, false
		end
		policy.finish(state, token, encoded, completed, cleanup)
	end
	local function request(actor, action, page, ...)
		if stopped or not ready or actor ~= deps.owner or select("#", ...) ~= 0 then
			return
		end
		tick()
		local response, token = policy.request(state, actor, action, page)
		if token then
			local ok = pcall(deps.spawn, function()
				work(token)
			end)
			if not ok then
				policy.cancel(state, "worker scheduling failed")
				stopWorker()
				policy.finish(state, token, '{"error":"scheduling failed","dynamicsAccepted":false}', false, false)
			end
		end
		if response then
			pcall(deps.send, actor, response)
		end
	end
	local ok, err = pcall(function()
		table.insert(subscriptions, deps.onRequest(request))
		table.insert(subscriptions, deps.onHeartbeat(tick))
		-- Events must signal leave/extra joins even if the player list has not updated.
		table.insert(
			subscriptions,
			deps.onInvalidated(function()
				if policy.cancel(state, "player membership changed") then
					stopWorker()
				end
			end)
		)
	end)
	if not ok then
		stop()
		error(err, 0)
	end
	ready = true
	return { stop = stop }
end
return Adapter
