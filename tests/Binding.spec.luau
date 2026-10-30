local Config = require("../src/shared/Config")
local Binding = require("../src/shared/Binding")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function run(d: any, seconds: number, channel: boolean): any
	for _ = 1, math.floor(seconds * 10) do
		Binding.step(d, Config, 0.1, channel)
	end
	return d
end

return {
	["binding: channelling a weak Kith binds it"] = function()
		local d = run(Binding.new(Config, 1, 100), 20, true)
		eq(d.result, "bound", "bound")
	end,
	["binding: not channelling makes it flee"] = function()
		local d = run(Binding.new(Config, 1, 100), 20, false)
		eq(d.result, "fled", "fled")
	end,
	["binding: higher Will is slower"] = function()
		local weak = run(Binding.new(Config, 1, 1000), 2, true)
		local strong = run(Binding.new(Config, 10, 1000), 2, true)
		eq(weak.progress > strong.progress, true, "will slows progress")
	end,
	["binding: no Qi means no progress"] = function()
		local d = run(Binding.new(Config, 1, 0), 1, true)
		eq(d.progress < Config.Binding.start, true, "slides back without Qi")
	end,
	["binding: Shard refills Qi with a cooldown"] = function()
		local d = Binding.new(Config, 1, 0)
		eq(Binding.useShard(d, Config, 1, 100), true, "first shard")
		eq(d.qi, math.min(100, Config.Binding.shardQi), "refilled")
		eq(Binding.useShard(d, Config, 1, 100), false, "cooldown")
		eq(Binding.useShard(Binding.new(Config, 1, 0), Config, 0, 100), false, "no shards")
	end,
	["binding: guided bind cannot fail"] = function()
		local d = run(Binding.new(Config, 5, 0, true), Config.Binding.timeLimit + 5, false)
		eq(d.result, nil, "never flees")
		eq(d.progress >= Config.Binding.guidedFloor, true, "floor")
		run(d, 30, true)
		eq(d.result, nil, "no qi, still running")
		for _ = 1, 10 do
			Binding.useShard(d, Config, 1, 100)
			run(d, 3, true)
		end
		eq(d.result, "bound", "guided bind completes with Qi")
	end,
}
