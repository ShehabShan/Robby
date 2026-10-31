local M = require("../src/shared/CastCommandMap")
local R = require("../src/shared/CastReceipts")
local Inbox = require("../src/shared/CastInbox")
local CI = require("../src/shared/CastContactInbox")
local Dispatch = require("../src/shared/CastContactDispatch")
local Gate = require("../src/shared/CastWarningGate")
local Registry = require("../src/shared/Registry")
local All = require("../src/shared/Content/All")
local Config = require("../src/shared/Config")
local built = Registry.build(All.content(Config))
local catalog = M.catalog(built.moves)
local function acceptance(move)
	return {
		castId = "g:1",
		generation = "g",
		seq = 1,
		moveId = move or "move.rime.fall",
		casterUserId = 5,
		characterKey = "character:old",
		slotRevision = 4,
		acceptedAt = 100,
		releaseAt = 100.6,
		endsAt = 101.6,
		aim = { x = 0, y = 0, z = 1 },
		origin = { x = 1, y = 2, z = 3 },
		centre = { x = 7, y = 8, z = 9 },
	}
end
local function store(value)
	local s = R.new(Config.CastClientReceipt)
	assert(R.put(s, value or acceptance(), 0) == "stored")
	return assert(R.get(s, "g:1", 0)), s
end
local function contact()
	return {
		castId = "g:1",
		ordinal = 1,
		resource = 1,
		tick = 1,
		targetKey = "target:1",
		at = 100.7,
		amount = 4,
		position = { x = 12, y = 13, z = 14 },
		direction = { x = 0, y = 0, z = -1 },
	}
