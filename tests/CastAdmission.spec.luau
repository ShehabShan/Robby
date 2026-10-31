local A = require("../src/shared/CastAdmission")
local Ledger = require("../src/shared/CastLedger")
local Config = require("../src/shared/Config")
local Tx = require("../src/shared/CastTransaction")
local Stance = require("../src/shared/Stance")
local Registry = require("../src/shared/Registry")
local All = require("../src/shared/Content/All")
local built = Registry.build(All.content(Config))
local function state(capacity)
	return A.new(
		"server-player",
		{ capacity = capacity or 4, maxAdvance = 1024, responseSeconds = 10, renewDistance = 30000 }
	)
end
local function request(s, seq)
	return {
		generation = s.ledger.generation,
		seq = seq,
		moveId = "move.rime.shard_fan",
		aim = { x = 0, y = 0, z = -1 },
	}
end
local function accept()
	return true, nil
end
return {
	["canonical binary identity is finite complete and unambiguous"] = function()
		local s = state()
		local r = request(s, 1)
		local clean, key = A.canonical(r)
		assert(clean and key and table.isfrozen(clean) and table.isfrozen(clean.aim))
		r.aim.x = -0
		local _, negativeZero = A.canonical(r)
		assert(key == negativeZero)
		r.aim.x = 2 ^ -40
		local _, precise = A.canonical(r)
		assert(precise ~= key)
		r.aim.x = 0
		r.point = { x = 0, y = 0, z = 0 }
		local _, originPoint = A.canonical(r)
		assert(originPoint ~= key)
		r.point.y = 0 / 0
		assert(A.canonical(r) == nil)
		r.point.y = math.huge
		assert(A.canonical(r) == nil)
		r.point = nil
		r.moveId = string.rep("x", 65)
		assert(A.canonical(r) == nil)
	end,
	["accepted duplicates call real payment once; changed intent never runs"] = function()
		local s = state()
		local stance = Stance.new()
		Stance.set(stance, true)
		stance.chain.step, stance.chain.lastAt = 2, 100
		local caster = { qi = 100, hp = 100, strain = 0, strainMax = 100, cooldowns = {} }
		local kit = Stance.kit(built.kith["kith.rimeshard"], built.moves)
		local cfg = { chain = Config.Abilities.Rimeshard.needle.chain, finisherRecovery = 1.2 }
		local count = 0
		local function auth(r)
			count += 1
			return Tx.pay(stance, cfg, kit, caster, built.moves[r.moveId], 100.01)
		end
		local r = request(s, 1)
		local first = A.dispatch(s, r, 100, auth)
		assert(first.receipt.status == "accepted" and first.receipt.castId == "server-player:1:1")
		for i = 1, 20 do
			assert(A.dispatch(s, r, 100 + i / 100, auth).kind == "duplicate")
		end
		assert(count == 1 and caster.qi == 90 and stance.chain.step == 0)
		r.aim.x = 0.00000001
		assert(A.dispatch(s, r, 101, auth).reason == "payload_changed")
		assert(count == 1)
	end,
	["rejected costs cached even if resources subsequently arrive"] = function()
		local s, n = state(), 0
		local function reject()
			n += 1
			return false, "qi"
		end
		local r = request(s, 1)
		assert(A.dispatch(s, r, 100, reject).receipt.reason == "qi")
		assert(A.dispatch(s, r, 101, accept).receipt.reason == "qi")
		assert(n == 1)
	end,
	["expiration and bounded eviction do not make old IDs executable"] = function()
		local s = state(3)
		for i = 1, 1000 do
			assert(A.dispatch(s, request(s, i), i / 1000, accept).kind == "completed")
		end
		assert(Ledger.prune(s.ledger, 1) == 3)
		assert(A.dispatch(s, request(s, 1), 1, accept).reason == "stale")
		assert(A.dispatch(s, request(s, 1000), 12, accept).reason == "stale")
		assert(Ledger.prune(s.ledger, 12) == 0)
	end,
	["u16 rollover and server rotation reject prior character traffic"] = function()
		local s = state()
		local old = request(s, 65535)
		assert(A.dispatch(s, old, 0, accept).kind == "completed")
		assert(A.dispatch(s, request(s, 0), 1, accept).kind == "completed")
		assert(A.rotate(s) == "server-player:2")
		assert(A.dispatch(s, old, 2, accept).reason == "generation")
		assert(A.dispatch(s, request(s, 0), 2, accept).receipt.castId == "server-player:2:0")
	end,
	["renewal signalled before half ring; arbitrary client generation refused"] = function()
		local s = state()
		assert(A.dispatch(s, request(s, 0), 0, accept).kind == "completed")
		local last
		for i = 1, 30 do
			last = A.dispatch(s, request(s, i * 1000), i, accept)
		end
		assert(last.renew and last.kind == "completed")
		local malicious = request(s, 30001)
		malicious.generation = "server-player:999"
		assert(A.dispatch(s, malicious, 31, accept).reason == "generation")
		assert(s.epoch == 1)
	end,
	["invalid clocks and payloads never invoke authorization"] = function()
		local s = state()
		local function forbidden()
			error("must not run")
		end
		for _, raw in { {}, { seq = 0 }, { generation = 4 } } do
			assert(A.dispatch(s, raw, 0, forbidden).reason == "malformed")
		end
		assert(A.dispatch(s, request(s, 1), 0 / 0, forbidden).reason == "clock")
		A.dispatch(s, request(s, 1), 100, accept)
		assert(A.dispatch(s, request(s, 2), 99, forbidden).reason == "clock")
	end,
	["nested entry cannot mutate ledger mid-transaction"] = function()
		local s = state()
		local function auth()
			assert(A.dispatch(s, request(s, 2), 1, accept).reason == "busy")
			assert(A.rotate(s) == nil)
			assert(not pcall(A.destroy, s))
			return true, nil
		end
		assert(A.dispatch(s, request(s, 1), 1, auth).receipt.status == "accepted")
	end,
	["yielding and throwing adapters cannot retry partial effects"] = function()
		for _, mode in { "yield", "throw", "invalid" } do
			local s, n = state(), 0
			local function bad()
				n += 1
				if mode == "yield" then
					coroutine.yield()
					n += 100
				elseif mode == "throw" then
					error("broken")
				end
				return false, nil
			end
			local r = request(s, 1)
			assert(A.dispatch(s, r, 0, bad).receipt.reason == "internal_error")
			assert(A.dispatch(s, r, 1, bad).kind == "duplicate" and n == 1)
			assert(not s.busy)
		end
	end,
	["teardown prevents dispatch and server scope is bounded"] = function()
		local s = state()
		A.dispatch(s, request(s, 1), 0, accept)
		A.destroy(s)
		assert(next(s.ledger.entries) == nil and A.rotate(s) == nil)
		assert(A.dispatch(s, request(s, 2), 1, accept).reason == "closed")
		assert(not pcall(A.new, "bad:scope", Config.CastProtocol))
		assert(A.new("server_unique_GUID", Config.CastProtocol).epoch == 1)
	end,
}
