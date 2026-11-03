--!strict
-- Admin panel rules (T-054a, D-398/D-399). Pure: no game services. The server re-checks the allowlist and
-- re-validates every request with these functions (never trust the client). Every Kith/food/shard an admin
-- grants is marked test-only (`data.adminGrants`) so `cleanup` can remove it again.
-- Actions: giveKith, removeKith, refill, addShards, addFood, spawnBeast, cleanup, debugDraw (toggle).
-- Profile actions are applied by `apply`; refill, spawnBeast and debugDraw change the live world and are done by the server.

local AdminRules = {}

export type Request = {
	action: string,
	speciesId: string?,
	uid: string?,
	amount: number?,
	foodId: string?,
	rare: boolean?,
	kind: string?,
	distance: number?,
}

local ACTIONS = {
	giveKith = true,
	removeKith = true,
	refill = true,
	addShards = true,
	addFood = true,
	spawnBeast = true,
	cleanup = true,
	debugDraw = true,
}

function AdminRules.isAdmin(cfg: any, userId: any): boolean
	if typeof(userId) ~= "number" then
		return false
	end
	for _, id in cfg.Admin.userIds do
		if id == userId then
			return true
		end
	end
	return false
end

local function wholeIn(n: any, lo: number, hi: number): number?
	if typeof(n) ~= "number" or n ~= n or n % 1 ~= 0 or n < lo or n > hi then
		return nil
	end
	return n
end

local function foods(built: any): { [string]: boolean }
	local set = {}
	for _, k in built.kith do
		if type(k.food) == "string" then
			set[k.food] = true
		end
	end
	return set
end

-- Lists every Kith species with its rank, sorted by rank then id (for the panel picker).
function AdminRules.species(built: any): { { id: string, rank: number } }
	local list = {}
	for id, k in built.kith do
		table.insert(list, { id = id, rank = k.rank or 1 })
	end
	table.sort(list, function(a, b)
		if a.rank ~= b.rank then
			return a.rank < b.rank
		end
		return a.id < b.id
	end)
	return list
end

-- Returns (clean request, nil) or (nil, reason). Only known fields of the right type survive.
function AdminRules.validate(cfg: any, built: any, req: any): (any, string?) -- any = Request or nil
	if type(req) ~= "table" or type(req.action) ~= "string" or not ACTIONS[req.action] then
		return nil, "unknown action"
	end
	local a = req.action
	local c = cfg.Admin
	if a == "giveKith" then
		if type(req.speciesId) ~= "string" or built.kith[req.speciesId] == nil then
			return nil, "unknown Kith"
		end
		return { action = a, speciesId = req.speciesId }, nil
	elseif a == "removeKith" then
		if type(req.uid) ~= "string" or #req.uid == 0 or #req.uid > 80 then
			return nil, "bad uid"
		end
		return { action = a, uid = req.uid }, nil
	elseif a == "addShards" then
		local n = wholeIn(req.amount, -c.maxShards, c.maxShards)
		if n == nil or n == 0 then
			return nil, "bad amount"
		end
		return { action = a, amount = n }, nil
	elseif a == "addFood" then
		if type(req.foodId) ~= "string" or not foods(built)[req.foodId] then
			return nil, "unknown food"
		end
		local n = wholeIn(req.amount, 1, c.maxFood)
		if n == nil then
			return nil, "bad amount"
		end
		local out: Request = { action = a, foodId = req.foodId, rare = req.rare == true, amount = n }
		return out, nil
	elseif a == "spawnBeast" then
		if type(req.kind) ~= "string" or cfg.Beasts.kinds[req.kind] == nil then
			return nil, "unknown beast"
		end
		local d = req.distance
		if typeof(d) ~= "number" or d ~= d then
			return nil, "bad distance"
		end
		local out: Request =
			{ action = a, kind = req.kind, distance = math.clamp(d, c.spawnDistance.min, c.spawnDistance.max) }
		return out, nil
	end
	return { action = a }, nil
end

local function grants(data: any): any
	local g = data.adminGrants
	if type(g) ~= "table" then
		g = { kith = {}, shards = 0, items = {} }
		data.adminGrants = g
	end
	return g
end

local function dropKith(data: any, uid: string)
	data.kith[uid] = nil
	if data.heartKith == uid then
		data.heartKith = nil
	end
	local lo = data.loadout
	if type(lo) == "table" and type(lo.slots) == "table" then
		for i, s in lo.slots do
			if s == uid then
				lo.slots[i] = ""
			end
		end
	end
	grants(data).kith[uid] = nil
end

-- Applies a validated profile action. Returns (ok, detail). refill/spawnBeast/debugDraw return (true, "server").
function AdminRules.apply(data: any, req: Request): (boolean, string)
	local a = req.action
	local g = grants(data)
	if a == "giveKith" then
		local base = "admin." .. (string.gsub(req.speciesId :: string, "^kith%.", ""))
		local n = 1
		while data.kith[`{base}.{n}`] do
			n += 1
		end
		local uid = `{base}.{n}`
		data.kith[uid] = { uid = uid, speciesId = req.speciesId, testOnly = true }
		g.kith[uid] = true
		return true, uid
	elseif a == "removeKith" then
		local uid = req.uid :: string
		if data.kith[uid] == nil then
			return false, "not owned"
		end
		dropKith(data, uid)
		return true, uid
	elseif a == "addShards" then
		local w = data.wallet
		local before = w.shards or 0
		w.shards = math.max(0, before + (req.amount :: number))
		g.shards += w.shards - before
		return true, tostring(w.shards)
	elseif a == "addFood" then
		local id = if req.rare then (req.foodId :: string) .. ".rare" else req.foodId :: string
		data.items = if type(data.items) == "table" then data.items else {}
		data.items[id] = (data.items[id] or 0) + (req.amount :: number)
		g.items[id] = (g.items[id] or 0) + (req.amount :: number)
		return true, `{id}={data.items[id]}`
	elseif a == "cleanup" then
		return true, AdminRules.cleanup(data)
	end
	return true, "server"
end

-- Removes everything admins granted to this profile: test-only Kith, and granted shards/food (never below 0).
function AdminRules.cleanup(data: any): string
	local g = grants(data)
	local count = 0
	for uid, k in data.kith do
		if g.kith[uid] or (type(k) == "table" and k.testOnly) then
			dropKith(data, uid)
			count += 1
		end
	end
	if g.shards > 0 then
		data.wallet.shards = math.max(0, (data.wallet.shards or 0) - g.shards)
	end
	for id, n in g.items do
		if type(data.items) == "table" and typeof(data.items[id]) == "number" then
			data.items[id] = math.max(0, data.items[id] - n)
		end
	end
	data.adminGrants = { kith = {}, shards = 0, items = {} }
	return `removed {count} Kith`
end

-- Builds a log line and appends it to `data.adminLog`, keeping the newest `cfg.Admin.logCap` entries.
function AdminRules.log(cfg: any, data: any, by: number, req: any, ok: boolean, detail: string, now: number): any
	local entry = {
		at = now,
		by = by,
		action = if type(req) == "table" and type(req.action) == "string" then req.action else "?",
		ok = ok,
		detail = string.sub(detail, 1, 120),
	}
	data.adminLog = if type(data.adminLog) == "table" then data.adminLog else {}
	table.insert(data.adminLog, entry)
	while #data.adminLog > cfg.Admin.logCap do
		table.remove(data.adminLog, 1)
	end
	return entry
end

return AdminRules
