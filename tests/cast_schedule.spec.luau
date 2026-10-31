local Schedule = require("../src/shared/CastSchedule")
local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local All = require("../src/shared/Content/All")
local built = Registry.build(All.content(Config))
local function offsets(id)
	return assert(Schedule.offsets(built.moves[id], built.effects, Config.CastReceipt.maxLifetimeSeconds))
end
return {
	["current fan and finisher release immediately, not declared fan warning"] = function()
		local fan, fin = offsets("move.rime.shard_fan"), offsets("move.rime.needle_finisher")
		assert(fan.release == 0 and math.abs(fan.finish - 0.35) < 1e-9)
		assert(fin.release == 0 and fin.finish == 45 / 120)
	end,
	["zone uses four real beats, burst warning and self effect duration"] = function()
		local zone, burst, wind = offsets("move.rime.fall"), offsets("move.rime.shatter"), offsets("move.wind_step")
		assert(zone.release == 0.6 and zone.finish == 1.6)
		assert(burst.release == Config.Abilities.Rimeshard.shatter.telegraph and burst.finish == burst.release)
		assert(wind.release == 0 and wind.finish == Config.Abilities.WindStep.iframes)
	end,
	["every registry and woven projectile schedule fits bounded policy"] = function()
		for _, move in built.moves do
			assert(Schedule.offsets(move, built.effects, Config.CastReceipt.maxLifetimeSeconds), move.id)
		end
		-- Snapshot a woven delivery's actual range; never a lookup of base move timing.
		local move = table.clone(built.moves["move.rime.needle"])
		move.delivery = { kind = "Projectile", params = table.clone(move.delivery.params) }
		move.delivery.params.range *= 1.25
		local s = assert(Schedule.offsets(move, built.effects, 10))
		assert(s.finish == move.delivery.params.range / move.delivery.params.speed)
	end,
	["invalid schedules cannot reach payment"] = function()
		for _, pair in { { 0, 1 }, { 0 / 0, 1 }, { 1, math.huge }, { 1, 100 } } do
			assert(
				Schedule.offsets(
					{ delivery = { kind = "Projectile", params = { speed = pair[1], range = pair[2] } } },
					{},
					10
				) == nil
			)
		end
		assert(Schedule.offsets({ delivery = { kind = "Unknown", params = {} } }, {}, 10) == nil)
	end,
}
