--!strict
-- Prepared only: no live caller until atomic acceptance/input cutover (D-311).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Motion = require(ReplicatedStorage.Shared.WindStep)
local Driver = {}
export type Lease = { commit: (number) -> boolean, stop: (boolean?) -> (), active: () -> boolean }
local leases: { [Player]: Lease } = {}
local function finite(n: number): boolean
	return n == n and math.abs(n) < math.huge
end

-- Bounds are fixed for this lease. Huge/custom roots are rejected, not costly queries.
-- Spatial overlap excludes Terrain; conservative solid voxel refusal closes that hole.
-- This can refuse near rough terrain: live activation must validate terrain usability.
local function occupied(root: BasePart, size: Vector3, overlap: OverlapParams): boolean
	if #workspace:GetPartBoundsInBox(root.CFrame, size, overlap) > 0 then
		return true
	end
	local cf = root.CFrame
	local x, y, z = cf.RightVector, cf.UpVector, cf.LookVector
	local half = Vector3.new(
		math.abs(x.X) * size.X + math.abs(y.X) * size.Y + math.abs(z.X) * size.Z,
		math.abs(x.Y) * size.X + math.abs(y.Y) * size.Y + math.abs(z.Y) * size.Z,
		math.abs(x.Z) * size.X + math.abs(y.Z) * size.Y + math.abs(z.Z) * size.Z
	) / 2
	local region = Region3.new(cf.Position - half, cf.Position + half):ExpandToGrid(4)
	local materials, occupancy = workspace.Terrain:ReadVoxels(region, 4)
	for ix, plane in occupancy do
		for iy, row in plane do
			for iz, amount in row do
				if amount > 0 and materials[ix][iy][iz] ~= Enum.Material.Water then
					return true
				end
			end
		end
	end
	return false
end

