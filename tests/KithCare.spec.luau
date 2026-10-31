local Config = require("../src/shared/Config")
local KithCare = require("../src/shared/KithCare")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function kith(): any
	local k = { uid = "a", speciesId = "kith.stone" }
	KithCare.ensure(k, Config)
	return k
end

local U = Config.Upkeep

return {
	["dev: devAlwaysReady refills a Kith to Ready (T-040, D-227)"] = function()
		local k = kith()
		k.satiety, k.strain, k.dormant, k.exhaustedUntil = 0, U.strainMax, true, 1e9
		local on = table.clone(Config)
		on.Upkeep = table.clone(U)
		on.Upkeep.devAlwaysReady = true
		eq(KithCare.devRefill(k, on), true, "on")
		eq(KithCare.state(k, on, 10), "Ready", "ready")
		eq(k.satiety, U.satietyMax, "full")
		eq(k.strain, 0, "no strain")
		local off = table.clone(on)
		off.Upkeep = table.clone(on.Upkeep)
		off.Upkeep.devAlwaysReady = false
		k.satiety = 5
		eq(KithCare.devRefill(k, off), false, "off")
		eq(k.satiety, 5, "untouched when off")
	end,
	["kith care: old saves get full satiety and no strain"] = function()
		local k = kith()
		eq(k.satiety, U.satietyMax, "satiety")
		eq(k.strain, 0, "strain")
		eq(KithCare.state(k, Config, 0), "Ready", "ready")
	end,
	["kith care: higher ranks eat less, fighting eats more"] = function()
		eq(KithCare.drainRate(Config, 2, false) < KithCare.drainRate(Config, 1, false), true, "rank")
		eq(KithCare.drainRate(Config, 1, true) > KithCare.drainRate(Config, 1, false), true, "fight")
	end,
	["kith care: hungry is weaker, starved goes Dormant and needs a rare meal"] = function()
		local k = kith()
		k.satiety = U.hungryAt - 1
		eq(KithCare.state(k, Config, 0), "Hungry", "hungry")
		eq(KithCare.power(k, Config, 0), U.hungryPower, "weaker")
		eq(KithCare.usable(k, Config, 0), true, "still usable")
		KithCare.drain(k, Config, 1, 1e6, true)
		eq(k.dormant, true, "dormant")
		eq(KithCare.usable(k, Config, 0), false, "dormant unusable")
		eq(KithCare.power(k, Config, 0), 0, "no power")
		eq(KithCare.feed(k, Config, "common"), false, "common meal refused")
		eq(KithCare.feed(k, Config, "rare"), true, "rare meal wakes")
		eq(KithCare.state(k, Config, 0), "Ready", "awake")
		eq(k.speciesId, "kith.stone", "never lost")
	end,
	["kith care: full Strain exhausts for a while, then recovers"] = function()
		local k = kith()
		eq(KithCare.addStrain(k, Config, U.strainMax / 2, 0), false, "half")
		KithCare.recover(k, Config, 1, 1)
		eq(k.strain, U.strainMax / 2 - U.strainDecayPerSecond, "decays")
		eq(KithCare.addStrain(k, Config, U.strainMax, 1), true, "exhausted")
		eq(KithCare.state(k, Config, 2), "Exhausted", "state")
		eq(KithCare.usable(k, Config, 2), false, "unusable")
		eq(KithCare.addStrain(k, Config, 10, 2), false, "no more strain while exhausted")
		KithCare.recover(k, Config, 1, 1 + U.exhaustSeconds - 1)
		eq(KithCare.state(k, Config, 1 + U.exhaustSeconds - 1), "Exhausted", "still exhausted")
		KithCare.recover(k, Config, 1, 1 + U.exhaustSeconds)
		eq(KithCare.state(k, Config, 1 + U.exhaustSeconds), "Ready", "recovered")
		eq(k.strain, 0, "strain reset")
	end,
	["kith care: dormant Kith stop draining, feeding caps at max"] = function()
		local k = kith()
		eq(KithCare.feed(k, Config, "common"), true, "fed")
		eq(k.satiety, U.satietyMax, "capped")
		eq(KithCare.feed(k, Config, "cake"), false, "unknown meal")
		k.dormant = true
		k.satiety = 0
		KithCare.drain(k, Config, 1, 10, false)
		eq(k.satiety, 0, "no drain below 0")
	end,
}
