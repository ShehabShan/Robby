--!strict
-- Production spatial adapter shared by the driver and Saved-engine probe (D-315).
local Clearance = {}
-- Empty-voxel seed certification avoids Blockcast's initial-overlap blind spot.
-- Voxel occupancy is only an emptiness certificate, NEVER an estimated surface height.
local function solidVoxels(cf: CFrame, size: Vector3): boolean
	local x, y, z = cf.RightVector, cf.UpVector, cf.LookVector
	local half = Vector3.new(
		math.abs(x.X) * size.X + math.abs(y.X) * size.Y + math.abs(z.X) * size.Z,
		math.abs(x.Y) * size.X + math.abs(y.Y) * size.Y + math.abs(z.Y) * size.Z,
		math.abs(x.Z) * size.X + math.abs(y.Z) * size.Y + math.abs(z.Z) * size.Z
	) / 2
	-- Terrain collision surfaces can extend into adjacent zero-occupancy cells
	-- (Saved29 shallow penetration). Require a full voxel halo for emptiness.
	local halo = half + Vector3.new(4, 4, 4)
	local region = Region3.new(cf.Position - halo, cf.Position + halo):ExpandToGrid(4)
	local materials, occupancy = workspace.Terrain:ReadVoxels(region, 4)
	-- ReadVoxels arrays include a Size Vector3 dictionary entry in the real engine.
	-- Iterate only numeric voxel cells, never dictionary metadata.
	for ix, plane in ipairs(occupancy) do
		for iy, row in ipairs(plane) do
			for iz, amount in ipairs(row) do
				if amount > 0 and materials[ix][iy][iz] ~= Enum.Material.Water then
					return true
				end
			end
		end
	end
	return false
end
function Clearance.occupied(root: BasePart, size: Vector3, overlap: OverlapParams, terrain: RaycastParams): boolean
	if #workspace:GetPartBoundsInBox(root.CFrame, size, overlap) > 0 then
		return true
	end
	if not solidVoxels(root.CFrame, size) then
		return false
	end
	-- A proven-empty seed and unobstructed full-volume descent certify the endpoint.
	-- Two fixed probes bound work; caves/overhangs with no clear path still refuse.
	for _, height in { 8, 16 } do
		local offset = Vector3.new(0, height, 0)
		local seed = root.CFrame + offset
		if not solidVoxels(seed, size) and not workspace:Blockcast(seed, size, -offset, terrain) then
			return false
		end
	end
	return true
end

return Clearance