end
return {
	["catalog covers every current content delivery without copying gameplay parameters"] = function()
		local seen = {}
		for id, move in built.moves do
			local style = assert(catalog[id], id)
			assert(style.delivery == move.delivery.kind and style.hitFx == move.fx.hit)
			assert(style.params == nil and style.radius == nil and style.speed == nil)
			assert(style.worldWarning == (move.delivery.kind ~= "Self"))
			seen[style.delivery] = true
		end
		for _, kind in { "Projectile", "Volley", "Zone", "Burst", "Self" } do
			assert(seen[kind], kind)
		end
	end,
	["catalog snapshots immutable cosmetic fields independent of mutable source content"] = function()
		local moves =
			{ m = { id = "m", delivery = { kind = "Projectile" }, fx = { cast = "a", travel = "b", hit = "c" } } }
		local c = M.catalog(moves)
		moves.m.fx.hit = "changed"
		moves.m.delivery.kind = "Zone"
		assert(c.m.hitFx == "c" and c.m.delivery == "Projectile")
		assert(table.isfrozen(c) and table.isfrozen(c.m))
		assert(not pcall(function()
			c.m.hitFx = "changed"
		end))
	end,
	["unsupported malformed and mismatched content is not guessed"] = function()
		local c = M.catalog({
			bad = { id = "other", delivery = { kind = "Zone" } },
			unknown = { id = "unknown", delivery = { kind = "Beam" } },
			empty = { id = "empty" },
		})
		assert(next(c) == nil)
		local c2 = M.catalog({
			s = { id = "s", delivery = { kind = "Self" }, fx = { hit = {}, cast = "", travel = string.rep("x", 129) } },
		})
		assert(c2.s.hitFx == nil and c2.s.castFx == nil and c2.s.travelFx == nil)
	end,
	["zone commands use authoritative ground centre and exact captured timeline"] = function()
		local entry = store()
		local result = assert(M.accepted(catalog, entry))
		assert(result.key == "g:1" and result.timeline.x == 7 and result.timeline.y == 8 and result.timeline.z == 9)
		assert(
			result.timeline.acceptedAt == 100 and result.timeline.releaseAt == 100.6 and result.timeline.endsAt == 101.6
		)
		assert(
			result.metadata.acceptance.characterKey == "character:old" and result.metadata.acceptance.slotRevision == 4
		)
		assert(result.metadata.style.castFx == "fx.rime.fall.telegraph")
	end,
	["mapping never substitutes base move timings for woven captured schedule"] = function()
		local a = acceptance("move.rime.shard_fan")
		a.releaseAt = 100
		a.endsAt = 102.5
		local result = assert(M.accepted(catalog, store(a)))
		assert(result.timeline.releaseAt == 100 and result.timeline.endsAt == 102.5)
		assert(result.timeline.x == a.origin.x and result.metadata.style.delivery == "Volley")
	end,
	["projectile and self use captured origin while burst prefers captured centre"] = function()
		for _, move in { "move.rime.needle", "move.wind_step", "move.rime.shatter" } do
			local result = assert(M.accepted(catalog, store(acceptance(move))))
			assert(result.timeline.x == (if move == "move.rime.shatter" then 7 else 1))
		end
		local a = acceptance("move.rime.shatter")
		a.centre = nil
		assert(M.accepted(catalog, store(a)).timeline.x == 1)
	end,
	["missing zone centre refuses warning mapping without gating confirmed contact"] = function()
		local a = acceptance()
		a.centre = nil
		local entry = store(a)
		assert(M.accepted(catalog, entry) == nil)
		local c = M.contact(catalog, contact(), entry)
		assert(c.delivery == "Zone" and c.fx == "fx.rime.fall.tick" and c.receipt.position.x == 12)
	end,
	["unknown move refuses accepted routing but always yields generic confirmed impact"] = function()
		local entry = store(acceptance("move.future"))
		assert(M.accepted(catalog, entry) == nil)
		local c = M.contact(catalog, contact(), entry)
		assert(c.delivery == "Generic" and c.fx == nil and c.metadata == nil and c.action == "contact")
	end,
	["terminal retains style for late contact but never restarts accepted warning"] = function()
		local _, s = store()
		assert(R.terminate(s, "g:1", "complete", 101.6, 1) == "stored")
		local entry = R.get(s, "g:1", 1)
		assert(M.accepted(catalog, entry) == nil)
		assert(M.contact(catalog, contact(), entry).fx == "fx.rime.fall.tick")
	end,
	["terminal before acceptance and evicted metadata degrade to generic not silence"] = function()
		local s = R.new(Config.CastClientReceipt)
		R.terminate(s, "g:1", "complete", 101.6, 0)
		assert(R.put(s, acceptance(), 1) == "terminal")
		local entry = R.get(s, "g:1", 1)
		assert(M.accepted(catalog, entry) == nil and M.contact(catalog, contact(), entry).delivery == "Generic")
		local policy = table.clone(Config.CastClientReceipt)
		policy.capacity = 1
		s = R.new(policy)
		R.put(s, acceptance(), 0)
		local other = acceptance()
		other.seq = 2
		other.castId = "g:2"
		R.put(s, other, 0)
		assert(M.contact(catalog, contact(), R.get(s, "g:1", 0)).delivery == "Generic")
	end,
	["wrong generation metadata cannot style a different confirmed cast"] = function()
		local a = acceptance()
		a.generation = "h"
		a.castId = "h:1"
		local s = R.new(Config.CastClientReceipt)
		R.put(s, a, 0)
		assert(M.contact(catalog, contact(), R.get(s, "h:1", 0)).delivery == "Generic")
	end,
	["mapping carries immutable receipt snapshot and does not mutate inbox or content"] = function()
		local a = acceptance()
		local entry = store(a)
		a.centre.x = 999
		a.origin.x = 999
		local result = assert(M.accepted(catalog, entry))
		assert(result.timeline.x == 7 and result.metadata.acceptance.origin.x == 1)
		assert(table.isfrozen(result) and table.isfrozen(result.timeline) and table.isfrozen(result.metadata))
		local i = CI.new(Config.CastClientContact)
		local v = contact()
		CI.record(i, v, 0, 101)
		v.position.x = 999
		local c = M.contact(catalog, CI.get(i, "g:1", 1).value, entry)
		assert(c.receipt.position.x == 12 and table.isfrozen(c.receipt))
	end,
	["real gate and contact owner compose across owner observer A C T arrival orders"] = function()
		for _, owner in { false, true } do
			for _, order in { "ACT", "ATC", "CAT", "CTA", "TAC", "TCA" } do
				local receipts = Inbox.new(Config.CastClientReceipt)
				local contacts = CI.new(Config.CastClientContact)
				local hits, warnings = {}, {}
				local gate = Gate.new(Config.CastWarning, function(f)
					table.insert(warnings, f)
					return true
				end, function()
					return true
				end)
				local dispatcher = Dispatch.new(contacts, Config.CastContactPresentation, function(frame)
					table.insert(
						hits,
						M.contact(catalog, frame.contact, R.get(receipts.acceptances, frame.contact.castId, 0))
					)
					return true
				end)
				if owner then
					Gate.predict(gate, "g:1", 0, 100)
				end
				for n = 1, 3 do
					local action = string.sub(order, n, n)
					if action == "A" then
						Inbox.accept(receipts, acceptance(), 0, 100.7, 1)
						local entry = receipts.acceptances.entries["g:1"]
						local command = if entry then M.accepted(catalog, entry) else nil
						if command then
							Gate.accept(gate, command.key, command.timeline, 0, 100.7)
						end
					elseif action == "T" then
						Inbox.terminal(receipts, "g:1", "complete", 100.7, 0)
						Gate.cancel(gate, "g:1", 0, 100.7)
					else
						assert(CI.record(contacts, contact(), 0, 100.7) == "stored")
						Dispatch.tick(dispatcher, 0, 100.7)
					end
				end
				Dispatch.tick(dispatcher, 0.1, 100.8)
				assert(#hits == 1 and hits[1].receipt.position.x == 12, order)
				assert(hits[1].delivery == (if order == "ACT" or order == "ATC" then "Zone" else "Generic"), order)
				assert(dispatcher.rendered == 1 and dispatcher.resources.count == 1)
				Gate.destroy(gate)
				Dispatch.destroy(dispatcher)
			end
		end
	end,
}
