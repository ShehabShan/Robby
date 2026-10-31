local Owner = require("../src/shared/CastOwner")
local function fixture(failStart, failStop)
	local log, errors, steps = {}, {}, {}
	for i = 1, 3 do
		table.insert(steps, function()
			table.insert(log, "start" .. i)
			if i == failStart then
				error("acquire" .. i)
			end
			return function()
				table.insert(log, "stop" .. i)
				if i == failStop then
					error("cleanup" .. i)
				end
			end
		end)
	end
	local c = Owner.new(steps, function(e)
		table.insert(errors, e)
	end)
	return c, log, errors
end
return {
	["producer first consumers next reverse cleanup exactly once"] = function()
		local c, log = fixture()
		local stop = c.start()
		assert(c.start() == stop)
		stop()
		stop()
		assert(table.concat(log, ",") == "start1,start2,start3,stop3,stop2,stop1")
	end,
	["every acquisition failure unwinds only already acquired owners"] = function()
		for i = 1, 3 do
			local c, log = fixture(i)
			assert(not pcall(c.start))
			assert(#log == i + i - 1)
			for n = 1, i - 1 do
				assert(log[i + n] == "stop" .. (i - n))
			end
		end
	end,
	["cleanup exceptions never prevent producer teardown"] = function()
		for i = 1, 3 do
			local c, log, errors = fixture(nil, i)
			c.start()()
			assert(#log == 6 and log[6] == "stop1" and #errors == 1)
		end
	end,
	["old stop cannot tear down a restarted owner"] = function()
		local c, log = fixture()
		local old = c.start()
		old()
		local fresh = c.start()
		assert(old ~= fresh)
		old()
		assert(#log == 9 and c.start() == fresh)
		fresh()
		assert(#log == 12)
	end,
	["failed acquisition can retry and reporting failures are isolated"] = function()
		local fail = true
		local cleaned = 0
		local c = Owner.new({
			function()
				return function()
					cleaned += 1
					error("stop")
				end
			end,
			function()
				if fail then
					error("start")
				end
				return function() end
			end,
		}, function()
			error("report")
		end)
		assert(not pcall(c.start) and cleaned == 1)
		fail = false
		c.start()()
		assert(cleaned == 2)
	end,
	["reentrant starts never create overlapping owner sets"] = function()
		local c
		local stop
		local starts = 0
		c = Owner.new({
			function()
				starts += 1
				assert(not pcall(function()
					c.start()
				end))
				return function()
					assert(c.start() == stop)
				end
			end,
		}, function() end)
		stop = c.start()
		stop()
		assert(starts == 1)
	end,
	["caller mutation cannot change the captured acquisition list"] = function()
		local acquired = 0
		local steps = {
			function()
				acquired += 1
				return function() end
			end,
		}
		local c = Owner.new(steps, function() end)
		table.clear(steps)
		c.start()()
		assert(acquired == 1)
	end,
}
