--!strict
-- Slot-selected abilities (T-036a, D-216): keys 1–7 / gamepad Y select a core slot (server `SelectSlot`). The Kith
-- in the selected slot is live: with a chain move (Rimeshard) its stance is on, so left click runs the chain and
-- Z / X / C its specials (shot 2 may cancel into one, Stance.special); without a chain (Crescent) Z / X / C fire its
-- moves and left click stays the sword light chain. The Q stance toggle is gone (D-216). A `target = "Point"` move
-- (Rime Fall) aims at the ground under the mouse. The live Kith is the player's `ActiveKith` attribute
-- (LoadoutService); bindings follow it. Fixed moves (Wind Step on R) are AbilityInput's, not this file's.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local AimDir = require(script.Parent.AimDir)
local CastRequest = require(ReplicatedStorage.Shared.CastRequest)
local Config = require(ReplicatedStorage.Shared.Config)
local FxRegistry = require(ReplicatedStorage.Shared.FxRegistry)
local Projectile = require(ReplicatedStorage.Shared.Deliveries.Projectile)
local Stance = require(ReplicatedStorage.Shared.Stance)
local Zone = require(ReplicatedStorage.Shared.Deliveries.Zone)

local CHEST = Vector3.new(0, 0.5, 0)
local SPECIAL_KEYS = { Enum.KeyCode.Z, Enum.KeyCode.X, Enum.KeyCode.C } -- Kit specials in order (Fan / Fall / Shatter)
local SLOT_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
}

export type SendCast = (moveId: string, aim: Vector3, point: Vector3?, seq: number) -> ()
export type SelectSlot = (slot: number) -> ()

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

function KithInput.start(sendCast: SendCast, selectSlot: SelectSlot, fx: FxRegistry.Registry, built: any)
	local player = Players.LocalPlayer
	local kit: Stance.Kit? = nil -- nil = the live Kith has no chain: left click is the light chain
	local cfg: Stance.Cfg? = nil
	local state = Stance.new()
	local seq = 0
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

	-- Slot keys: 1–7 select a slot; gamepad Y steps to the next one. The server validates and republishes the slot.
	for i, key in SLOT_KEYS do
		ContextActionService:BindAction(
			"SelectSlot" .. i,
			function(_, st: Enum.UserInputState, _): Enum.ContextActionResult
				if st ~= Enum.UserInputState.Begin then
					return Enum.ContextActionResult.Pass
				end
				selectSlot(i)
				return Enum.ContextActionResult.Sink
			end,
			false,
			key
		)
	end
	ContextActionService:BindAction("SelectSlotNext", function(_, st: Enum.UserInputState, _): Enum.ContextActionResult
		if st ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local n = tonumber(player:GetAttribute("SlotCount")) or 1
		local cur = tonumber(player:GetAttribute("ActiveSlot")) or 1
		selectSlot(cur % n + 1)
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonY)

	-- Left click above CombatInput's light chain: taken while the stance is on, passed through when it is off.
	ContextActionService:BindActionAtPriority(
		"KithChain",
		function(_, st: Enum.UserInputState, _): Enum.ContextActionResult
			local k, c = kit, cfg
			if st ~= Enum.UserInputState.Begin or not state.on or not k or not c then
				return Enum.ContextActionResult.Pass
			end
			local now = os.clock()
			local id = Stance.press(state, now, c, k)
			if id then
				fire(id, now)
			end
			return Enum.ContextActionResult.Sink
		end,
		true, -- on-screen button so the Needle chain works on mobile (D-212)
		Enum.ContextActionPriority.High.Value,
		Enum.UserInputType.MouseButton1,
		Enum.KeyCode.ButtonR2
	)
	ContextActionService:SetTitle("KithChain", "Needle")

	local bound: { string } = {}
	local plainMoves: { string } = {} -- moves of a live Kith without a chain (Crescent Cut on Z, D-216)
	local function bindSpecials()
		for _, name in bound do
			ContextActionService:UnbindAction(name)
		end
		table.clear(bound)
		local k, c = kit, cfg
		local ids: { string } = if k then k.specials else plainMoves
		for i, key in SPECIAL_KEYS do
			local moveId = ids[i]
			if moveId == nil then
				break
			end
			local name = "KithSpecial" .. i
			table.insert(bound, name)
			ContextActionService:BindAction(name, function(_, st: Enum.UserInputState, _): Enum.ContextActionResult
				if st ~= Enum.UserInputState.Begin then
					return Enum.ContextActionResult.Pass
				end
				local now = os.clock()
				if not k or not c or Stance.special(state, now, c, k, moveId) then
					fire(moveId, now)
				end
				return Enum.ContextActionResult.Sink
			end, true, key)
			ContextActionService:SetTitle(name, tostring(built.moves[moveId].name or moveId))
		end
	end

	-- Follow the selected slot: `ActiveKith` is the species in `ActiveSlot` (Loadout.activeKith, D-216).
	local function load()
		local kithId = player:GetAttribute("ActiveKith")
		local kith = if typeof(kithId) == "string" then built.kith[kithId] else nil
		local k = if kith then Stance.kit(kith, built.moves) else nil
		table.clear(plainMoves)
		if k then
			local chainMove = built.moves[k.chain]
			local fin = built.moves[k.finisher]
			kit = k
			cfg = { chain = chainMove.chain, finisherRecovery = if fin then fin.cooldown else chainMove.chain.recovery }
		else
			kit, cfg = nil, nil
			if kith then
				for _, id in kith.moves or {} do
					if built.moves[id] and not table.find(Config.Loadout.fixedMoves, id) then
						table.insert(plainMoves, id)
					end
				end
			end
		end
		Stance.set(state, k ~= nil) -- the server mirrors this from the same attribute (Abilities, D-216)
		bindSpecials()
	end
	player:GetAttributeChangedSignal("ActiveKith"):Connect(load)
	load()
end

return KithInput
