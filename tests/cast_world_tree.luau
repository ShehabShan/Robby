-- Actual engine primitive under mocked Instance lifecycle; no visual/device claim.
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local source = fs.readFile("src/client/CastWorldTree.luau")
local function fixture()
	local f = { objects = {}, bound = false, current = true, fail = nil, cleanup = nil, allocations = 0 }
	local function new(class)
		if f.fail == "allocate" and class == "Part" then
			error("allocation")
		end
		local props = { ClassName = class, dead = false }
		local o
		o = setmetatable({}, {
			__index = function(_, k)
				if k == "Destroy" then
					return function()
						if props.dead then
							return
						end
						props.dead = true
						for _, child in f.objects do
							if child.Parent == o then
								child:Destroy()
							end
						end
					end
				end
				return props[k]
			end,
			__newindex = function(_, k, v)
				if k == "Parent" then
					assert(f.bound, "activated before binding")
				end
				if f.fail == "child-parent" and k == "Parent" and class == "Part" then
					error("parent")
				end
				if f.fail == "root-parent" and k == "Parent" and class == "Folder" then
					error("parent")
				end
				if f.fail == "update" and k == "CFrame" then
					error("update")
				end
				props[k] = v
			end,
		})
		table.insert(f.objects, o)
		f.allocations += 1
		return o
	end
	f.tree = luau.load(source, {
		injectGlobals = true,
		environment = {
			game = {
				GetService = function()
					return { Shared = { CastDeliveryPlan = "plan" } }
				end,
			},
			require = function()
				return {}
			end,
			Instance = { new = new },
			workspace = {},
			Vector3 = rb.Vector3,
			CFrame = rb.CFrame,
			Color3 = rb.Color3,
			Enum = rb.Enum,
		},
	})()
	f.owner = {
		bind = function(_, dispose)
			if f.fail == "bind" then
				return nil
			end
			f.bound = true
			f.cleanup = dispose
			return "ticket"
		end,
		isCurrent = function()
			return f.current
		end,
		release = function()
			if f.cleanup then
				f.cleanup()
			end
			return true
		end,
	}
	return f
end
local function plan(n, disc)
	local shapes = {}
	for i = 1, n do
		table.insert(shapes, {
			slot = "s" .. i,
			kind = if disc then "Disc" else "Box",
			position = { x = i, y = 2, z = 3 },
			direction = { x = 0, y = 0, z = -1 },
			size = { x = 2, y = 3, z = 4 },
			radius = 7,
		})
	end
	return { phase = "warning", speculative = false, world = shapes }
end
local function clean(f)
	for _, o in f.objects do
		assert(o.dead, "unowned live " .. o.ClassName)
	end
end
local cases = {
	["bounded fan seeks in place and owns only safe parts"] = function()
		local f = fixture()
		local h = assert(f.tree.open(f.owner, plan(16)))
		assert(#f.objects == 17 and h.root.Parent ~= nil)
		for _, p in h.parts do
			assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch)
		end
		local v = plan(16)
		v.phase = "active"
		v.world[1].position.x = 99
		for _ = 1, 100 do
			assert(f.tree.seek(h, v))
		end
		assert(
			f.allocations == 17 and h.parts.s1.CFrame.Position.X == 99 and h.parts.s1.Size == rb.Vector3.new(2, 3, 4)
		)
		assert(h.parts.s1.Transparency == 0.8)
		assert(f.tree.seek(h, plan(1, true)))
		assert(h.parts.s2 == nil)
		assert(h.parts.s1.Shape == rb.Enum.PartType.Cylinder and h.parts.s1.Size == rb.Vector3.new(0.06, 14, 14))
		assert(math.abs(h.parts.s1.CFrame.RightVector.Y - 1) < 1e-6)
		f.cleanup()
		f.cleanup()
		clean(f)
	end,
	["allocation binding parenting update and stale failures clean all instances"] = function()
		for _, mode in { "allocate", "bind", "child-parent", "root-parent", "update", "stale" } do
			local f = fixture()
			f.fail = mode
			if mode == "stale" then
				f.current = false
			end
			assert(f.tree.open(f.owner, plan(2)) == nil, mode)
			clean(f)
		end
	end,
	["late failure and stale ticket retire already active resources"] = function()
		for _, mode in { "update", "stale" } do
			local f = fixture()
			local h = assert(f.tree.open(f.owner, plan(2)))
			if mode == "stale" then
				f.current = false
			else
				f.fail = mode
			end
			assert(not f.tree.seek(h, plan(2)))
			clean(f)
			assert(not f.tree.seek(h, plan(2)))
		end
	end,
	["speculation overbudget and duplicate slots refuse without leaks"] = function()
		for _, mode in { "predicted", "over", "duplicate" } do
			local f = fixture()
			local v = plan(if mode == "over" then 17 else 2)
			if mode == "predicted" then
				v.speculative = true
			elseif mode == "duplicate" then
				v.world[2].slot = v.world[1].slot
			end
			assert(f.tree.open(f.owner, v) == nil)
			clean(f)
		end
	end,
}
local n = 0
for name, test in cases do
	local ok, err = pcall(test)
	assert(ok, name .. ": " .. tostring(err))
	n += 1
end
print(`CAST WORLD TREE: PASS ({n} actual-source groups; mocked engine, not live rendering)`)
