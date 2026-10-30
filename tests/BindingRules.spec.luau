local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local All = require("../src/shared/Content/All")
local Binding = require("../src/shared/Binding")
local BindingRules = require("../src/shared/BindingRules")

local built = Registry.build(All.content(Config))

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function profile(): any
	return {
		kith = { ["starter.crescent"] = { uid = "starter.crescent", speciesId = "kith.crescent" } },
		wallet = { shards = 2 },
	}
end

return {
	["bind rules: only a weakened wild Kith in range can be bound"] = function()
		local c = Config.Binding
		eq(BindingRules.canStart(Config, built, "kith.stone", 20, 100, 5), true, "weak, near")
		eq(select(2, BindingRules.canStart(Config, built, "kith.stone", 100, 100, 5)), "not weakened", "healthy")
		eq(select(2, BindingRules.canStart(Config, built, "kith.stone", 20, 100, c.range + 1)), "too far", "far")
		eq(select(2, BindingRules.canStart(Config, built, "kith.nope", 20, 100, 5)), "not a wild Kith", "unknown")
		eq(select(2, BindingRules.canStart(Config, built, nil, 20, 100, 5)), "not a wild Kith", "no attribute")
		eq(select(2, BindingRules.canStart(Config, built, "kith.stone", 0, 100, 5)), "gone", "dead")
	end,
	["bind rules: first bind is guided and becomes the Heart Kith"] = function()
		local data = profile()
		eq(BindingRules.guided(data), true, "guided before")
		eq(BindingRules.start(Config, data, 3, 100).guided, true, "duel guided")
		local uid, heart = BindingRules.grant(data, "kith.stone")
		eq(heart, true, "heart")
		eq(data.heartKith, uid, "heartKith set")
		eq(data.kith[uid].speciesId, "kith.stone", "owned")
		eq(BindingRules.guided(data), false, "not guided after")
		eq(BindingRules.start(Config, data, 3, 100).guided, false, "later duel not guided")
	end,
	["bind rules: later binds get unique uids and keep the Heart Kith"] = function()
		local data = profile()
		local first = BindingRules.grant(data, "kith.stone")
		local second, heart = BindingRules.grant(data, "kith.stone")
		eq(heart, false, "not heart")
		eq(second ~= first, true, "unique uid")
		eq(data.heartKith, first, "heart unchanged")
	end,
	["bind rules: Shards are spent from the wallet with a cooldown"] = function()
		local data = profile()
		local d = BindingRules.start(Config, data, 1, 0)
		eq(BindingRules.useShard(d, Config, data, 100), true, "first shard")
		eq(data.wallet.shards, 1, "spent")
		eq(d.qi, Config.Binding.shardQi, "qi refilled")
		eq(BindingRules.useShard(d, Config, data, 100), false, "cooldown")
		eq(data.wallet.shards, 1, "not spent on cooldown")
		Binding.step(d, Config, Config.Binding.shardCooldown, false)
		eq(BindingRules.useShard(d, Config, data, 100), true, "after cooldown")
		eq(data.wallet.shards, 0, "empty")
		Binding.step(d, Config, Config.Binding.shardCooldown, false)
		eq(BindingRules.useShard(d, Config, data, 100), false, "no shards")
	end,
}
