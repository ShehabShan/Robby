--!strict
-- CastRequest payload rules (T-002c4, SCHEMAS §9): C→S `moveId: string, aim: vector, point: vector?, seq: u16`.
-- `point` is the aimed ground point for `target = "Point"` moves (T-027d1); the server checks it with Zone.isValidPoint.
-- Pure: the server checks aim (a Vector3) itself; this validates moveId against built Content and seq as u16.

local MAX_ID = 64
local U16 = 65536

local CastRequest = {}

-- Returns the Move and seq for a valid request, or nil for anything malformed or unknown.
function CastRequest.decode(moveId: unknown, seq: unknown, moves: { [string]: any }): (any, number?)
	if typeof(moveId) ~= "string" or #moveId > MAX_ID then
		return nil, nil
	end
	if typeof(seq) ~= "number" or seq ~= seq or seq % 1 ~= 0 or seq < 0 or seq >= U16 then
		return nil, nil
	end
	local move = moves[moveId]
	if move == nil then
		return nil, nil
	end
	return move, seq
end

-- Next client sequence number, wrapping at u16.
function CastRequest.nextSeq(seq: number): number
	return (seq + 1) % U16
end

return CastRequest
