--!strict
-- Independent bounded reserve for essential world warnings, NOT live-wired.
-- The caller supplies only canonical accepted cues, never predictions or contacts.
-- Own this reserve exclusively; tick it even without packets. All callbacks are non-yielding.
local Bridge = require("./CastBridge")
local Presentation = require("./CastPresentation")
local Resources = require("./CastResources")
local CastWarningReserve = {}
export type Frame = {
	key: string,
	action: string,
	now: number,
	timeline: Presentation.Timeline,
	phase: string,
	progress: number,
	bind: (string, () -> ()) -> Resources.Ticket?,
	isCurrent: (Resources.Ticket) -> boolean,
	release: (Resources.Ticket) -> boolean,
}
export type Renderer = (Frame) -> boolean
export type State = { bridge: Bridge.State, offers: number, refusals: number }
function CastWarningReserve.new(policy: Presentation.Policy, perCast: number, render: Renderer): State
	local bridge = Bridge.new(policy, perCast, function(frame: Bridge.Frame): boolean
		local timeline = frame.timeline
		if not timeline then
			return false
		end
		-- No pose scope, pose lease or prediction command crosses this boundary.
		-- Active means a remaining world hazard, NOT evidence of a confirmed hit.
		return render(table.freeze({
			key = frame.key,
			action = frame.action,
			now = frame.now,
			timeline = timeline,
			phase = frame.phase,
			progress = frame.progress,
			bind = function(slot: string, dispose: () -> ()): Resources.Ticket?
				return frame.bind(slot, "world", dispose)
			end,
			isCurrent = frame.isCurrent,
			release = frame.release,
		}))
	end)
	return { bridge = bridge, offers = 0, refusals = 0 }
end
function CastWarningReserve.accept(s: State, key: string, timeline: Presentation.Timeline, now: number): string
	s.offers += 1
	local outcome = Bridge.accept(s.bridge, key, timeline, now)
	if outcome == "refuse" then
		-- Includes malformed/time/refused offers; detailed renderer/resource/cleanup
		-- failure counters remain on bridge/resources, never hidden as success.
		s.refusals += 1
	end
	return outcome
end
function CastWarningReserve.tick(s: State, now: number): boolean
	return Bridge.tick(s.bridge, now)
end
function CastWarningReserve.cancel(s: State, key: string, now: number): string
	return Bridge.cancel(s.bridge, key, now)
end
function CastWarningReserve.destroy(s: State): boolean
	return Bridge.destroy(s.bridge)
end
return CastWarningReserve