-- Non-yielding resource reservation. No force, velocity or ownership writes before commit.
-- Caller must stop a reservation if payment fails; commit must be part of rollback-capable
-- server acceptance. Do not pay/grant iframes from this module.
function Driver.prepare(player: Player, raw: any, direction: Vector3): Lease?
	if leases[player] then
		return nil
	end
	local profile = Motion.profile(raw)
	if not profile or not finite(direction.Y) or math.abs(direction.Y) > 0.001 then
		return nil
	end
	local dx, dz, validDirection = Motion.direction(direction.X, direction.Z, 0, 0)
	if not validDirection then
		return nil
	end
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		return nil
	end
	local assembly = root.AssemblyRootPart
	local size, collisionGroup, mass = root.Size, root.CollisionGroup, root.AssemblyMass
	if not assembly or size.X < 0.5 or size.Y < 0.5 or size.Z < 0.5 or size.X > 4 or size.Y > 4 or size.Z > 4 then
		return nil
	end
	local function original(): boolean
		return root:IsDescendantOf(workspace) and root.AssemblyRootPart == assembly
	end
	local function eligible(): boolean
		return player.Parent == Players
			and player.Character == character
			and character:FindFirstChild("HumanoidRootPart") == root
			and character:FindFirstChildOfClass("Humanoid") == humanoid
			and original()
			and root.Size == size
			and root.CollisionGroup == collisionGroup
			and root.AssemblyMass == mass
			and Motion.eligible(humanoid.Health, root.Anchored, humanoid.Sit, humanoid:GetState().Name)
	end
	local attachment: Attachment? = nil
	local force: LinearVelocity? = nil
	local connections: { RBXScriptConnection } = {}
	local closed, committed, owned, automatic = false, false, false, false
	local previousOwner: Player? = nil
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	overlap.RespectCanCollide = true
	overlap.MaxParts = 1
	overlap.CollisionGroup = root.CollisionGroup
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { character }
	ray.RespectCanCollide = true
	ray.IgnoreWater = true
	ray.CollisionGroup = root.CollisionGroup
	local preparedAt = workspace:GetServerTimeNow()
	local started, covered, lastClock = 0, 0, 0
	local pending, finishAfter, applied, pendingSpeed = false, false, 0, 0
	local axis = Vector3.new(dx, 0, dz)
	local lease: Lease
	local function stop(keepVelocity: boolean?)
		if closed then
			return
		end
		closed = true
		leases[player] = nil
		for _, connection in connections do
			pcall(function()
				connection:Disconnect()
			end)
		end
		-- Disable separately: a failing Destroy must not leave an active actuator.
		if force then
			pcall(function()
				(force :: LinearVelocity).Enabled = false
			end)
			pcall(function()
				(force :: LinearVelocity):Destroy()
			end)
		end
		if attachment then
			pcall(function()
				(attachment :: Attachment):Destroy()
			end)
		end
		pcall(function()
			if
				applied > 0
				and not keepVelocity
				and original()
				and not root:GetNetworkOwnershipAuto()
				and root:GetNetworkOwner() == nil
			then
				local velocity = root.AssemblyLinearVelocity
				-- Remove only positive dash-axis contribution; retain Y, perpendicular
				-- and additive excess/reverse knockback. Explicit stop(true) before a
				-- replacement-velocity knockback; never restore a stale start velocity.
				root.AssemblyLinearVelocity = velocity - axis * math.clamp(velocity:Dot(axis), 0, applied)
			end
		end)
		pcall(function()
			if
				owned
				and original()
				and root:CanSetNetworkOwnership()
				and not root:GetNetworkOwnershipAuto()
				and root:GetNetworkOwner() == nil
			then
				if automatic or (previousOwner and previousOwner.Parent ~= Players) then
					root:SetNetworkOwnershipAuto()
				else
					root:SetNetworkOwner(previousOwner)
				end
			end
		end)
	end
	local function before(dt: number)
		if closed then
			return
		end
		local ok = pcall(function()
			local now = workspace:GetServerTimeNow()
			if not committed then
				if not finite(now) or now < preparedAt or now - preparedAt > profile.maxFrame or not eligible() then
					stop()
				end
				return
			end
			if
				pending
				or not eligible()
				or root:GetNetworkOwnershipAuto()
				or root:GetNetworkOwner() ~= nil
				or (force :: LinearVelocity).Parent ~= root
				or (attachment :: Attachment).Parent ~= root
				or not finite(now)
				or now < lastClock
				or now - lastClock > profile.maxFrame
			then
				stop()
				return
			end
			lastClock = now
			-- Never re-spend an interval if server time stalls; never catch up when
			-- wall time runs ahead. Single-use Pre/Post pairing owns simulation time.
			local elapsed = math.max(covered, now - started)
			local distance, _, terminal = Motion.forward(profile, elapsed, dt, nil)
			if distance <= 0 or occupied(root, size, overlap) then
				stop()
				return
			end
			local hit = workspace:Blockcast(root.CFrame, size, axis * (distance + profile.skin), ray)
			local clearance = if hit then hit.Distance else nil
			local allowed, speed, blocked = Motion.forward(profile, elapsed, dt, clearance)
			if allowed <= 0 then
				stop()
				return
			end
			local actuator = force :: LinearVelocity
			actuator.PlaneVelocity = Vector2.new(dx * speed, dz * speed)
			actuator.Enabled = true
			pendingSpeed, pending, finishAfter = speed, true, terminal or blocked
			covered = elapsed + dt
		end)
		if not ok then
			stop()
		end
	end
	local function after()
		if closed or not committed or not pending then
			return
		end
		pending = false
		applied = pendingSpeed -- only completed simulation may contribute residual dash velocity
		local ok = pcall(function()
			(force :: LinearVelocity).Enabled = false
			if finishAfter or not eligible() then
				stop()
			end
		end)
		if not ok then
			stop()
		end
	end
	lease = {
		stop = stop,
		active = function()
			return committed and not closed
		end,
		commit = function(acceptedAt: number): boolean
			if closed or committed then
				return false
			end
			local ok, accepted = pcall(function()
				local now = workspace:GetServerTimeNow()
				if
					not finite(acceptedAt)
					or not finite(now)
					or acceptedAt > now
					or now - acceptedAt > profile.maxFrame
					or now < preparedAt
					or now - preparedAt > profile.maxFrame
				then
					return false
				end
				if
					not eligible()
					or not root:CanSetNetworkOwnership()
					or occupied(root, size, overlap)
					or (force :: LinearVelocity).Parent ~= root
					or (attachment :: Attachment).Parent ~= root
				then
					return false
				end
				automatic, previousOwner = root:GetNetworkOwnershipAuto(), root:GetNetworkOwner()
				owned = true -- also attempt restore if acquisition throws after side effect
				root:SetNetworkOwner(nil)
				started, lastClock = acceptedAt, now
				committed = true
				return true
			end)
			if not ok or not accepted then
				stop()
				return false
			end
			return true
		end,
	}
	leases[player] = lease
	local ok = pcall(function()
		if not eligible() or not root:CanSetNetworkOwnership() or occupied(root, size, overlap) then
			error("ineligible Wind Step root")
		end
		if not finite(mass) or mass <= 0 or mass > 1000 then
			error("unsupported Wind Step mass")
		end
		attachment = Instance.new("Attachment")
		local a = attachment :: Attachment
		a.Name = "WindStepAttachment"
		a.Parent = root
		force = Instance.new("LinearVelocity")
		local v = force :: LinearVelocity
		v.Name = "WindStepVelocity"
		v.Enabled = false
		v.Attachment0 = a
		v.RelativeTo = Enum.ActuatorRelativeTo.World
		v.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		v.PrimaryTangentAxis = Vector3.xAxis
		v.SecondaryTangentAxis = Vector3.zAxis
		v.ForceLimitsEnabled = true
		v.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		v.MaxPlanarAxesForce = Vector2.new(mass * 6000, mass * 6000)
		v.PlaneVelocity = Vector2.zero
		v.Parent = root
		table.insert(connections, RunService.PreSimulation:Connect(before))
		table.insert(connections, RunService.PostSimulation:Connect(after))
		table.insert(
			connections,
			humanoid.Died:Connect(function()
				stop()
			end)
		)
		table.insert(
			connections,
			player.CharacterRemoving:Connect(function(removing: Model)
				if removing == character then
					stop()
				end
			end)
		)
		table.insert(
			connections,
			root.AncestryChanged:Connect(function()
				if not root:IsDescendantOf(workspace) then
					stop()
				end
			end)
		)
	end)
	if not ok then
		stop()
		return nil
	end
	return lease
end
return Driver
