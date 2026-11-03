--!strict
local Vault = require("../src/shared/Vault")
local Config = require("../src/shared/Config")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local C: Vault.Cfg = Config.Vault

local function probe(d: number?, h: number?, head: boolean?, room: boolean?): Vault.Probe
	return { faceDist = d, topHeight = h, headBlocked = head == true, roomAbove = room ~= false }
end

return {
	["classify: low wall in reach is a vault"] = function()
		eq(Vault.classify(C, probe(1.5, 3)), "vault", "3 studs")
		eq(Vault.classify(C, probe(1.5, C.vaultMin)), "vault", "min edge")
	end,
	["classify: taller ledge is a climb"] = function()
		eq(Vault.classify(C, probe(1.5, (C.vaultMax + C.climbMax) / 2)), "climb", "ledge")
	end,
	["classify: normal jump otherwise"] = function()
		eq(Vault.classify(C, probe(nil, 3)), nil, "nothing ahead")
		eq(Vault.classify(C, probe(C.reach + 1, 3)), nil, "too far")
		eq(Vault.classify(C, probe(1, C.vaultMin - 0.5)), nil, "step, just walk")
		eq(Vault.classify(C, probe(1, C.climbMax + 1)), nil, "too tall")
		eq(Vault.classify(C, probe(1, 3, true)), nil, "head blocked")
		eq(Vault.classify(C, probe(1, 3, false, false)), nil, "no room")
		eq(Vault.classify(C, probe(1, 0 / 0)), nil, "nan")
	end,
	["launch: clears the top and keeps run speed on vaults"] = function()
		local up, fwd = Vault.launch(C, "vault", 3, 24)
		eq(up * up / (2 * C.gravity) >= 3, true, "apex above top")
		eq(fwd, 24, "keeps speed")
		local _, slow = Vault.launch(C, "vault", 3, 5)
		eq(slow, C.vaultForward, "min forward")
		local _, cf = Vault.launch(C, "climb", 6, 24)
		eq(cf, C.climbForward, "climb forward")
	end,
	["launch: forward speed stays inside the speed guard"] = function()
		local _, fwd = Vault.launch(C, "vault", 3, Config.Movement.sprintMax)
		eq(fwd <= Config.Movement.sprintMax, true, "no extra planar speed")
	end,
}
