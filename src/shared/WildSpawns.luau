--!strict
-- Wild Kith placed in the world (T-025b1, D-158). Pure: which wild Kith stand where (a ring in the Binding
-- grove from Shared.MistvaleHub) with HP and respawn time. Server WildKithService turns these into Models.

local MistvaleHub = require("./MistvaleHub")
local MistvaleLayout = require("./MistvaleLayout")

local WildSpawns = {}

export type Kind = { kith: string, count: number, hp: number, respawn: number, ring: number }
export type Spawn = { kith: string, x: number, y: number, z: number, hp: number, respawn: number }

WildSpawns.KINDS = {
	{ kith = "kith.lotus", count = 2, hp = 60, respawn = 30, ring = 6 }, -- Mist Lotus (T-025, D-112)
} :: { Kind }

function WildSpawns.spots(layout: MistvaleLayout.Layout): { Spawn }
	local grove: MistvaleHub.Placement? = nil
	for _, p in MistvaleHub.placements(layout) do
		if p.tag == "BindingGrove" then
			grove = p
		end
	end
	local out: { Spawn } = {}
	if not grove then
		return out
	end
	for _, k in WildSpawns.KINDS do
		for i = 1, k.count do
			local a = (i - 1) * 2 * math.pi / k.count
			local x, z = grove.x + k.ring * math.cos(a), grove.z + k.ring * math.sin(a)
			local y = MistvaleLayout.heightAt(layout, x, z)
			table.insert(out, { kith = k.kith, x = x, y = y, z = z, hp = k.hp, respawn = k.respawn })
		end
	end
	return out
end

return WildSpawns
