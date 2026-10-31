-- Executes actual client receipt adapter with mocked engine/network, not live-network proof.
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local Inbox = require("../src/shared/CastInbox")
local Config = require("../src/shared/Config")
local source = fs.readFile("src/client/CastReceiptClient.luau")
local init = fs.readFile("src/client/init.client.luau")
assert(init:find("require(script.CastReceiptClient).start()", 1, true) < init:find("Net.CastSync.Fire", 1, true))
assert(init:find("script.Destroying:Connect(stopCastReceipts)", 1, true))
local listeners, callbacks, now, disconnected = {}, {}, 100, 0
local function event(name)
	return {
		On = function(fn)
			assert(not listeners[name])
			listeners[name], callbacks[name] = fn, fn
			return function()
				listeners[name] = nil
				disconnected += 1
			end
		end,
	}
end
local net =
	{ CastAccepted = event("accepted"), CastDisposition = event("disposition"), CastTerminal = event("terminal") }
local serverNow = 1000000
local heartbeat
local services = {
	ReplicatedStorage = { Shared = { Config = "config", CastInbox = "inbox" } },
	RunService = {
		Heartbeat = {
			Connect = function(_, fn)
				heartbeat = fn
				return {
					Disconnect = function()
						heartbeat = nil
						disconnected += 1
					end,
				}
			end,
		},
	},
}
local adapter = luau.load(source, {
	injectGlobals = true,
	environment = {
		workspace = {
			GetServerTimeNow = function()
				return serverNow
			end,
		},
		game = {
			GetService = function(_, name)
				return services[name]
			end,
		},
		script = { Parent = { Net = "net" } },
		require = function(id)
			return ({ config = Config, inbox = Inbox, net = net })[id]
		end,
		os = {
			clock = function()
				return now
			end,
		},
	},
})()
local stop = adapter.start()
assert(adapter.start() == stop)
local a = {
	castId = "scope:1:1",
	generation = "scope:1",
	seq = 1,
	moveId = "move.rime.fall",
	casterUserId = 42,
	characterKey = "character-1",
	slotRevision = 2,
	acceptedAt = 1000000,
	releaseAt = 1000000.6,
	endsAt = 1000001.6,
	aim = rb.Vector3.new(0, 0, -1),
	origin = rb.Vector3.new(0, 3, 0),
	centre = rb.Vector3.new(5, 0, -10),
}
listeners.accepted(a)
local state = adapter.inbox()
local original = state.acceptances.entries[a.castId]
assert(original.acceptance.centre.x == 5 and original.acceptance.acceptedAt == 1000000)
now += 5
listeners.accepted(a)
assert(state.acceptances.entries[a.castId] == original)
listeners.disposition({ generation = "scope:1", seq = 2, moveId = "move.rime.fall", status = "rejected", reason = "qi" })
assert(state.responses["scope:1:2"].value.reason == "qi")
-- Character absence/respawn is deliberately irrelevant to world-centred receipts.
assert(state.acceptances.entries[a.castId].acceptance.characterKey == "character-1")
-- Death/leave never clear this listener: an accepted world hazard ends on server terminal only.
listeners.terminal({ castId = a.castId, reason = "completed", at = a.endsAt })
local ended = state.acceptances.entries[a.castId]
assert(ended.terminal.at == a.endsAt and ended.acceptance.characterKey == "character-1")
listeners.accepted(a)
listeners.terminal({ castId = a.castId, reason = "expired", at = a.endsAt + 9 })
assert(state.acceptances.entries[a.castId] == ended)
local reordered = table.clone(a)
reordered.seq, reordered.castId = 3, "scope:1:3"
listeners.terminal({ castId = reordered.castId, reason = "caster_lost", at = a.acceptedAt + 0.1 })
listeners.accepted(reordered)
assert(state.acceptances.entries[reordered.castId].acceptance == nil)
now += 13
heartbeat()
assert(next(state.acceptances.entries) == nil and next(state.responses) == nil)
listeners.accepted(a) -- TTL retirement must not revive old ended cast
assert(next(state.acceptances.entries) == nil)
stop()
stop()
assert(disconnected == 4 and adapter.inbox() == nil and next(listeners) == nil)
callbacks.accepted(a) -- queued callback cannot resurrect destroyed inbox
callbacks.terminal({ castId = a.castId, reason = "completed", at = a.endsAt })
assert(next(state.acceptances.entries) == nil)
local stop2 = adapter.start()
assert(adapter.inbox() ~= state)
serverNow = a.endsAt + Config.CastLifetime.graceSeconds
listeners.accepted(a) -- even a fresh adapter rejects an already expired schedule
assert(next(adapter.inbox().acceptances.entries) == nil)
stop2()
print(
	"CAST RECEIPT CLIENT: PASS (actual adapter; registration, vectors/clocks, duplicate, disposition, terminal reorder/expiry, teardown/restart)"
)
