-- Actual fresh observer resolver with engine-shaped doubles. No replication/device proof.
local fs, luau = require("@lune/fs"), require("@lune/luau")
local I = require("../src/shared/CastCharacterIdentity")
local Plan = require("../src/shared/CastDeliveryPlan")
local source = fs.readFile("src/client/CastCharacterClient.luau")
local function fixture()
	local expected = { generation = "g:1", characterKey = "original", casterUserId = 42, slotRevision = 4 }
	local player = { UserId = 42 }
	local players = {
		GetPlayerByUserId = function(_, id)
			return if id == player.UserId then player else nil
		end,
	}
	player.Parent = players
	local world = {}
	local function model(v)
		return {
			raw = I.encode(v),
			present = true,
			humanoid = { Health = 100 },
			GetAttribute = function(self, name)
				assert(name == I.attribute)
				return self.raw
			end,
			IsDescendantOf = function(self, parent)
				assert(parent == world)
				return self.present
			end,
			FindFirstChildOfClass = function(self, name)
				assert(name == "Humanoid")
				return self.humanoid
			end,
		}
	end
	local original = model(expected)
	player.Character = original
	local services = {
		Players = players,
		ReplicatedStorage = { Shared = { CastCharacterIdentity = "identity", CastDeliveryPlan = "plan" } },
	}
	local client = luau.load(source, {
		injectGlobals = true,
		environment = {
			workspace = world,
			game = {
				GetService = function(_, name)
					return assert(services[name])
				end,
			},
			require = function(name)
				return if name == "identity" then I else Plan
			end,
		},
	})()
	return client, player, original, expected, model
end
local cases = {
	["late observer resolves only independently published complete original identity"] = function()
		local c, p, m, e = fixture()
		local raw = m.raw
		m.raw = nil
		assert(c.resolve(e) == nil)
		m.raw = raw
		local resolved, pose = c.resolve(e)
		assert(resolved == m and pose.alive and Plan.poseEligible(e, pose, true))
		m.raw = "bad"
		assert(c.resolve(e) == nil)
		m.raw = raw
		assert(c.resolve(e) == m and p.Character == m)
	end,
	["fresh liveness and streaming lookup fails closed"] = function()
		local c, p, m, e = fixture()
		for _, health in { 0, -1, 0 / 0, math.huge } do
			m.humanoid.Health = health
			assert(c.resolve(e) == nil)
		end
		m.humanoid = nil
		assert(c.resolve(e) == nil)
		m.humanoid = { Health = 100 }
		m.present = false
		assert(c.resolve(e) == nil)
		m.present = true
		p.Parent = nil
		assert(c.resolve(e) == nil)
	end,
	["replacement is never assigned a stale receipts identity"] = function()
		local c, p, m, e, model = fixture()
		local new = table.clone(e)
		new.characterKey = "replacement"
		new.generation = "g:2"
		p.Character = model(new)
		assert(c.resolve(e) == nil and c.resolve(new) == p.Character)
		p.Character.raw = nil
		assert(c.resolve(e) == nil and c.resolve(new) == nil)
		p.Character = nil
		assert(c.resolve(e) == nil)
		assert(m.raw == I.encode(e)) -- no mutation or stale-cache reuse
	end,
	["slot renewal ownership and generation mismatch cannot borrow current pose"] = function()
		local c, p, m, e = fixture()
		for field, replacement in { slotRevision = 5, generation = "g:2", characterKey = "new", casterUserId = 43 } do
			local v = table.clone(e)
			v[field] = replacement
			m.raw = I.encode(v)
			assert(c.resolve(e) == nil)
		end
		m.raw = I.encode(e)
		local v = table.clone(e)
		v.casterUserId = 99
		assert(c.resolve(v) == nil)
		assert(c.resolve({}) == nil and c.resolve(e) == m)
	end,
	["one hundred replacement lookups retain no resources or subscriptions"] = function()
		local c, p, m, e, model = fixture()
		for n = 1, 100 do
			local v = table.clone(e)
			v.characterKey = tostring(n)
			p.Character = model(v)
			assert(c.resolve(e) == nil and c.resolve(v) == p.Character)
		end
		p.Character = m
		assert(c.resolve(e) == m)
	end,
}
local count = 0
for name, test in cases do
	local ok, err = pcall(test)
	assert(ok, name .. ": " .. tostring(err))
	count += 1
end
print(`CAST CHARACTER CLIENT: PASS ({count} actual-source cases)`)
