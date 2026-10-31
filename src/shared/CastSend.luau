--!strict
-- Shared input sender. One allocator per connection; optional cosmetics NEVER gate gameplay.
-- No retries: a transport error can mean the server already received a paid request.
local Request = require("./CastRequest")
local Identity = require("./CastCharacterIdentity")
local Send = {}
export type Dependencies = {
	ready: () -> boolean,
	generation: () -> string?,
	fire: (any) -> (),
	snapshot: (() -> Identity.Value?)?,
	predict: ((string, Identity.Value) -> ())?,
}
function Send.new(deps: Dependencies): (string, any, any?) -> (string, string?)
	local nextSeq = Request.allocator()
	return function(moveId: string, aim: any, point: any?): (string, string?)
		if not deps.ready() then
			return "unready", nil
		end
		local generation = deps.generation()
		if not generation or #generation == 0 then
			return "unready", nil
		end
		local seq = nextSeq()
		local key = generation .. ":" .. tostring(seq)
		-- Capture original cosmetic identity before transport; protect it from callback mutation.
		local identity: Identity.Value? = nil
		if deps.predict and deps.snapshot then
			local ok, value = pcall(deps.snapshot)
			if ok and value and Identity.valid(value) and value.generation == generation then
				identity = table.freeze(table.clone(value))
			end
		end
		local sent = pcall(deps.fire, { moveId = moveId, aim = aim, point = point, seq = seq, generation = generation })
		if not sent then
			return "transport_uncertain", key
		end
		if identity and deps.predict then
			-- Cosmetic failure, stale identity or exhausted pools must not resend or refund.
			pcall(deps.predict, key, identity)
		end
		return "sent", key
	end
end
return Send
