--!strict
-- Prepared NON-cast contact boundary; inactive until atomic keyed cast cutover.
-- Sword hits have no cast receipt. Never replay a keyed ability through this route.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Registry = require(ReplicatedStorage.Shared.FxRegistry)
local HitFeel = require(script.Parent.HitFeel)
local Net = require(script.Parent.Net)
local Client = {}
local stop: (() -> ())? = nil
function Client.start(fx: Registry.Registry): () -> ()
	if stop then
		return stop
	end
	local closed = false
	local disconnect: (() -> ())? = nil
	local function cleanup()
		if closed then
			return
		end
		closed = true
		if disconnect then
			local ok, problem = pcall(function(): any
				(disconnect :: () -> ())()
				return nil
			end)
			if not ok then
				pcall(warn, problem)
			end
		end
		stop = nil
	end
	stop = cleanup
	local ok, problem = pcall(function()
		disconnect = Net.HitFx.On(function(value)
			if closed or value.fxId ~= HitFeel.GENERIC_ID then
				return
			end
			Registry.play(fx, HitFeel.GENERIC_ID, {
				caster = value.caster,
				pos = value.pos,
				dir = value.dir,
				target = value.target,
				amount = value.amount,
			})
		end)
	end)
	if not ok then
		cleanup()
		error(problem, 0)
	end
	return cleanup
end
return Client
