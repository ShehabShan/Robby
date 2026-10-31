-- Executes actual client receipt adapter with mocked engine/network, not live-network proof.
local fs, luau, rb = require("@lune/fs"), require("@lune/luau"), require("@lune/roblox")
local Inbox = require("../src/shared/CastInbox")
local ContactInbox = require("../src/shared/CastContactInbox")
local Config = require("../src/shared/Config")
local Dispatch = require("../src/shared/CastContactDispatch")
local CommandMap = require("../src/shared/CastCommandMap")
local Registry = require("../src/shared/Registry")
local All = require("../src/shared/Content/All")
local catalog = CommandMap.catalog(Registry.build(All.content(Config)).moves)
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
local net = {
	CastAccepted = event("accepted"),
	CastDisposition = event("disposition"),
	CastTerminal = event("terminal"),
	CastContact = event("contact"),
}
local serverNow = 1000000
local heartbeat
local services = {
	ReplicatedStorage = { Shared = { Config = "config", CastInbox = "inbox", CastContactInbox = "contacts" } },
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
			return ({ config = Config, inbox = Inbox, contacts = ContactInbox, net = net })[id]
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
local geometry = require("../src/shared/CastGeometry")
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
	geometry = table.clone(
		assert(geometry.capture({ delivery = { kind = "Zone", params = { radius = 17, range = 49 } } }, {}))
	),
	centre = rb.Vector3.new(5, 0, -10),
}
listeners.accepted(a)
local state = adapter.inbox()
local contact = {
	castId = a.castId,
	ordinal = 1,
	resource = 1,
	tick = 1,
	targetKey = "m1",
	at = a.acceptedAt + 0.1,
	amount = 4,
	position = rb.Vector3.new(1, 2, 3),
	direction = rb.Vector3.zAxis,
}
for _ = 1, 1000 do
	listeners.contact(contact)
end
local contactState = adapter.contacts()
assert(contactState.count == 1 and ContactInbox.get(contactState, a.castId, 1).value.position.y == 2)
local original = state.acceptances.entries[a.castId]
assert(original.acceptance.centre.x == 5 and original.acceptance.acceptedAt == 1000000)
assert(original.acceptance.geometry.radius == 17 and original.acceptance.geometry.range == 49)
a.geometry.radius = 99
assert(original.acceptance.geometry.radius == 17 and table.isfrozen(original.acceptance.geometry))
a.geometry.radius = 17
local bad = table.clone(a)
bad.seq, bad.castId = 4, "scope:1:4"
bad.geometry = table.clone(a.geometry)
bad.geometry.radius = 0 / 0
listeners.accepted(bad)
assert(state.acceptances.entries[bad.castId] == nil)
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
-- S77: compose the ACTUAL listener adapter with the pure contact owner/mapper.
-- Rendering is injected, not live engine proof; no production cutover is enabled.
local effects, contactCleanups = {}, 0
local dispatcher = Dispatch.new(contactState, Config.CastContactPresentation, function(frame)
	local mapped = CommandMap.contact(catalog, frame.contact, state.acceptances.entries[frame.contact.castId])
	assert(not effects[frame.key], "actual listener replayed a consumed impact")
	effects[frame.key] = mapped
	assert(frame.bind("impact", function()
		contactCleanups += 1
	end))
	return true
end)
assert(Dispatch.tick(dispatcher, now, contact.at))
assert(dispatcher.rendered == 1)
-- All acceptance/contact/terminal permutations, plus duplicate contact, are independent.
local permutations =
	{ { "A", "C", "T" }, { "A", "T", "C" }, { "C", "A", "T" }, { "C", "T", "A" }, { "T", "A", "C" }, { "T", "C", "A" } }
