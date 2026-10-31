local I = require("../src/shared/CastCharacterIdentity")
local function value()
	return { generation = "scope:2", characterKey = "original:key", casterUserId = 42, slotRevision = 4 }
end
return {
	["atomic codec roundtrips bounded identities and freezes copies"] = function()
		for _, v in
			{
				value(),
				{
					generation = string.rep("g", 64),
					characterKey = string.rep("k", 64),
					casterUserId = 9007199254740991,
					slotRevision = 4294967295,
				},
				{ generation = "0", characterKey = "1", casterUserId = 0, slotRevision = 0 },
			}
		do
			local encoded = assert(I.encode(v))
			local decoded = assert(I.decode(encoded))
			assert(I.matches(v, decoded) and table.isfrozen(decoded) and decoded ~= v)
		end
	end,
	["codec rejects malformed oversized noncanonical and truncated replicas"] = function()
		local raw = assert(I.encode(value()))
		for _, bad in
			{
				"",
				"x",
				"0:",
				"65:" .. string.rep("x", 65),
				string.rep("x", 193),
				"07:" .. raw:sub(3),
				raw .. ":junk",
				raw:sub(1, -2),
				"1:g1:k1.0:0",
				"1:g1:k1:4294967296",
				"1:g1:k9007199254740992:0",
				"1:g1:k-1:0",
			}
		do
			assert(I.decode(bad) == nil, bad)
		end
		assert(I.decode(nil) == nil and I.decode({}) == nil and I.decode(1) == nil)
	end,
	["identity validation refuses invalid scalar fields"] = function()
		for _, field in { "generation", "characterKey" } do
			for _, bad in { "", string.rep("x", 65), 42, false } do
				local v = value()
				v[field] = bad
				assert(not I.valid(v) and not I.encode(v))
			end
		end
		for _, field in { "casterUserId", "slotRevision" } do
			for _, bad in { -1, 0.5, math.huge, -math.huge, 0 / 0, "42", false } do
				local v = value()
				v[field] = bad
				assert(not I.valid(v) and not I.encode(v))
			end
		end
	end,
	["each identity component must match independently"] = function()
		for field, bad in { generation = "new", characterKey = "new", casterUserId = 43, slotRevision = 5 } do
			local v = value()
			v[field] = bad
			assert(not I.matches(value(), v))
		end
		assert(not I.matches(value(), {}))
	end,
}
