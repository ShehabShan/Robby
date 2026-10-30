--!strict
-- Kith stance input (T-027d3, D-190): Q / gamepad B toggles the Kith stance (`Shared.Stance`). Stance on: left click
-- fires the active Kith's chain move and the third press its finisher (Rimeshard Needle); off: left click falls
-- through to CombatInput's light chain. Z / X / C fire the Kith's specials in both stances, and shot 2 of the chain
-- may cancel into one (Stance.special). A `target = "Point"` move (Rime Fall) aims at the ground under the mouse,
-- clamped to its range. FX play at once; the server runs the same machine and verifies every CastRequest.
-- The active Kith is Rimeshard until the loadout publishes one (Resume note in TASKS.md).

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AimDir = require(script.Parent.AimDir)
local CastRequest = require(ReplicatedStorage.Shared.CastRequest)
local FxRegistry = require(ReplicatedStorage.Shared.FxRegistry)
local Projectile = require(ReplicatedStorage.Shared.Deliveries.Projectile)
local Stance = require(ReplicatedStorage.Shared.Stance)
local Zone = require(ReplicatedStorage.Shared.Deliveries.Zone)

local CHEST = Vector3.new(0, 0.5, 0)
local SPECIAL_KEYS = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C } -- Kit specials in order (Fan / Fall / Shatter)

export type SendCast = (moveId: string, aim: Vector3, point: Vector3?, seq: number) -> ()
export type SendAction = (kind: string, dir: Vector3?, seq: number) -> ()

local KithInput = {}

local function flatLook(camera: Camera): Vector3?
	local look = AimDir.look(camera)
	local x, z, ok = Projectile.flatten(look.X, look.Z)
	return if ok then Vector3.new(x, 0, z) else nil
end

-- Ground point under the mouse (the screen centre under shift lock), clamped to the Zone's range from the caster.
local function groundPoint(camera: Camera, character: Model, root: BasePart, params: any): Vector3
	local m = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(m.X, m.Y)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, rp)
	local p = if hit then hit.Position else ray.Origin + ray.Direction * params.range
	local rx, rz = root.Position.X, root.Position.Z
	if not Zone.isValidPoint(rx, rz, p.X, p.Z, params) then
		local dx, dz = p.X - rx, p.Z - rz
		local d = math.sqrt(dx * dx + dz * dz)
		local s = if d > 0 then (params.range * 0.98) / d else 0
		p = Vector3.new(rx + dx * s, if hit then p.Y else root.Position.Y - 3, rz + dz * s)
	end
	return p
end

function KithInput.start(
	sendCast: SendCast,
	sendAction: SendAction,
	fx: FxRegistry.Registry,
	built: any,
	kithId: string
)
	local kith = built.kith[kithId]
	local kit = if kith then Stance.kit(kith, built.moves) else nil
	if not kit then
		warn("KithInput: " .. kithId .. " has no chain move")
		return
	end
	local chainMove = built.moves[kit.chain]
	local fin = built.moves[kit.finisher]
	local cfg: Stance.Cfg = {
		chain = chainMove.chain,
		finisherRecovery = if fin then fin.cooldown else chainMove.chain.recovery,
	}
	local player = Players.LocalPlayer
	local state = Stance.new()
	local seq = 0
	local actionSeq = 0
	local lastCast: { [string]: number } = {}

	local function ready(): (Model?, BasePart?, Camera?)
		local character = player.Character
		local camera = workspace.CurrentCamera
		if not character or not camera then
			return nil, nil, nil
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			return nil, nil, nil
		end
		return character, root, camera
	end

	local function fire(moveId: string, now: number): boolean
		local move = built.moves[moveId]
		local character, root, camera = ready()
		if not move or not character or not root or not camera then
			return false
		end
		local last = lastCast[moveId]
		if last and now - last < move.cooldown then
			return false
		end
		local qi = player:GetAttribute("Qi")
		if typeof(qi) == "number" and qi < (move.costs.qi or 0) then
			return false
		end
		local dir = flatLook(camera) or root.CFrame.LookVector
		local point: Vector3? = nil
		local pos = root.Position + dir * (move.delivery.params.spawnOffset or 0) + CHEST
		if move.target == "Point" then
			point = groundPoint(camera, character, root, move.delivery.params)
			pos = point :: Vector3
		end
		lastCast[moveId] = now
		seq = CastRequest.nextSeq(seq)
		local ctx = { caster = player, character = character, pos = pos, dir = dir, point = point }
		FxRegistry.play(fx, move.fx.cast, ctx)
		if move.fx.travel then
			FxRegistry.play(fx, move.fx.travel, ctx)
		end
		sendCast(move.id, dir, point, seq)
		return true
	end

	ContextActionService:BindAction("KithStance", function(_, st: Enum.UserInputState, _): Enum.ContextActionResult
		if st ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		Stance.toggle(state)
		actionSeq = (actionSeq + 1) % 65536
		sendAction("Stance", nil, actionSeq)
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle("KithStance", "Stance")

	-- Left click above CombatInput's light chain: taken while the stance is on, passed through when it is off.
	ContextActionService:BindActionAtPriority(
		"KithChain",
		function(_, st: Enum.UserInputState, _): Enum.ContextActionResult
			if st ~= Enum.UserInputState.Begin or not state.on then
				return Enum.ContextActionResult.Pass
			end
			local now = os.clock()
			local id = Stance.press(state, now, cfg, kit)
			if id then
				fire(id, now)
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.ButtonR2
	)

	for i, key in SPECIAL_KEYS do
		local moveId = kit.specials[i]
		if moveId == nil then
			break
		end
		local name = "KithSpecial" .. i
		ContextActionService:BindAction(name, function(_, st: Enum.UserInputState, _): Enum.ContextActionResult
			if st ~= Enum.UserInputState.Begin then
				return Enum.ContextActionResult.Pass
			end
			local now = os.clock()
			if Stance.special(state, now, cfg, kit, moveId) then
				fire(moveId, now)
			end
			return Enum.ContextActionResult.Sink
		end, true, key)
		ContextActionService:SetTitle(name, tostring(built.moves[moveId].name or moveId))
	end
end

return KithInput
