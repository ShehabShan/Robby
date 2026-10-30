--!strict
-- Builds the Mistvale hub village (T-021c, D-147) from the pure plan in Shared.MistvaleHub: one Model per kit
-- piece under workspace.MistvaleHub, made of code proxies until the T-021b meshes are uploaded (Open Cloud).
-- The rest spot pad is tagged `RestSpot` (RefineService/Crucible/Loom) and the grove marker `BindingGrove`.
-- Must start after MistvaleTerrain and before RefineService (which only adds a fallback pad when none is tagged).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MistvaleHub = require(ReplicatedStorage.Shared.MistvaleHub)
local MistvaleLayout = require(ReplicatedStorage.Shared.MistvaleLayout)

local MistvaleHubBuilder = {}

local function build(p: MistvaleHub.Placement): Model
	local model = Instance.new("Model")
	model.Name = p.piece
	local base = CFrame.new(p.x, p.y, p.z) * CFrame.Angles(0, p.yaw, 0)
	for i, proxy in MistvaleHub.proxies(p.piece) do
		local part = Instance.new("Part")
		part.Name = if i == 1 then "Root" else "Part"
		part.Anchored = true
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if proxy.shape == "Ball" then
			part.Shape = Enum.PartType.Ball
		end
		part.Size = Vector3.new(proxy.size[1], proxy.size[2], proxy.size[3])
		part.CFrame = base * CFrame.new(proxy.offset[1], proxy.offset[2], proxy.offset[3])
		part.Color = Color3.fromHex(MistvaleHub.PALETTE[proxy.color])
		part.Material = if proxy.color == "glow" then Enum.Material.Neon else Enum.Material.SmoothPlastic
		if proxy.shape == "Marker" then
			part.Transparency = 1
			part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
		end
		part.Parent = model
		if i == 1 then
			model.PrimaryPart = part
			if p.tag then
				CollectionService:AddTag(part, p.tag)
			end
		end
	end
	return model
end

function MistvaleHubBuilder.start()
	local folder = Instance.new("Folder")
	folder.Name = "MistvaleHub"
	local list = MistvaleHub.placements(MistvaleLayout.DEFAULT)
	for _, p in list do
		build(p).Parent = folder
	end
	folder.Parent = workspace
	print(`[Mistvale] hub built: {#list} pieces`)
end

return MistvaleHubBuilder
