--!strict
-- Retired ids (SCHEMAS §1, D-047): content ids are never reused. A removed id maps to its
-- replacement, or to `false` when it has none. Saves resolve old ids through here on load.
-- Pure: tested under Lune.

export type Map = { [string]: string | false }

local MAX_HOPS = 16

local Retired = {}

-- Live map. Add entries here when content is removed or renamed; never delete entries.
Retired.map = {} :: Map

-- Follows replacement chains. Returns (id, retired): the live id (or nil if the chain ends
-- with no replacement or loops) and whether `id` was retired at all.
function Retired.resolve(id: string, map: Map?): (string?, boolean)
	local m: Map = map or Retired.map
	if m[id] == nil then
		return id, false
	end
	local current: string = id
	for _ = 1, MAX_HOPS do
		local nextId = m[current]
		if nextId == nil then
			return current, true
		elseif nextId == false then
			return nil, true
		end
		current = nextId :: string
	end
	return nil, true -- a cycle or an over-long chain counts as "no replacement"
end

return Retired
