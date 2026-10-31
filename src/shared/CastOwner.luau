--!strict
-- Ordered exclusive ownership. Each start must unwind its OWN failed acquisition;
-- this controller can release only owners that successfully returned a stop callback.
local Owner = {}
export type Stop = () -> ()
export type Start = () -> Stop
export type Controller = { start: () -> Stop }
function Owner.new(starts: { Start }, report: (any) -> ()): Controller
	local steps = table.clone(starts)
	local active: Stop? = nil
	local starting = false
	local function start(): Stop
		if active then
			return active
		end
		assert(not starting, "recursive owner start")
		starting = true
		local stops: { Stop } = {}
		local closed = false
		local cleanup: Stop
		cleanup = function()
			if closed then
				return
			end
			closed = true
			-- Keep the old token installed until all consumers are stopped; reentrant
			-- start cannot open a new producer halfway through old teardown.
			for i = #stops, 1, -1 do
				local ok, err = pcall(function(): any
					stops[i]()
					return nil
				end)
				if not ok then
					pcall(report, err)
				end
			end
			table.clear(stops)
			if active == cleanup then
				active = nil
			end
		end
		local ok, err = pcall(function()
			for _, acquire in steps do
				local stop = acquire()
				assert(type(stop) == "function", "owner must return cleanup")
				table.insert(stops, stop)
			end
		end)
		if not ok then
			cleanup()
			starting = false
			error(err, 0)
		end
		starting = false
		active = cleanup
		return cleanup
	end
	return { start = start }
end
return Owner
