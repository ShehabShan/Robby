local CastRequest = require("../src/shared/CastRequest")
return {
	["shared allocation wraps u16 without collisions before rollover"] = function()
		local nextSeq = CastRequest.allocator()
		for i = 1, 65537 do
			assert(nextSeq() == i % 65536)
		end
	end,
	["connection allocators are independent"] = function()
		local a, b = CastRequest.allocator(), CastRequest.allocator()
		assert(a() == 1 and a() == 2 and b() == 1 and a() == 3)
	end,
}
