local H = require("../src/shared/MistvaleHub")
local L = require("../src/shared/MistvaleLayout")

local layout = L.DEFAULT
local plan = H.placements(layout)

local function ok(cond: boolean, msg: string)
	if not cond then
		error(msg, 2)
	end
end

local function count(piece: string): number
	local n = 0
	for _, p in plan do
		if p.piece == piece then
			n += 1
		end
	end
	return n
end

return {
	["hub: plan validates (flat, apart, off paths, spawn clear)"] = function()
		local problems = H.validate(layout, plan)
		ok(#problems == 0, table.concat(problems, "; "))
	end,
	["hub: village has rest spot, Crucible shrine, gate, grove and houses"] = function()
		ok(count("RestSpot") == 1 and count("CrucibleShrine") == 1 and count("HubGate") == 1, "core pieces")
		ok(count("BindingGrove") == 1, "grove marker")
		ok(count("HubHouseSmall") + count("HubHouseTall") >= 5, "5 houses (ART §4)")
		ok(count("PineA") + count("PineB") + count("PineC") >= 12, "pines ring the hub")
		local tags = {}
		for _, p in plan do
			if p.tag then
				tags[p.tag] = p
			end
		end
		ok(tags.RestSpot ~= nil and tags.RestSpot.piece == "RestSpot", "RestSpot tag on the rest spot")
		ok(tags.BindingGrove ~= nil, "BindingGrove tag")
	end,
	["hub: gate straddles the path to zone 1"] = function()
		for _, p in plan do
			if p.piece == "HubGate" then
				ok(H.pathDist(layout, p.x, p.z) < 0, "gate centre on the path")
			end
		end
	end,
	["hub: validate catches an overlap and a blocked spawn"] = function()
		local bad = { { piece = "HubHouseSmall", x = 0, y = 0, z = 0, yaw = 0 } }
		table.insert(bad, { piece = "HubHouseTall", x = 5, y = 0, z = 0, yaw = 0 })
		local problems = table.concat(H.validate(layout, bad), "; ")
		ok(string.find(problems, "overlaps") ~= nil, "overlap found")
		ok(string.find(problems, "blocks spawn") ~= nil, "spawn found")
	end,
	["hub: every piece has proxies with palette colours and fits its footprint"] = function()
		for name, piece in H.PIECES do
			local list = H.proxies(name)
			ok(#list > 0, `{name} has proxies`)
			for _, pr in list do
				ok(H.PALETTE[pr.color] ~= nil, `{name} colour {pr.color}`)
				ok(math.abs(pr.offset[1]) + pr.size[1] / 2 <= piece.w / 2 + 1, `{name} proxy wider than footprint`)
				ok(pr.offset[2] + pr.size[2] / 2 <= piece.h + 1, `{name} proxy taller than piece`)
				ok(pr.color ~= "glow" or pr.shape ~= "Marker", "glow is visible")
			end
		end
	end,
}
