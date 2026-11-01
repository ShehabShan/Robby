-- Actual generated server + real transport/adapter/controller, mock engine/driver.
-- Synthetic scheduling validates orchestration only, never Roblox physics evidence.
local fs, luau, serde = require("@lune/fs"), require("@lune/luau"), require("@lune/serde")
local rb = require("@lune/roblox")
local fixture = require("./helpers/owner_test_fixture")
local Session = require("../src/shared/OwnerTestSession")
local Adapter = require("./published/OwnerTestAdapter")
local Policy = require("./published/WindStepPublishedPolicy")
local Evidence = require("./studio/WindStepEvidence")
local Motion = require("../src/shared/WindStep")
local source = fs.readFile("build/published-test/wind_step.server.luau")
local function worker(mode)
	return fixture(nil, function(f, env)
		f.entry, f.waits, f.prepared, f.commits, f.stops = source, 0, 0, 0, 0
		local function signal()
			return f.signal()
		end
		local workspace = {
			Gravity = 196.2,
			GetServerTimeNow = function()
				return f.now
			end,
		}
		local root = f.instance("Part")
		root.Size, root.Position = rb.Vector3.new(2, 2, 1), rb.Vector3.new(-50, 5, 0)
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = rb.Vector3.zero, rb.Vector3.zero
		local auto, owner = true, nil
		function root:CanSetNetworkOwnership()
			return true
		end
		function root:GetNetworkOwnershipAuto()
			return auto
		end
		function root:GetNetworkOwner()
			return owner
		end
		function root:SetNetworkOwner(value)
			auto, owner = false, value
		end
		function root:SetNetworkOwnershipAuto()
			auto, owner = true, nil
		end
		function root:IsDescendantOf(value)
			return value == workspace
		end
		local humanoid = f.instance("Humanoid")
		humanoid.Health, humanoid.RigType, humanoid.FloorMaterial =
			100, rb.Enum.HumanoidRigType.R15, rb.Enum.Material.Concrete
		humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight, humanoid.AutoRotate = 16, 50, 7.2, true
		function humanoid:GetState()
			return { Name = "Running" }
		end
		local character = f.instance("Model")
		root.Parent, root.Name, humanoid.Parent = character, "HumanoidRootPart", character
		function character:GetPivot()
			return rb.CFrame.new(root.Position)
		end
		function character:PivotTo(cf)
			root.Position = cf.Position
		end
		f.owner.Character = if mode == "character-wait" then nil else character
		f.root, f.humanoid, f.character = root, humanoid, character
		f.run.PreSimulation, f.run.PostSimulation = signal(), signal()
		function f.run:GetRobloxVersion()
			return "MOCK-NOT-PHYSICS"
		end
		local attrs = {
			TestUniverseId = 123,
			TestPlaceId = 456,
			TestOwnerUserId = 7738981129,
			RunWindStep = true,
			SourceRevision = "OFFLINE",
			SourceHashes = "OFFLINE",
		}
		local script = f.instance("Script")
		script.Destroying, script.changed = signal(), signal()
		script.Evidence, script.PublishedPolicy, script.WindStepDriver = "Evidence", "Policy", "Driver"
		script.OwnerTestTransport, script.OwnerTestSession, script.OwnerTestAdapter = "Transport", "Session", "Adapter"
		function script:GetAttribute(name)
			return attrs[name]
		end
		function script:SetAttribute(name, value)
			attrs[name] = value
		end
		function script:GetPropertyChangedSignal()
			return script.changed
		end
		f.stop = function()
			script.Destroying:Fire()
		end
		local transport
		local current, frames, moving, originalAuto, originalOwner, force, attachment
		local fired = false
		local function invalidate(seam)
			if fired or mode ~= seam then
				return
			end
			fired = true
			f.players.PlayerAdded:Fire({}) -- cancel before membership snapshot updates
			if seam == "commit" or seam == "pre" or seam == "post" then
				f.synchronousStop = not moving and f.preserved == true
			end
		end
		local function stopMotion(preserve)
			f.stops += 1
			if mode == "stop-error" and f.commits > 0 then
				error("injected driver release fault")
			end
			if not current then
				return
			end
			f.preserved = preserve
			moving = false
			if force then
				force:Destroy()
			end
			if attachment then
				attachment:Destroy()
			end
			auto, owner = originalAuto, originalOwner
		end
		local driver = {
			prepare = function()
				f.prepared += 1
				originalAuto, originalOwner = auto, owner
				frames, moving = 0, false
				force, attachment = f.instance("LinearVelocity"), f.instance("Attachment")
				force.Name, force.Parent, attachment.Name, attachment.Parent =
					"WindStepVelocity", root, "WindStepAttachment", root
				current = {
					active = function()
						return moving
					end,
					stop = stopMotion,
					commit = function()
						f.commits += 1
						moving, auto, owner = true, false, nil
						invalidate("commit")
						return true
					end,
				}
				invalidate("prepare")
				return current
			end,
		}
		local oldServices = f.game.GetService
		function f.game:GetService(name)
			if name == "ReplicatedStorage" then
				return { Shared = { WindStep = "Motion" } }
			end
			return oldServices(self, name)
		end
		env.script, env.workspace = script, workspace
		env.Vector3, env.CFrame, env.Enum = rb.Vector3, rb.CFrame, rb.Enum
		env.print, env.warn = function() end, function() end
		env.require = function(name)
			return ({
				Evidence = Evidence,
				Policy = Policy,
				Driver = driver,
				Motion = Motion,
				Session = Session,
				Adapter = Adapter,
				Transport = transport,
			})[name]
		end
		local originalInstance = env.Instance.new
		env.Instance.new = function(class)
			local obj = originalInstance(class)
			if class == "Folder" then
				local destroy = obj.Destroy
				function obj:Destroy()
					if mode == "fixture-error" and self.Name == "WindStepFixtures" then
						error("fixture fault")
					end
					return destroy(self)
				end
			end
			return obj
		end
		env.task.wait = function()
			f.now += 0.02
			f.waits += 1
			-- The first wait is header admission, before owner start.
			if f.waits == 2 then
				invalidate("settle")
				invalidate("character-wait")
			end
			if f.waits == 5 then
				invalidate("align")
			end
			if moving then
				if mode == "deadline" then
					f.now = 602
					f.run.Heartbeat:Fire()
				end
				if mode == "leave" or mode == "rejoin" then
					f.players.PlayerRemoving:Fire(f.owner)
					if mode == "rejoin" then
						f.list = { { UserId = f.owner.UserId } }
						f.players.PlayerAdded:Fire(f.list[1])
					end
				elseif mode == "destroy" then
					script.Destroying:Fire()
				elseif mode == "disable" then
					script.Disabled = true
					script.changed:Fire()
				end
				if mode == "replacement" then
					f.owner.Character = {}
				end
				if mode == "death" then
					humanoid.Health = 0
				end
				invalidate("pre")
				force.Enabled, force.PlaneVelocity = true, rb.Vector2.new(70, 0)
				f.run.PreSimulation:Fire(0.02)
				if moving then
					frames += 1
					local wall = false
					for _, obj in f.instances do
						if obj.Name == "Wall" and obj.Parent then
							wall = true
						end
					end
					local x = math.min(frames * 1.4, if wall then 4 else 14)
					local y = root.Position.Y
					if y > 50 then
						root.AssemblyLinearVelocity -= rb.Vector3.new(0, workspace.Gravity * 0.02, 0)
					end
					root.Position = rb.Vector3.new(x, y, 0)
					force.Enabled = false
					invalidate("post")
					f.run.PostSimulation:Fire()
					if moving and (frames == 10 or (wall and frames == 3)) then
						stopMotion(false)
					end
				end
			else
				if root.Position.Y == 8 then
					root.Position = rb.Vector3.new(0, 5, 0)
				end
				if mode ~= "no-post" then
					f.run.PostSimulation:Fire()
				end
			end
			f.run.Heartbeat:Fire()
		end
		transport = luau.load(fs.readFile("tests/published/OwnerTestTransport.luau"), { environment = env })()
	end)
