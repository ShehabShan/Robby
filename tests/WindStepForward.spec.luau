local W = require("../src/shared/WindStep")
local p = assert(W.profile(W.PROPOSED))
local function near(a, b)
	assert(math.abs(a - b) < 1e-8, `{a} != {b}`)
end
return {
	["prospective partitions reach fourteen including partial final frame"] = function()
		for _, hz in { 30, 60, 144 } do
			local sum = 0
			local dt = 1 / hz
			for i = 0, math.ceil(p.duration / dt) - 1 do
				local d, v, finish = W.forward(p, i * dt, dt, nil)
				near(v * dt, d)
				assert(v <= p.peak + 1e-8)
				sum += d
				assert(finish == (i == math.ceil(p.duration / dt) - 1))
			end
			near(sum, 14)
		end
	end,
	["last partial divides by full dt not remaining duration"] = function()
		local d, v, finish = W.forward(p, 0.23, 0.03, nil)
		near(d, 0.04375)
		near(v, 0.04375 / 0.03)
		assert(finish)
	end,
	["hitch invalid and expired yield stop without catch up"] = function()
		for _, r in
			{
				{ 0, 0.051 },
				{ 0.24, 0.01 },
				{ 0.5, 0.01 },
				{ -1, 0.01 },
				{ 0, -1 },
				{ 0, 0 },
				{ 0, 0 / 0 },
				{
					math.huge,
					0.01,
				},
			}
		do
			local d, v, finish = W.forward(p, r[1], r[2], nil)
			near(d, 0)
			near(v, 0)
			assert(finish)
		end
	end,
	["collision caps upcoming step with skin"] = function()
		local d, v, finish = W.forward(p, 0, 0.02, 1)
		near(d, 0.85)
		near(v, 42.5)
		assert(finish)
		d, v, finish = W.forward(p, 0, 0.02, 10)
		near(d, 1.4)
		near(v, 70)
		assert(not finish)
	end,
	["initial overlap and malformed clearance stop"] = function()
		for _, c in { 0, 0.1, -1, 0 / 0, math.huge } do
			local d, v, finish = W.forward(p, 0, 0.02, c)
			near(d, 0)
			near(v, 0)
			assert(finish)
		end
	end,
	["late starting frame only plans future remaining travel"] = function()
		local d, v, finish = W.forward(p, 0.2, 0.02, nil)
		near(d, 0.525)
		near(v, 26.25)
		assert(not finish)
	end,
}
