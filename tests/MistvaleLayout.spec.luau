local L = require("../src/shared/MistvaleLayout")

local layout = L.DEFAULT

local function ok(cond: boolean, msg: string)
	if not cond then
		error(msg, 2)
	end
end

local function name(n: string): any
	return n
end

return {
	["mistvale: hub is flat around spawn and spawn is in the hub"] = function()
		local hub = layout.areas[1]
		for _, p in { { 0, 0 }, { 60, -25 }, { -90, 40 }, { 0, -110 } } do
			local h = L.heightAt(layout, p[1], p[2])
			ok(math.abs(h - hub.height) < 0.01, `hub height at {p[1]},{p[2]}: {h}`)
		end
		ok(L.zoneAt(layout, layout.spawn.x, layout.spawn.z) == "hub", "spawn in hub")
		ok(L.surfaceAt(layout, 0, 0) == "Cobblestone", "plaza at spawn")
	end,
	["mistvale: path from hub to zone 1 is walkable and dry"] = function()
		local a, b = layout.areas[1], layout.areas[2]
		local len = math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
		local steps = math.floor(len / 4)
		local prev = L.heightAt(layout, a.x, a.z)
		for i = 1, steps do
			local t = i / steps
			local x, z = a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t
			local h = L.heightAt(layout, x, z)
			ok(math.abs(h - prev) / (len / steps) <= 0.35, `too steep at step {i}`)
			ok(h > layout.waterLevel + 1, `wet at step {i}`)
			prev = h
		end
		ok(L.surfaceAt(layout, (a.x + b.x) / 2, (a.z + b.z) / 2) == "Ground", "dirt path midway")
	end,
	["mistvale: zone 1 is flat, the rim encloses the map, the river is carved"] = function()
		local z1 = layout.areas[2]
		ok(L.zoneAt(layout, z1.x, z1.z) == "zone1", "zone1 centre")
		ok(math.abs(L.heightAt(layout, z1.x, z1.z) - z1.height) < 0.01, "zone1 height")
		ok(L.surfaceAt(layout, z1.x + 30, z1.z) == "LeafyGrass", "zone1 grass")
		for _, c in { { 500, 500 }, { -500, 0 }, { 0, 505 } } do
			ok(L.heightAt(layout, c[1], c[2]) > 40, `rim at {c[1]},{c[2]}`)
		end
		ok(L.heightAt(layout, layout.river.x, 0) < layout.waterLevel, "river bed below water")
		ok(L.surfaceAt(layout, layout.river.x, 0) == "Sand", "river sand")
	end,
	["mistvale: chunk at spawn is grid-aligned and well formed"] = function()
		local c = L.buildChunk(layout, 124, 124, 8, 8, name)
		ok(c.min.x % layout.voxel == 0 and c.min.z % layout.voxel == 0 and c.min.y % layout.voxel == 0, "aligned")
		ok(#c.materials == 8 and #c.occupancy == 8, "x size")
		local ny = (c.max.y - c.min.y) / layout.voxel
		ok(#c.materials[1] == ny and #c.materials[1][1] == 8, "y/z size")
		local cobble, wet = false, false
		for i = 1, 8 do
			for j = 1, ny do
				for k = 1, 8 do
					local o = c.occupancy[i][j][k]
					ok(o >= 0 and o <= 1, "occupancy range")
					cobble = cobble or c.materials[i][j][k] == "Cobblestone"
					wet = wet or c.materials[i][j][k] == "Water"
				end
			end
		end
		ok(cobble and not wet, "plaza surface, no water")
	end,
	["mistvale: voxel budget and determinism"] = function()
		ok(L.voxelEstimate(layout, 8) < 5e6, "voxel budget")
		ok(L.heightAt(layout, 123, -77) == L.heightAt(layout, 123, -77), "deterministic")
		ok(#L.anchors(layout) == #layout.areas + 1, "anchors")
	end,
}
