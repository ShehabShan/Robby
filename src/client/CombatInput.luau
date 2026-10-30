--!strict
-- Combat input (T-013b, GDD §5 controls): light chain (LMB / RT), parry+guard (F / LB: press parries and
-- raises the guard, release lowers it). Sends intent only; the server decides.
-- No dash (T-028, D-189): Shift sprints, Wind Step is the dodge; Q is reserved for the Kith stance (T-027d3).

local ContextActionService = game:GetService("ContextActionService")
local AimDir = require(script.Parent.AimDir)

export type Send = (kind: string, dir: Vector3?, seq: number) -> ()

local CombatInput = {}

function CombatInput.start(send: Send)
	local seq = 0

	local function nextSeq(): number
		seq = (seq + 1) % 65536
		return seq
	end

	local function aim(): Vector3?
		local camera = workspace.CurrentCamera
		if not camera then
			return nil
		end
		local look = AimDir.look(camera)
		local flat = Vector3.new(look.X, 0, look.Z)
		return if flat.Magnitude > 0.01 then flat.Unit else nil
	end

	ContextActionService:BindAction("CombatAttack", function(_, state: Enum.UserInputState, _): Enum.ContextActionResult
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		send("Attack", aim(), nextSeq())
		return Enum.ContextActionResult.Sink
	end, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)

	ContextActionService:BindAction("CombatParry", function(_, state: Enum.UserInputState, _): Enum.ContextActionResult
		if state == Enum.UserInputState.Begin then
			send("Parry", nil, nextSeq())
			return Enum.ContextActionResult.Sink
		elseif state == Enum.UserInputState.End then
			send("Guard", nil, nextSeq())
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonL1)
end

return CombatInput