end
local count = 0
local function test(name, fn)
	fn()
	count += 1
	print("PASS " .. name)
end
local function report(f)
	local status = f.ask("status")
	local parts = {}
	for i = 1, status.pages do
		table.insert(parts, f.ask("report", i).data)
	end
	return serde.decode("json", table.concat(parts)), status
end
local function noWorkerLeaks(f)
	for _, obj in f.instances do
		if
			obj.Name == "WindStepFixtures"
			or obj.Name == "Floor"
			or obj.Name == "Wall"
			or obj.Name == "WindStepVelocity"
			or obj.Name == "WindStepAttachment"
		then
			assert(obj.destroyed and obj.Parent == nil, "worker instance leak " .. obj.Name)
		end
	end
	assert(f.humanoid.WalkSpeed == 16 and f.humanoid.AutoRotate == true, "humanoid not restored")
end
test("explicit start only; full106-case generated worker returns after cleanup", function()
	local f = worker()
	assert(f.ok, tostring(f.error))
	assert(f.prepared == 0 and #f.jobs == 0)
	f.ask("start", nil, { UserId = f.owner.UserId })
	assert(#f.jobs == 0)
	f.ask("start")
	f.drain()
	local r, status = report(f)
	assert(r.runCompleted and r.cleanup and r.matrixPassed, serde.encode("json", r))
	assert(not r.dynamicsAccepted and f.prepared == 106 and status.progress == 106)
	f.ask("start")
	assert(#f.jobs == 0)
	noWorkerLeaks(f)
	f.stop()
	f.noLeaks()
end)
test("cancel across waits, reservation, commit and active simulation seams", function()
	for _, mode in
		{
			"character-wait",
			"settle",
			"align",
			"prepare",
			"commit",
			"pre",
			"post",
			"deadline",
			"replacement",
			"death",
			"no-post",
		}
	do
		local f = worker(mode)
		assert(f.ok, tostring(f.error))
		f.ask("start")
		f.drain()
		local r = report(f)
		assert(not r.matrixPassed and not r.runCompleted and r.cleanup, mode .. ":" .. serde.encode("json", r))
		assert(f.prepared <= 1, mode)
		if mode == "prepare" then
			assert(f.commits == 0)
		end
		if f.commits > 0 then
			assert(f.preserved == true, mode)
		end
		if mode == "commit" or mode == "pre" or mode == "post" then
			assert(f.synchronousStop == true, "synchronous stop: " .. mode)
		end
		noWorkerLeaks(f)
		f.stop()
		f.noLeaks()
	end
end)
test("owner removal, teardown while active, deferred cancellation remain clean", function()
	for _, mode in { "leave", "rejoin", "destroy", "disable" } do
		local f = worker(mode)
		assert(f.ok)
		f.ask("start")
		f.drain()
		assert(f.prepared == 1 and f.preserved == true, mode)
		noWorkerLeaks(f)
		f.stop()
		f.noLeaks()
	end
	local f = worker()
	f.ask("start")
	f.stop()
	f.drain()
	assert(f.prepared == 0)
	f.noLeaks()
end)
test("independent cleanup continues after fixture or driver stop errors", function()
	for _, mode in { "fixture-error", "stop-error" } do
		local f = worker(mode)
		f.ask("start")
		f.drain()
		local r = report(f)
		assert(not r.cleanup and not r.matrixPassed)
		assert(f.humanoid.WalkSpeed == 16 and f.humanoid.AutoRotate)
		f.stop()
		f.noLeaks()
	end
end)
test("100 independent generated-session lifetimes leave no owned resources", function()
	for _ = 1, 100 do
		local f = worker("pre")
		assert(f.ok)
		f.ask("start")
		f.drain()
		assert(report(f).cleanup)
		noWorkerLeaks(f)
		f.stop()
		f.noLeaks()
	end
end)
print(string.format("PASS %d generated worker groups (mocked engine only)", count))
