local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local All = require("../src/shared/Content/All")
local Refining = require("../src/shared/Refining")
local Stages = require("../src/shared/Stages")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local built, errors = Registry.build(All.content(Config))

local function profile(slots: { string }): any
	return {
		rank = 1,
		wallet = { shards = 30 },
		kith = { a = { speciesId = "kith.crescent" }, b = { speciesId = "kith.lotus" } },
		loadout = { slots = slots, weaves = {} },
	}
end

return {
	["refining: Mist Lotus validates and mirrors Config"] = function()
		eq(#errors, 0, "registry errors: " .. table.concat(errors, "; "))
		eq(built.kith["kith.lotus"].passive.refineYield, Config.Refining.lotusYield, "yield")
	end,
	["refining: bonus only while the Lotus is equipped"] = function()
		eq(Refining.multiplier(profile({ "a", "", "" }), Config, built), 1, "no lotus")
		eq(Refining.multiplier(profile({ "a", "b", "" }), Config, built), 1 + Config.Refining.lotusYield, "lotus")
		eq(Refining.multiplier({}, Config, built), 1, "empty profile")
	end,
	["refining: Shards buy more Stage progress with the bonus"] = function()
		local data = profile({ "b", "", "" })
		local m = Refining.multiplier(data, Config, built)
		local spent = Stages.refine(data, Config, 20, true, m)
		eq(spent, 20, "spent")
		eq(data.wallet.shards, 10, "wallet")
		eq(data.stageProgress, math.floor(20 * m), "progress")
	end,
	["refining: no bonus keeps 1:1 and never overspends"] = function()
		local data = profile({ "", "", "" })
		eq(Stages.refine(data, Config, 100, true, 1), 30, "all owned")
		eq(data.wallet.shards, 0, "empty wallet")
		eq(Stages.refine(data, Config, 5, false, 2), 0, "not at rest")
	end,
}
