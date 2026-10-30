--!strict
-- Timed status tags per entity (T-015b, D-062): `State.Warded` (Stone Ward) and `State.Iframes` (Wind Step).
-- Pure: no services, so it is tested under Lune. The server passes its clock (`now`) in.

export type Statuses = { [any]: { [string]: number } }

local NEVER = -math.huge
local BLOCKING = { "State.Warded", "State.Iframes" }

local Status = {}

function Status.new(): Statuses
	return {}
end

-- Grants `tag` to `who` until `untilTime`; a longer existing grant is kept.
function Status.grant(s: Statuses, who: any, tag: string, untilTime: number)
	local t = s[who]
	if not t then
		t = {}
		s[who] = t
	end
	t[tag] = math.max(t[tag] or NEVER, untilTime)
end

function Status.has(s: Statuses, who: any, tag: string, now: number): boolean
	local t = s[who]
	return t ~= nil and (t[tag] or NEVER) > now
end

-- True while a ward or i-frames make `who` ignore incoming hits.
function Status.blocksHit(s: Statuses, who: any, now: number): boolean
	for _, tag in BLOCKING do
		if Status.has(s, who, tag, now) then
			return true
		end
	end
	return false
end

function Status.clear(s: Statuses, who: any)
	s[who] = nil
end

return Status
