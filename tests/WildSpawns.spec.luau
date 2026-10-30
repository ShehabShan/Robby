local W = require("../src/shared/WildSpawns")
local H = require("../src/shared/MistvaleHub")
local L = require("../src/shared/MistvaleLayout")
local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local All = require("../src/shared/Content/All")

local layout = L.DEFAULT
local built = Registry.build(All.content(Config))

local function ok(cond: boolean, msg: string)
	if not cond then
		error(msg, 2)
	end
end

return {
	["wild: Mist Lotus stands in the Binding grove on flat ground"] = function()
		local grove
		for _, p in H.placements(layout) do
			if p.tag == "BindingGrove" then
				grove = p
			end
		end
		local spots = W.spots(layout)
		ok(#spots == 2, `2 lotus spots, got {#spots}`)
		for _, s in spots do
			ok(s.kith == "kith.lotus", "lotus")
			ok(math.sqrt((s.x - grove.x) ^ 2 + (s.z - grove.z) ^ 2) <= 12, "inside the grove")
			ok(math.abs(s.y - grove.y) < 0.5, "flat ground")
			ok(math.sqrt((s.x - layout.spawn.x) ^ 2 + (s.z - layout.spawn.z) ^ 2) > 40, "away from spawn")
		end
	end,
	["wild: every wild kind is a registered Kith with HP and respawn"] = function()
		for _, k in W.KINDS do
			ok(built.kith[k.kith] ~= nil, `{k.kith} registered`)
			ok(k.hp > 0 and k.respawn > 0 and k.count > 0, `{k.kith} numbers`)
		end
	end,
}
