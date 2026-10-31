local C = require("../src/shared/CastContacts")
local function input(resource, tick, target)
	return {
		["identity matrix preserves every shard tick target and coalesces repeated callbacks"] = function()
			local s = C.new("g:1", 16, 1000, 256)
			local originals = {}
			for resource = 1, 16 do
				for tick = 1, 3 do
					for _, target in { "target:1", "target:1:2", "2:target:1", "é" } do
						local value = input(resource, tick, target)
						local result, record = C.record(s, value)
						assert(result == "stored" and record.ordinal == #originals + 1)
						table.insert(originals, { value = value, record = record })
					end
				end
			end
			for i = #originals, 1, -1 do
				local pair = originals[i]
				local changed = table.clone(pair.value)
				changed.amount, changed.at = 99, 1001
				local result, record = C.record(s, changed)
				assert(result == "duplicate" and record == pair.record and record.amount == 4)
			end
			assert(s.count == 192)
		end,

		resource = resource or 1,
		tick = tick or 1,
		targetKey = target or "target:1",
		at = 1000.5,
		position = { x = 1, y = 2, z = 3 },
		direction = { x = 0, y = 0, z = -1 },
		amount = 4,
	}
end
return {
	["immutable original per cast resource tick target with monotonic ordinal"] = function()
		local s, value = C.new("g:1", 3, 1000, 20), input()
		local result, record = C.record(s, value)
		assert(result == "stored" and record.castId == "g:1" and record.ordinal == 1)
		value.position.x, value.amount, value.at = 90, 99, 1002
		local duplicate, original = C.record(s, value)
		assert(duplicate == "duplicate" and original == record and record.position.x == 1 and record.amount == 4)
		assert(record.at == 1000.5 and s.count == 1 and s.lastAt == 1000.5)
		assert(table.isfrozen(record) and table.isfrozen(record.position) and table.isfrozen(record.direction))
		assert(not pcall(function()
			record.direction.x = 9
		end))
	end,
	["different volley shards zone ticks and targets are distinct notifications"] = function()
		local s = C.new("g:1", 3, 1000, 20)
		for i, value in { input(), input(2), input(1, 2), input(1, 1, "target:2") } do
			local result, record = C.record(s, value)
			assert(result == "stored" and record.ordinal == i)
		end
		assert(s.count == 4)
		-- Cast boundary scopes the ordinal and identity; sequence reuse in a new generation is distinct.
		local result, record = C.record(C.new("g2:1", 1, 1000, 20), input())
		assert(result == "stored" and record.castId == "g2:1" and record.ordinal == 1)
	end,
	["capacity never evicts dedupe identities or advances ordinal on dropped notification"] = function()
		local s = C.new("g:1", 1, 1000, 2)
		C.record(s, input())
		C.record(s, input(1, 2))
		for tick = 3, 100 do
			assert(C.record(s, input(1, tick)) == "full")
		end
		assert(C.record(s, input()) == "duplicate" and s.count == 2)
		local count = 0
		for _ in s.entries do
			count += 1
		end
		assert(count == 2)
	end,
	["terminal closes and clears once while delayed callbacks cannot allocate"] = function()
		local s = C.new("g:1", 1, 1000, 2)
		local _, record = C.record(s, input())
		C.close(s)
		C.close(s)
		assert(C.record(s, input(1, 2)) == "closed" and next(s.entries) == nil)
		assert(record.castId == "g:1" and record.ordinal == 1)
	end,
	["zero damage and same-time distinct contacts are valid post-effect notifications"] = function()
		local s, value = C.new("g:1", 1, 1000, 2), input()
		value.amount = 0
		assert(C.record(s, value) == "stored")
		assert(C.record(s, input(1, 1, "target:2")) == "stored")
	end,
	["invalid fields never allocate; backward new contact fails but original duplicate survives"] = function()
		local s = C.new("g:1", 1, 1000, 20)
		for field, values in
			{
				resource = { 0, 2, 0 / 0, math.huge, 1.5 },
				tick = { 0, 65536, 0 / 0, math.huge, 1.5 },
				at = { 999, 0 / 0, math.huge },
				amount = { -1, 0 / 0, math.huge },
				targetKey = { "", string.rep("a", 129) },
			}
		do
			for _, value in values do
				local invalid = input()
				invalid[field] = value
				assert(C.record(s, invalid) == "invalid" and s.count == 0)
			end
		end
		for _, field in { "position", "direction" } do
			local invalid = input()
			invalid[field].x = 0 / 0
			assert(C.record(s, invalid) == "invalid")
		end
		C.record(s, input())
		local backwards = input(1, 2)
		backwards.at = 1000.4
		assert(C.record(s, backwards) == "invalid" and s.count == 1)
		local second = input(1, 2)
		second.at = 1001
		C.record(s, second)
		assert(C.record(s, input()) == "duplicate")
	end,
	["constructor rejects unbounded lifetime resource and storage policies"] = function()
		assert(not pcall(C.new, "", 1, 1000, 2))
		assert(not pcall(C.new, string.rep("g", 71), 1, 1000, 2))
		for _, value in { 0, 17, 0 / 0, math.huge, 1.5 } do
			assert(not pcall(C.new, "g:1", value, 1000, 2))
		end
		for _, value in { 0, 65536, 0 / 0, math.huge, 1.5 } do
			assert(not pcall(C.new, "g:1", 1, 1000, value))
		end
		assert(not pcall(C.new, "g:1", 1, 0 / 0, 2))
	end,
}