for i, events in permutations do
	local av = table.clone(a)
	av.seq = 10 + i
	av.castId = "scope:1:" .. av.seq
	local cv = table.clone(contact)
	cv.castId = av.castId
	for _, event in events do
		if event == "A" then
			listeners.accepted(av)
		elseif event == "T" then
			listeners.terminal({ castId = av.castId, reason = "completed", at = av.endsAt })
		else
			listeners.contact(cv)
			listeners.contact(cv)
			assert(Dispatch.tick(dispatcher, now, cv.at))
		end
	end
	local entry = ContactInbox.get(contactState, av.castId, 1)
	assert(entry and entry.value.amount == 4 and state.acceptances.entries[av.castId].terminal)
	local mapped = effects[tostring(#av.castId) .. ":" .. av.castId .. ":1"]
	assert(mapped and mapped.receipt.position.y == 2)
	assert(mapped.delivery == (if i <= 2 then "Zone" else "Generic"))
end
assert(dispatcher.rendered == 7 and dispatcher.consumed == 7)
assert(contactState.count == 7)
local late = table.clone(contact)
late.ordinal = 2
late.tick = 2
late.at = a.endsAt
serverNow = a.endsAt + 1
listeners.contact(late) -- valid late contact AFTER terminal must not disappear
assert(ContactInbox.get(contactState, a.castId, 2))
assert(Dispatch.tick(dispatcher, now, serverNow) and dispatcher.rendered == 8)
assert(contactCleanups == 0, "server terminal must not cancel confirmed-contact resources")
now += 13
heartbeat()
assert(next(state.acceptances.entries) == nil and next(state.responses) == nil)
assert(contactState.count == 0 and next(contactState.identities) == nil)
assert(Dispatch.tick(dispatcher, now, serverNow) and contactCleanups == 8)
assert(next(contactState.consumed) == nil and dispatcher.resources.count == 0)
listeners.accepted(a) -- TTL retirement must not revive old ended cast
assert(next(state.acceptances.entries) == nil)
stop()
stop()
assert(disconnected == 5 and adapter.inbox() == nil and adapter.contacts() == nil and next(listeners) == nil)
callbacks.contact(contact)
assert(not Dispatch.tick(dispatcher, now, serverNow) and dispatcher.closed)
assert(contactState.closed and contactState.count == 0)
callbacks.accepted(a) -- queued callback cannot resurrect destroyed inbox
callbacks.terminal({ castId = a.castId, reason = "completed", at = a.endsAt })
assert(next(state.acceptances.entries) == nil)
local oldContactCallback = callbacks.contact
local stop2 = adapter.start()
assert(adapter.inbox() ~= state and adapter.contacts() ~= contactState)
listeners.contact(contact) -- restart watermark must not replay previous effects
assert(adapter.contacts().count == 0)
serverNow += 1
local fresh = table.clone(contact)
fresh.at = serverNow
fresh.castId = "fresh:1"
listeners.contact(fresh)
assert(adapter.contacts().count == 1)
oldContactCallback(fresh)
assert(contactState.count == 0 and adapter.contacts().count == 1)
-- Pressure must remain bounded in the real adapter, not only in the pure module.
for i = 1, Config.CastClientContact.capacity + 3 do
	local cv = table.clone(fresh)
	cv.castId = "pressure:" .. i
	cv.at = serverNow + i * 0.001
	listeners.contact(cv)
end
assert(adapter.contacts().count <= Config.CastClientContact.capacity)
listeners.contact(fresh) -- the evicted first receipt cannot reappear
assert(ContactInbox.get(adapter.contacts(), fresh.castId, 1) == nil)
local n = 0
for _ in adapter.contacts().identities do
	n += 1
end
assert(n == adapter.contacts().count)
serverNow = a.endsAt + Config.CastLifetime.graceSeconds
listeners.accepted(a) -- even a fresh adapter rejects an already expired schedule
assert(next(adapter.inbox().acceptances.entries) == nil)
stop2()
print(
	"CAST RECEIPT CLIENT: PASS (actual adapter; registration, vectors/clocks, duplicate, disposition, terminal/contact permutations, actual listener -> once-only command/style/cleanup, late contacts, duplicate/expiry, teardown/restart)"
)
