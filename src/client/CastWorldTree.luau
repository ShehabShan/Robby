--!strict
-- Minimal owned geometry primitive; NOT started by the live client.
-- Caller is the outer warning owner, supplies validated plans and retains handles.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Plan = require(ReplicatedStorage.Shared.CastDeliveryPlan)
local Tree = {}
export type Owner = { bind: (string, () -> ()) -> any, isCurrent: (any) -> boolean, release: (any) -> boolean }
export type Handle = { root: Folder, parts: { [string]: Part }, ticket: any, owner: Owner, closed: boolean }
function Tree.close(h: Handle)
	if h.closed then
		return
	end
	h.closed = true
	h.root:Destroy()
	table.clear(h.parts)
end
local function update(h: Handle, frame: Plan.Frame)
	assert(not frame.speculative and #frame.world <= 16, "world plan bounds")
	local seen: { [string]: boolean } = {}
	for _, shape in frame.world do
		assert(not seen[shape.slot] and (shape.kind == "Box" or shape.kind == "Disc"), "shape slot/kind")
		seen[shape.slot] = true
		local part: Part? = h.parts[shape.slot]
		if not part then
			part = Instance.new("Part")
			-- Own the child before ANY property configuration, even failed parenting.
			local object: Part = assert(part, "part allocated")
			local ok, err = pcall(function()
				object.Parent = h.root
			end)
			if not ok then
				object:Destroy()
				error(err)
			end
			h.parts[shape.slot] = part
			part.Name = shape.slot
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
			part.Material = Enum.Material.Neon
			part.Color = Color3.fromRGB(180, 235, 255)
		end
		assert(part, "part allocated")
		local p = shape.position
		local position = Vector3.new(p.x, p.y, p.z)
		if shape.kind == "Box" then
			local size = assert(shape.size, "box size")
			local d = assert(shape.direction, "box direction")
			part.Shape = Enum.PartType.Block
			part.Size = Vector3.new(size.x, size.y, size.z)
			part.CFrame = CFrame.lookAt(position, position + Vector3.new(d.x, d.y, d.z))
		else
			local radius = assert(shape.radius, "disc radius")
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(0.06, radius * 2, radius * 2)
			part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
		end
		part.Transparency = if frame.phase == "warning" then 0.65 else 0.8
	end
	for slot, part in h.parts do
		if not seen[slot] then
			part:Destroy()
			h.parts[slot] = nil
		end
	end
end
function Tree.seek(h: Handle, frame: Plan.Frame): boolean
	if h.closed or not h.owner.isCurrent(h.ticket) then
		Tree.close(h)
		return false
	end
	local ok = pcall(update, h, frame)
	if not ok then
		h.owner.release(h.ticket)
		Tree.close(h)
	end
	return ok
end
function Tree.open(owner: Owner, frame: Plan.Frame): Handle?
	local root = Instance.new("Folder")
	local h: Handle = { root = root, parts = {}, ticket = nil, owner = owner, closed = false }
	local ok, ticket = pcall(owner.bind, "world-tree", function()
		Tree.close(h)
	end)
	if not ok or not ticket then
		Tree.close(h)
		return nil
	end
	h.ticket = ticket
	if not Tree.seek(h, frame) then
		return nil
	end
	local active = pcall(function()
		assert(owner.isCurrent(ticket), "stale tree")
		root.Name = "KeyedCastWorld"
		root.Parent = workspace
	end)
	if not active then
		owner.release(ticket)
		Tree.close(h)
		return nil
	end
	return h
end
return Tree
