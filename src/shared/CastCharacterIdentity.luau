--!strict
-- Cosmetic replica only. One bounded atomic value prevents mixed generation/slot fields.
local Identity = {}
Identity.attribute = "CastCharacterIdentityV1"
export type Value = { generation: string, characterKey: string, slotRevision: number, casterUserId: number }
local function integer(v: any, max: number): boolean
	return type(v) == "number" and v == v and v >= 0 and v <= max and v % 1 == 0
end
function Identity.valid(v: any): boolean
	return type(v) == "table"
		and type(v.generation) == "string"
		and #v.generation > 0
		and #v.generation <= 64
		and type(v.characterKey) == "string"
		and #v.characterKey > 0
		and #v.characterKey <= 64
		and integer(v.slotRevision, 4294967295)
		and integer(v.casterUserId, 9007199254740991)
end
function Identity.encode(v: Value): string?
	if not Identity.valid(v) then
		return nil
	end
	return string.format(
		"%d:%s%d:%s%.0f:%.0f",
		#v.generation,
		v.generation,
		#v.characterKey,
		v.characterKey,
		v.casterUserId,
		v.slotRevision
	)
end
function Identity.decode(raw: any): Value?
	if type(raw) ~= "string" or #raw > 192 then
		return nil
	end
	local cursor = 1
	local function text(): string?
		local digits, start = string.match(raw, "^(%d+):()", cursor)
		local length = if digits then tonumber(digits) else nil
		if not length or not start or length < 1 or length > 64 then
			return nil
		end
		local value = string.sub(raw, start, start + length - 1)
		cursor = start + length
		return value
	end
	local generation, characterKey = text(), text()
	local user, slot = string.match(string.sub(raw, cursor), "^(%d+):(%d+)$")
	local value = {
		generation = generation,
		characterKey = characterKey,
		casterUserId = tonumber(user),
		slotRevision = tonumber(slot),
	}
	if not Identity.valid(value) or Identity.encode(value :: any) ~= raw then
		return nil
	end
	return table.freeze(value) :: any
end
function Identity.matches(a: Value, b: Value): boolean
	return Identity.valid(a)
		and Identity.valid(b)
		and a.generation == b.generation
		and a.characterKey == b.characterKey
		and a.casterUserId == b.casterUserId
		and a.slotRevision == b.slotRevision
end
return Identity
