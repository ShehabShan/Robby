--!strict
-- Owns the primary clock gate and separate essential world-warning reserve.
-- Pure orchestration only. The engine adapter must classify canonical accepted
-- cues before admission; never feed contacts or predictions to the reserve.
local Bridge = require("./CastBridge")
local Gate = require("./CastClockGate")
local Reserve = require("./CastWarningReserve")
local Presentation = require("./CastPresentation")
local CastWarningGate = {}
export type Policy = {
	presentation: Presentation.Policy,
	perCast: number,
	clock: Gate.Policy,
	warning: Presentation.Policy,
	warningPerCast: number,
}
export type State = {
	gate: Gate.State,
	reserve: Reserve.State,
	busy: boolean,
	closed: boolean,
	cancelling: string?,
	fallbacks: number,
	refusals: number,
}
function CastWarningGate.new(policy: Policy, render: Bridge.Renderer, warning: Reserve.Renderer): State
	assert(
		policy.warning.maxLifetimeSeconds >= policy.presentation.maxLifetimeSeconds,
		"warning must cover primary lifetime"
	)
	assert(
		policy.warning.tombstoneSeconds >= policy.presentation.tombstoneSeconds,
		"warning must cover primary terminals"
	)
	local reserve = Reserve.new(policy.warning, policy.warningPerCast, warning)
	local s: State
	local bridge = Bridge.new(policy.presentation, policy.perCast, render, function(key, timeline, now)
		-- Called for immediate starts, delayed gate drains AND later seek failures.
		-- A terminal being processed cannot flash a fallback during gate advancement.
		if s.cancelling ~= key then
			s.fallbacks += 1
			Reserve.accept(reserve, key, timeline, now)
		end
	end)
	s = {
		gate = Gate.new(bridge, policy.clock),
		reserve = reserve,
		busy = false,
		closed = false,
		cancelling = nil,
		fallbacks = 0,
		refusals = 0,
	}
	return s
end
local function finite(n: number): boolean
	return n == n and math.abs(n) < math.huge
end
local function begin(s: State, localNow: number, serverNow: number): boolean
	if
		s.closed
		or s.busy
		or not finite(localNow)
		or (s.gate.lastLocal ~= nil and localNow < s.gate.lastLocal)
		or (s.gate.now == nil and not finite(serverNow))
	then
		s.refusals += 1
		return false
	end
	s.busy = true
	return true
end
local function finish(s: State)
	if s.gate.now then
		Reserve.tick(s.reserve, s.gate.now)
	end
	s.cancelling = nil
	s.busy = false
end
function CastWarningGate.accept(
	s: State,
	key: string,
	timeline: Presentation.Timeline,
	localNow: number,
	serverNow: number
): string
	if not begin(s, localNow, serverNow) then
		return "refuse"
	end
	local outcome
	-- A refused normal start must not later coexist with its reserve warning or
	-- resurrect it after fallback failure. The reserve owns that key until expiry.
	if s.reserve.bridge.presentation.entries[key] then
		Gate.tick(s.gate, localNow, serverNow)
		outcome = "ignore"
	else
		outcome = Gate.accept(s.gate, key, timeline, localNow, serverNow)
	end
	finish(s)
	return outcome -- primary admission outcome; reserve counters report degradation
end
function CastWarningGate.predict(s: State, key: string, localNow: number, serverNow: number): string
	if not begin(s, localNow, serverNow) then
		return "refuse"
	end
	local outcome
	if s.reserve.bridge.presentation.entries[key] then
		Gate.tick(s.gate, localNow, serverNow)
		outcome = "ignore"
	else
		outcome = Gate.predict(s.gate, key, localNow, serverNow)
	end
	finish(s)
	return outcome
end
function CastWarningGate.tick(s: State, localNow: number, serverNow: number): boolean
	if not begin(s, localNow, serverNow) then
		return false
	end
	local ok = Gate.tick(s.gate, localNow, serverNow)
	finish(s)
	return ok -- clock processing, NOT a guarantee of visible warnings
end
-- Cancel a whole borrowed-inbox snapshot without seeking any cancelled key.
function CastWarningGate.cancelMany(s: State, keys: { [string]: boolean }, localNow: number, serverNow: number): boolean
	if not begin(s, localNow, serverNow) then
		return false
	end
	local ok = Gate.cancelMany(s.gate, keys, localNow, serverNow)
	if ok and s.gate.now then
		for key in keys do
			if s.reserve.bridge.presentation.entries[key] then
				Reserve.cancel(s.reserve, key, s.gate.now)
			end
		end
	end
	finish(s)
	return ok
end
function CastWarningGate.cancel(s: State, key: string, localNow: number, serverNow: number): string
	if not begin(s, localNow, serverNow) then
		return "refuse"
	end
	s.cancelling = key
	local outcome = Gate.cancel(s.gate, key, localNow, serverNow)
	-- Primary gate already retains unknown terminals and overflow watermarks.
	-- Do not consume the independent reserve with healthy-only cancellations.
	if s.gate.now and s.reserve.bridge.presentation.entries[key] then
		Reserve.cancel(s.reserve, key, s.gate.now)
	end
	finish(s)
	return outcome
end
function CastWarningGate.retirePose(s: State, key: string, localNow: number, serverNow: number): boolean
	if not begin(s, localNow, serverNow) then
		return false
	end
	local retired = Gate.retirePose(s.gate, key, localNow, serverNow)
	finish(s) -- reserve is world-only; local death cannot cancel accepted hazards
	return retired
end
function CastWarningGate.destroy(s: State): boolean
	if s.closed then
		return true
	end
	if s.busy then
		s.refusals += 1
		return false
	end
	s.closed = true
	s.busy = true
	Gate.destroy(s.gate)
	Reserve.destroy(s.reserve)
	s.busy = false
	return true
end
return CastWarningGate
