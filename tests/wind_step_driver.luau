-- Actual production driver + pure policy, engine-shaped doubles (not a Roblox solver).
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local Motion = require("../src/shared/WindStep")
local V, V2, CF = rb.Vector3, rb.Vector2, rb.CFrame
local source = fs.readFile("src/server/WindStepDriver.luau")
local clearanceSource = fs.readFile("src/server/WindStepClearance.luau")
local function near(a, b)
	assert(math.abs(a - b) < 0.0001, `{a} != {b}`)
end
local function fixture()
	local f = {
		now = 100,
		stage = 0,
		fail = 0,
		resources = {},
		connections = {},
		saved = {},
		ownership = {},
		casts = {},
		boxes = {},
		failQuery = false,
	}
	local function acquire(label)
		f.stage += 1
		if f.fail == f.stage then
			error("injected " .. label)
		end
	end
	local function signal(name)
		local s = { callbacks = {} }
		function s:Connect(fn)
			acquire(name)
			local c = { live = true, fn = fn }
			function c:Disconnect()
				self.live = false
				if f.failDisconnect then
					error("disconnect")
				end
			end
			table.insert(self.callbacks, c)
			table.insert(f.connections, c)
			f.saved[name] = fn
			return c
		end
		function s:Fire(...)
			for _, c in self.callbacks do
				if c.live then
					c.fn(...)
				end
			end
		end
		return s
	end
	local players, world = {}, {}
	local player = { Parent = players, CharacterRemoving = signal("remove") }
	local humanoid = { Health = 100, Sit = false, state = "Running", Died = signal("death") }
	function humanoid:GetState()
		return { Name = self.state }
	end
	local root = {
		Size = V.new(2, 2, 1),
		CFrame = CF.new(0, 5, 0),
		CollisionGroup = "Players",
		AssemblyMass = 10,
		Anchored = false,
		AssemblyLinearVelocity = V.zero,
		auto = true,
		owner = player,
		present = true,
		AncestryChanged = signal("ancestry"),
		canOwn = true,
	}
	root.AssemblyRootPart = root
	function root:IsA(k)
		return k == "BasePart"
	end
	function root:IsDescendantOf(w)
		assert(w == world)
		return self.present
	end
	function root:CanSetNetworkOwnership()
		return self.canOwn
	end
	function root:GetNetworkOwnershipAuto()
		return self.auto
	end
	function root:GetNetworkOwner()
		return self.owner
	end
	function root:SetNetworkOwnershipAuto()
		self.auto = true
		table.insert(f.ownership, "auto")
	end
	function root:SetNetworkOwner(owner)
		self.auto, self.owner = false, owner
		table.insert(f.ownership, if owner then "player" else "server")
		if f.failOwner then
			error("owner acquisition after side effect")
		end
	end
	local character = { root = root, humanoid = humanoid }
	function character:FindFirstChild(k)
		assert(k == "HumanoidRootPart")
		return self.root
	end
	function character:FindFirstChildOfClass(k)
		assert(k == "Humanoid")
		return self.humanoid
	end
	player.Character = character
	function world:GetServerTimeNow()
		return f.now
	end
	function world:GetPartBoundsInBox(cf, size, params)
		if f.failQuery then
			error("query failed")
		end
		table.insert(f.boxes, { cf = cf, size = size, params = params })
		return if f.overlap then { root } else {}
	end
	world.Terrain = {
		ReadVoxels = function(_, region, resolution)
			assert(resolution == 4 and region.expanded)
			f.lastRegion = region
			return { Size = V.new(1, 1, 1), { { if f.water then "Water" else "Rock" } } }, {
				Size = V.new(1, 1, 1),
				{ { if f.terrain and not (f.seedClear and region.lo.Y > 8) then 0.2 else 0 } },
			}
		end,
	}
	function world:Blockcast(cf, size, direction, params)
		if params.FilterType == "Include" then
			assert(
				params.FilterDescendantsInstances[1] == self.Terrain and params.RespectCanCollide and params.IgnoreWater
			)
			assert(params.CollisionGroup == "Players" and size == root.Size)
			f.terrainSweeps = (f.terrainSweeps or 0) + 1
			assert(direction.X == 0 and direction.Z == 0 and (direction.Y == -8 or direction.Y == -16))
			if f.failTerrainSweep then
				error("terrain sweep failed")
			end
			return if f.terrainHit then { Distance = f.terrainHit } else nil
		end
		if f.failCast then
			error("sweep failed")
		end
		table.insert(f.casts, { cf = cf, size = size, direction = direction, params = params })
		return if f.clearance then { Distance = f.clearance } else nil
	end
	local run = { PreSimulation = signal("pre"), PostSimulation = signal("post") }
	local services = { Players = players, RunService = run, ReplicatedStorage = { Shared = { WindStep = "motion" } } }
	local enum = {
		Material = { Water = "Water" },
		RaycastFilterType = { Exclude = "Exclude", Include = "Include" },
		ActuatorRelativeTo = { World = "World" },
		VelocityConstraintMode = { Plane = "Plane" },
		ForceLimitMode = { PerAxis = "PerAxis" },
	}
	local function instance(kind)
		acquire(kind)
		local values = { kind = kind }
		local obj = setmetatable({}, {
			__index = values,
			__newindex = function(_, key, value)
				if key ~= "Destroy" and key ~= "destroyed" then
					f.setStage = (f.setStage or 0) + 1
					if f.failSet == f.setStage then
						error("injected property " .. key)
					end
				end
				values[key] = value
			end,
		})
		function obj:Destroy()
			self.destroyed, self.Parent = true, nil
			if f.failDestroy then
				error("destroy")
			end
		end
		table.insert(f.resources, obj)
		if kind == "LinearVelocity" then
			f.force = obj
		else
			f.attachment = obj
		end
		return obj
	end
	local environment = {
		game = {
			GetService = function(_, name)
				return assert(services[name])
			end,
		},
		workspace = world,
		script = { Parent = { WindStepClearance = "clearance" } },
		Instance = { new = instance },
		Enum = enum,
		Vector3 = V,
		Vector2 = V2,
		OverlapParams = {
			new = function()
				return {}
			end,
		},
		RaycastParams = {
			new = function()
				return {}
			end,
		},
		Region3 = {
			new = function(lo, hi)
				return {
					lo = lo,
					hi = hi,
					ExpandToGrid = function(self, n)
						assert(n == 4)
						self.expanded = true
						return self
					end,
				}
			end,
		},
	}
	local clearance = luau.load(clearanceSource, { injectGlobals = true, environment = environment })()
	environment.require = function(name)
		if name == "clearance" then
			return clearance
		end
		assert(name == "motion")
		return Motion
	end
	local driver = luau.load(source, { injectGlobals = true, environment = environment })()
	f.player, f.root, f.humanoid, f.character, f.run, f.driver = player, root, humanoid, character, run, driver
	function f:prepare()
		return self.driver.prepare(player, Motion.PROPOSED, V.xAxis)
	end
	function f:start()
		local lease = assert(self:prepare(), "prepare failed")
		assert(lease.commit(self.now), "commit failed")
		self.lease = lease
		return lease
	end
	function f:tick(dt, clockDt)
		run.PreSimulation:Fire(dt)
		if self.force and self.force.Enabled then
			-- Ideal target velocity integration only: not real friction, acceleration or collision.
			local v = self.force.PlaneVelocity
			root.AssemblyLinearVelocity = V.new(v.X, root.AssemblyLinearVelocity.Y, v.Y)
			root.CFrame += V.new(v.X * dt, 0, v.Y * dt)
		end
		self.now += clockDt or dt
		run.PostSimulation:Fire(dt)
	end
	function f:clean()
		for _, x in self.resources do
			assert(x.destroyed, "resource leaked: " .. x.kind)
		end
		for _, c in self.connections do
			assert(not c.live, "listener leaked")
		end
	end
	return f
