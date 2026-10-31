local Geometry = require("../src/shared/CastGeometry")
local Store = require("../src/shared/CastReceipts")
local Lifetime = require("../src/shared/CastLifetime")
local Config = require("../src/shared/Config")
local Registry = require("../src/shared/Registry")
local All = require("../src/shared/Content/All")
local built = Registry.build(All.content(Config))
local fallback = Config.Abilities.Rimeshard.needle.hitboxSize
local function acceptance(g)
	return {
		castId = "g:1",
		generation = "g",
		seq = 1,
		moveId = "test",
		casterUserId = 42,
		characterKey = "c",
		slotRevision = 1,
		acceptedAt = 100,
		releaseAt = 101,
		endsAt = 102,
		aim = { x = 0, y = 0, z = -1 },
		origin = { x = 0, y = 2, z = 0 },
		centre = { x = 3, y = 0, z = 8 },
		geometry = g,
	}
end
local function store()
	return Store.new({ capacity = 8, responseSeconds = 10, tombstoneSeconds = 20, maxLifetimeSeconds = 20 })
end
local function zone()
	return assert(Geometry.capture({ delivery = { kind = "Zone", params = { radius = 17, range = 49 } } }, fallback))
end
return {
	["every live move captures valid authoritative delivery shape"] = function()
		local kinds = {}
		for _, move in built.moves do
			local g = assert(Geometry.capture(move, fallback), move.id)
			assert(Geometry.valid(g) and g.kind == move.delivery.kind and table.isfrozen(g))
			kinds[g.kind] = true
		end
		for _, kind in { "Projectile", "Volley", "Zone", "Burst", "Self" } do
			assert(kinds[kind], kind)
		end
	end,
	["woven projectile and volley bounds never use base values"] = function()
		for _, kind in { "Projectile", "Volley" } do
			local p = { speed = 123, range = 87, count = 7, spreadDeg = 61, hitbox = { x = 9, y = 4, z = 3 } }
			local g = assert(Geometry.capture({ delivery = { kind = kind, params = p } }, fallback))
			assert(g.speed == 123 and g.range == 87 and g.hitboxX == 9 and g.hitboxY == 4 and g.hitboxZ == 3)
			assert(
				g.count == (if kind == "Volley" then 7 else 1) and g.spreadDeg == (if kind == "Volley" then 61 else 0)
			)
			p.hitbox.x, p.speed = 99, 99
			assert(g.hitboxX == 9 and g.speed == 123)
		end
	end,
	["projectile fallback hitbox equals server sweep fallback"] = function()
		local g = assert(
			Geometry.capture(
				{ delivery = { kind = "Volley", params = { speed = 10, range = 20, count = 1, spreadDeg = 0 } } },
				fallback
			)
		)
		assert(g.hitboxX == fallback.x and g.hitboxY == fallback.y and g.hitboxZ == fallback.z)
	end,
	["fixed zone and moving burst semantics cannot be interchanged"] = function()
		local g = zone()
		assert(g.radius == 17 and g.range == 49 and g.centreMode == "Fixed")
		local b = assert(Geometry.capture({ delivery = { kind = "Burst", params = { radius = 22 } } }, fallback))
		assert(b.radius == 22 and b.centreMode == "CasterAtRelease")
		local fake = table.clone(b)
		fake.centreMode = "Fixed"
		assert(not Geometry.valid(fake))
		local a = acceptance(g)
		a.centre = nil
		assert(Store.put(store(), a, 0) == "invalid")
	end,
	["all numeric fields reject NaN infinity missing string and negative"] = function()
		local g = zone()
		for _, field in { "radius", "range", "speed", "count", "spreadDeg", "hitboxX", "hitboxY", "hitboxZ" } do
			for _, bad in { 0 / 0, math.huge, -math.huge, -1, "2" } do
				local copy = table.clone(g)
				copy[field] = bad
				assert(not Geometry.valid(copy), field)
			end
			local copy = table.clone(g)
			copy[field] = nil
			assert(not Geometry.valid(copy))
		end
	end,
	["malformed capture and fractional or overflowing fan refused"] = function()
		for _, bad in { false, {}, { delivery = {} }, { delivery = { kind = "Unknown", params = {} } } } do
			assert(Geometry.capture(bad, fallback) == nil)
		end
		for _, n in { 0, 1.5, 17 } do
			assert(
				Geometry.capture(
					{ delivery = { kind = "Volley", params = { count = n, speed = 1, range = 1, spreadDeg = 0 } } },
					fallback
				) == nil
			)
		end
		assert(
			Geometry.capture(
				{ delivery = { kind = "Volley", params = { count = 1, speed = 1, range = 1, spreadDeg = 180 } } },
				fallback
			) == nil
		)
	end,
	["receipt and lifetime independently freeze geometry without aliasing"] = function()
		local g = table.clone(zone())
		local a = acceptance(g)
		local s = store()
		assert(Store.put(s, a, 0) == "stored")
		local life = Lifetime.new(2)
		local handle = Lifetime.start(life, a, 0, 1, 1)
		g.radius = 100
		local saved = Store.get(s, a.castId, 0).acceptance.geometry
		assert(saved.radius == 17 and handle.acceptance.geometry.radius == 17)
		assert(not pcall(function()
			saved.radius = 5
		end))
		assert(not pcall(function()
			handle.acceptance.geometry.radius = 5
		end))
	end,
	["duplicate geometry equality conflicts on every field and nil transition"] = function()
		local a = acceptance(zone())
		local s = store()
		assert(Store.put(s, a, 0) == "stored")
		assert(Store.put(s, acceptance(Geometry.copy(a.geometry)), 1) == "duplicate")
		local changed = acceptance(table.clone(a.geometry))
		changed.geometry.radius += 1
		assert(Store.put(s, changed, 1) == "conflict")
		assert(Store.put(s, acceptance(nil), 1) == "conflict")
		for k, v in a.geometry do
			local b = table.clone(a.geometry)
			b[k] = if type(v) == "number" then v + 1 else v .. "x"
			assert(not Geometry.same(a.geometry, b), k)
		end
	end,
	["legacy missing geometry stays absent not invented"] = function()
		local s = store()
		local a = acceptance(nil)
		assert(Store.put(s, a, 0) == "stored" and Store.get(s, a.castId, 0).acceptance.geometry == nil)
		assert(Geometry.same(nil, nil) and not Geometry.same(zone(), nil))
	end,
}