end
local cases = {
	["unordered sibling observation reproduces zero commands despite movement"] = function()
		local f = fixture()
		local sampled = 0
		-- This listener runs before the driver, a legal order the old harness assumed away.
		local observer = f.run.PreSimulation:Connect(function(dt)
			if f.force and f.force.Enabled then
				sampled += f.force.PlaneVelocity.X * dt
			end
		end)
		local l = f:start()
		for _ = 1, 12 do
			if l.active() then
				f:tick(0.02)
			end
		end
		assert(sampled == 0 and f.root.CFrame.X > 10, "ordering failure not reproduced")
		observer:Disconnect()
		l.stop()
		f:clean()
	end,
	["phase observer errors release resources and original ownership"] = function()
		for _, failPhase in { "pre", "post" } do
			local f = fixture()
			local l = assert(f.driver.prepare(f.player, Motion.PROPOSED, V.xAxis, function(phase)
				if phase == failPhase then
					error("injected observer failure")
				end
			end))
			assert(l.commit(f.now))
			f:tick(0.02)
			assert(not l.active() and f.root.auto)
			f:clean()
		end
	end,
	["terminal phase is observed before automatic ownership restoration"] = function()
		local f = fixture()
		local pre, post, distance = 0, 0, 0
		local l = assert(f.driver.prepare(f.player, Motion.PROPOSED, V.xAxis, function(phase, dt)
			assert(not f.root.auto and f.root.owner == nil)
			if phase == "pre" then
				pre += 1
				distance += f.force.PlaneVelocity.X * dt
			else
				post += 1
				assert(not f.force.Enabled)
			end
		end))
		assert(l.commit(f.now))
		for _ = 1, 16 do
			if l.active() then
				f:tick(1 / 60)
			end
		end
		assert(pre == post and post > 0 and not l.active() and f.root.auto)
		near(distance, 14)
		f:clean()
	end,
	["phase observer runs at command/release seam regardless of signal ordering"] = function()
		for _, reverse in { false, true } do
			local f = fixture()
			local phases = {}
			local l = assert(f.driver.prepare(f.player, Motion.PROPOSED, V.xAxis, function(phase, dt)
				table.insert(phases, phase)
				assert(f.force.Enabled == (phase == "pre"))
				assert(not f.root.auto and f.root.owner == nil)
				if phase == "pre" then
					near(dt, 0.02)
				end
			end))
			assert(l.commit(f.now))
			-- Other listeners may run before or after the driver's callback.
			local noise = f.run.PreSimulation:Connect(function() end)
			if reverse then
				local callbacks = f.run.PreSimulation.callbacks
				callbacks[1], callbacks[2] = callbacks[2], callbacks[1]
			end
			f:tick(0.02)
			assert(table.concat(phases, ",") == "pre,post", "missing deterministic phase observation")
			noise:Disconnect()
			l.stop()
			f:clean()
		end
	end,
	["reservation is inert; one lease; two-phase commit is single use"] = function()
		local f = fixture()
		local l = assert(f:prepare())
		assert(not l.active() and not f.force.Enabled and #f.ownership == 0)
		assert(f:prepare() == nil)
		assert(l.commit(f.now) and l.active() and not l.commit(f.now))
		l.stop()
		l.stop()
		f:clean()
		assert(f.root.auto and #f.ownership == 2)
	end,
	["plane has bounded forces; Y untouched; query filters and body volume"] = function()
		local f = fixture()
		local l = f:start()
		f.root.AssemblyLinearVelocity = V.new(0, -17, 0)
		local v = f.force
		assert(
			v.VelocityConstraintMode == "Plane"
				and v.RelativeTo == "World"
				and v.ForceLimitMode == "PerAxis"
				and v.ForceLimitsEnabled
		)
		assert(v.PrimaryTangentAxis == V.xAxis and v.SecondaryTangentAxis == V.zAxis)
		assert(v.MaxPlanarAxesForce == V2.new(60000, 60000) and v.Attachment0 == f.attachment)
		f:tick(0.02)
		near(f.root.AssemblyLinearVelocity.Y, -17)
		local cast, box = f.casts[1], f.boxes[1]
		assert(cast.size == f.root.Size and box.size == f.root.Size)
		assert(
			cast.params.FilterDescendantsInstances[1] == f.character
				and cast.params.RespectCanCollide
				and cast.params.IgnoreWater
		)
		assert(box.params.MaxParts == 1 and box.params.RespectCanCollide and box.params.CollisionGroup == "Players")
		near(cast.direction.Magnitude, 1.55)
		l.stop()
		near(f.root.AssemblyLinearVelocity.Y, -17)
		f:clean()
	end,
	["30 60 144Hz ideal driver reaches 14 and releases after final simulation"] = function()
		for _, hz in { 30, 60, 144 } do
			local f = fixture()
			local l = f:start()
			for _ = 1, 50 do
				if not l.active() then
					break
				end
				f:tick(1 / hz)
			end
			near(f.root.CFrame.X, 14)
			near(f.root.AssemblyLinearVelocity.X, 0)
			assert(not l.active())
			f:clean()
		end
	end,
	["partial final frame and collision consume only their own interval"] = function()
		local f = fixture()
		local l = f:start()
		for _ = 1, 4 do
			f:tick(0.05)
		end
		f.run.PreSimulation:Fire(0.05)
		assert(l.active() and f.force.Enabled)
		near(f.force.PlaneVelocity.X, 14)
		f.run.PostSimulation:Fire(0.05)
		assert(not l.active())
		f:clean()
		f = fixture()
		l = f:start()
		f.clearance = 0.5
		f:tick(0.02)
		near(f.root.CFrame.X, 0.35)
		assert(not l.active())
		f:clean()
	end,
	["start overlap part solid terrain refused; water ignored"] = function()
		for _, field in { "overlap", "terrain" } do
			local f = fixture()
			f[field] = true
			assert(f:prepare() == nil)
			f:clean()
			assert(#f.ownership == 0)
		end
		local f = fixture()
		f.water, f.terrain = true, true
		f:start().stop()
		f:clean()
	end,
	["commit rechecks newly blocked root and ownership before taking control"] = function()
		for _, field in { "overlap", "terrain", "failQuery" } do
			local f = fixture()
			local l = assert(f:prepare())
			f[field] = true
			assert(not l.commit(f.now))
			f:clean()
			assert(#f.ownership == 0)
		end
		local f = fixture()
		local l = assert(f:prepare())
		f.root.canOwn = false
		assert(not l.commit(f.now))
		f:clean()
	end,
	["runtime query failure new overlap and skin stop without travel"] = function()
		for _, field in { "overlap", "terrain", "failQuery", "failCast", "clearance" } do
			local f = fixture()
			local l = f:start()
			f[field] = if field == "clearance" then 0.1 else true
			f:tick(0.02)
			assert(not l.active())
			near(f.root.CFrame.X, 0)
			f:clean()
		end
	end,
	["current position and orientation swept each time; moving obstacle stops"] = function()
		local f = fixture()
		local l = f:start()
		f:tick(0.02)
		f.root.CFrame = CF.new(7, 9, 3) * CF.Angles(0, 0.7, 0)
		local cf = f.root.CFrame
		f.clearance = 0.2
		f:tick(0.02)
		assert(f.casts[2].cf == cf)
		near(f.root.CFrame.X, 7.05)
		assert(not l.active())
		f:clean()
	end,
	["all acquisition failure points unwind; ownership failure after side effect"] = function()
		for i = 1, 7 do
			local f = fixture()
			f.fail = i
			assert(f:prepare() == nil, `fault {i} missed`)
			f:clean()
			assert(#f.ownership == 0)
		end
		local f = fixture()
		local l = assert(f:prepare())
		f.failOwner = true
		assert(not l.commit(f.now))
		assert(f.root.auto)
		f:clean()
	end,
	["cleanup failures isolated and stale callbacks cannot stop replacement lease"] = function()
		local f = fixture()
		local l = f:start()
		local callbacks = table.clone(f.saved)
		f.failDestroy, f.failDisconnect = true, true
		l.stop()
		f:clean()
		assert(f.root.auto)
		f.failDestroy, f.failDisconnect = false, false
		local nextLease = f:start()
		callbacks.pre(0.02)
		callbacks.post(0.02)
		callbacks.death()
		callbacks.remove(f.character)
		callbacks.ancestry()
		assert(nextLease.active())
		nextLease.stop()
		f:clean()
	end,
	["death replacement removal leave state change and detached root stop"] = function()
		local changes = {
			function(f)
				f.humanoid.Died:Fire()
			end,
			function(f)
				f.player.Character = {}
			end,
			function(f)
				f.player.CharacterRemoving:Fire(f.character)
			end,
			function(f)
				f.player.Parent = nil
			end,
			function(f)
				f.root.present = false
				f.root.AncestryChanged:Fire()
			end,
			function(f)
				f.character.root = {}
			end,
			function(f)
				f.character.humanoid = {}
			end,
			function(f)
				f.humanoid.Health = 0
			end,
			function(f)
				f.humanoid.Sit = true
			end,
			function(f)
				f.root.Anchored = true
			end,
			function(f)
				f.humanoid.state = "Swimming"
			end,
			function(f)
				f.root.Size = V.new(3, 3, 3)
			end,
		}
		for _, change in changes do
			local f = fixture()
			local l = f:start()
			change(f)
			f:tick(0.02)
			assert(not l.active())
			f:clean()
		end
	end,
	["eligibility mass and direction fail closed; supported airborne state"] = function()
		local changes = {
			function(f)
				f.humanoid.Health = 0
			end,
			function(f)
				f.root.Anchored = true
			end,
			function(f)
				f.humanoid.Sit = true
			end,
			function(f)
				f.humanoid.state = "Climbing"
			end,
			function(f)
				f.root.canOwn = false
			end,
			function(f)
				f.root.AssemblyMass = 0 / 0
			end,
			function(f)
				f.root.AssemblyMass = 1001
			end,
			function(f)
				f.root.Size = V.new(20, 2, 2)
			end,
		}
		for _, change in changes do
			local f = fixture()
			change(f)
			assert(f:prepare() == nil)
			f:clean()
		end
		local f = fixture()
		for _, d in { V.zero, V.yAxis, V.new(0 / 0, 0, 1) } do
			assert(f.driver.prepare(f.player, Motion.PROPOSED, d) == nil)
		end
		f.humanoid.state = "Freefall"
		f:start().stop()
		f:clean()
	end,
	["restore auto manual player and manual server; never restore changed assembly"] = function()
		for _, mode in { "auto", "player", "server" } do
			local f = fixture()
			f.root.auto = mode == "auto"
			f.root.owner = if mode == "server" then nil else f.player
			f:start().stop()
			f:clean()
			assert(f.ownership[2] == mode)
		end
		local f = fixture()
		local l = f:start()
		f.root.AssemblyRootPart = {}
		l.stop()
		f:clean()
		assert(#f.ownership == 1)
	end,
	["new ownership or destroyed force fails closed without stealing new owner"] = function()
		for _, change in
			{
				function(f)
					f.root.auto, f.root.owner = true, f.player
				end,
				function(f)
					f.root.owner = {}
				end,
				function(f)
					f.force.Parent = nil
				end,
				function(f)
					f.attachment.Parent = nil
				end,
			}
		do
			local f = fixture()
			local l = f:start()
			change(f)
			f:tick(0.02)
			assert(not l.active())
			f:clean()
		end
	end,
	["hitch stale reversed NaN clocks and duplicate pre never replay movement"] = function()
		for _, dt in { 0, -0.01, 0.051, math.huge, 0 / 0 } do
			local f = fixture()
			local l = f:start()
			f.run.PreSimulation:Fire(dt)
			assert(not l.active())
			f:clean()
		end
		for _, clock in { 100.06, 100.3, 99, 0 / 0 } do
			local f = fixture()
			local l = f:start()
			f.now = clock
			f:tick(0.02)
			assert(not l.active())
			f:clean()
		end
		local f = fixture()
		local l = f:start()
		f.run.PreSimulation:Fire(0.02)
		f.run.PreSimulation:Fire(0.02)
		assert(not l.active())
		f:clean()
	end,
	["clock stall cannot reuse budget; fast wall time drops unspent travel"] = function()
		local f = fixture()
		local l = f:start()
		for _ = 1, 15 do
			if not l.active() then
				break
			end
			f:tick(0.02, 0)
		end
		near(f.root.CFrame.X, 14)
		assert(not l.active())
		f:clean()
		f = fixture()
		l = f:start()
		for _ = 1, 15 do
			if not l.active() then
				break
			end
			f:tick(0.02, 0.03)
		end
		assert(f.root.CFrame.X < 14 and not l.active())
		f:clean()
	end,
	["reservation timeout and invalid acceptance release without ownership"] = function()
		local f = fixture()
		local l = assert(f:prepare())
		f.now += 0.06
		f:tick(0.02)
		assert(not l.commit(f.now))
		f:clean()
		for _, at in { 99, 101, 0 / 0 } do
			f = fixture()
			l = assert(f:prepare())
			assert(not l.commit(at))
			assert(#f.ownership == 0)
			f:clean()
		end
	end,
	["residual removal preserves vertical perpendicular excess reverse and explicit knockback"] = function()
		for _, entry in { { 100, false, 30 }, { -20, false, -20 }, { 25, true, 25 } } do
			local f = fixture()
			local l = f:start()
			f:tick(0.02)
			f.root.AssemblyLinearVelocity = V.new(entry[1], -19, 23)
			l.stop(entry[2])
			near(f.root.AssemblyLinearVelocity.X, entry[3])
			near(f.root.AssemblyLinearVelocity.Y, -19)
			near(f.root.AssemblyLinearVelocity.Z, 23)
			f:clean()
		end
	end,
	["every preparation property fault unwinds acquired resources"] = function()
		local probe = fixture()
		local l = assert(probe:prepare())
		local count = probe.setStage
		l.stop()
		for i = 1, count do
			local f = fixture()
			f.failSet = i
			assert(f:prepare() == nil, `property fault {i} missed`)
			f:clean()
			assert(#f.ownership == 0)
		end
	end,
	["runtime force-write failure stops cleanly"] = function()
		for _, offset in { 1, 2, 3 } do
			local f = fixture()
			local l = f:start()
			f.failSet = f.setStage + offset
			f:tick(0.02)
			assert(not l.active())
			f:clean()
		end
	end,
	["unconsumed first command and new authority never erase unrelated velocity"] = function()
		local f = fixture()
		local l = f:start()
		f.root.AssemblyLinearVelocity = V.new(12, -4, 3)
		f.run.PreSimulation:Fire(0.02)
		l.stop()
		assert(f.root.AssemblyLinearVelocity == V.new(12, -4, 3))
		f:clean()
		f = fixture()
		l = f:start()
		f:tick(0.02)
		f.root.owner = {}
		f.root.AssemblyLinearVelocity = V.new(31, 7, 2)
		l.stop()
		assert(f.root.AssemblyLinearVelocity == V.new(31, 7, 2))
		assert(#f.ownership == 1)
		f:clean()
	end,
	["expired reservation refuses commit even before next physics callback"] = function()
		local f = fixture()
		local l = assert(f:prepare())
		f.now += 0.06
		assert(not l.commit(f.now))
		assert(#f.ownership == 0)
		f:clean()
	end,

	["prepared resources mass and collision group must survive until commit"] = function()
		for _, change in
			{
				function(f)
					f.force.Parent = nil
				end,
				function(f)
					f.attachment.Parent = nil
				end,
				function(f)
					f.root.AssemblyMass = 12
				end,
				function(f)
					f.root.CollisionGroup = "Other"
				end,
			}
		do
			local f = fixture()
			local l = assert(f:prepare())
			change(f)
			assert(not l.commit(f.now))
			f:clean()
			assert(#f.ownership == 0)
		end
	end,

	["coarse occupied ground cell allowed only by certified empty full-volume descent"] = function()
		local f = fixture()
		f.terrain, f.seedClear = true, true
		local l = f:start()
		assert(f.terrainSweeps == 2)
		f:tick(0.02)
		assert(l.active() and f.terrainSweeps == 3)
		l.stop()
		f:clean()
	end,
	["buried terrain blocked descent missing empty seed and query failure refuse"] = function()
		for _, change in
			{
				function(f)
					f.terrainHit = 1
				end,
				function(f)
					f.terrainHit = 8
				end,
				function(f)
					f.seedClear = false
				end,
				function(f)
					f.failTerrainSweep = true
				end,
			}
		do
			local f = fixture()
			f.terrain, f.seedClear = true, true
			change(f)
			assert(f:prepare() == nil)
			assert((f.terrainSweeps or 0) <= 2)
			f:clean()
		end
	end,

	["tilted root voxel certificate encloses all body corners"] = function()
		local f = fixture()
		f.root.CFrame = CF.new(7, 8, 9) * CF.Angles(0.3, 0.7, 0.2)
		local l = assert(f:prepare())
		local region = f.lastRegion
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local corner = f.root.CFrame:PointToWorldSpace(V.new(x, y, z) * f.root.Size / 2)
					assert(corner.X - 4 >= region.lo.X - 0.0001 and corner.X + 4 <= region.hi.X + 0.0001)
					assert(corner.Y - 4 >= region.lo.Y - 0.0001 and corner.Y + 4 <= region.hi.Y + 0.0001)
					assert(corner.Z - 4 >= region.lo.Z - 0.0001 and corner.Z + 4 <= region.hi.Z + 0.0001)
				end
			end
		end
		l.stop()
		f:clean()
	end,
	["terrain clearance is fresh at commit and every frame not a cached start"] = function()
		local f = fixture()
		f.terrain, f.seedClear = true, true
		local l = assert(f:prepare())
		f.terrainHit = 2
		assert(not l.commit(f.now))
		f:clean()
		f = fixture()
		f.terrain, f.seedClear = true, true
		l = f:start()
		f:tick(0.02)
		f.terrainHit = 2
		f:tick(0.02)
		assert(not l.active())
		f:clean()
	end,

	["100 turnovers leave no listeners forces or duplicate ownership writes"] = function()
		local f = fixture()
		for _ = 1, 100 do
			local l = f:start()
			f:tick(0.02)
			l.stop()
			f:clean()
		end
		assert(#f.ownership == 200)
	end,
}
local count = 0
for name, test in cases do
	local ok, err = pcall(test)
	assert(ok, name .. ": " .. tostring(err))
	count += 1
end
print(`PASS Wind Step actual-source driver: {count} groups`)
