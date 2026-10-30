--!strict
-- Tag sets (SCHEMAS §3): hierarchical strings with counts. Pure rules. No Roblox services.
-- `has(set, "State")` matches "State" and every child such as "State.Guarding".

export type TagSet = { [string]: number }

local Tags = {}

function Tags.new(list: { string }?): TagSet
	local set: TagSet = {}
	if list then
		for _, tag in list do
			Tags.add(set, tag)
		end
	end
	return set
end

function Tags.add(set: TagSet, tag: string)
	set[tag] = (set[tag] or 0) + 1
end

-- Counted: two sources of the same tag need two removals.
function Tags.remove(set: TagSet, tag: string)
	local n = set[tag]
	if n == nil then
		return
	end
	if n <= 1 then
		set[tag] = nil
	else
		set[tag] = n - 1
	end
end

function Tags.has(set: TagSet, tag: string): boolean
	if set[tag] ~= nil then
		return true
	end
	local prefix = tag .. "."
	for t in set do
		if string.sub(t, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

function Tags.hasAll(set: TagSet, list: { string }?): boolean
	if list then
		for _, tag in list do
			if not Tags.has(set, tag) then
				return false
			end
		end
	end
	return true
end

function Tags.hasAny(set: TagSet, list: { string }?): boolean
	if list then
		for _, tag in list do
			if Tags.has(set, tag) then
				return true
			end
		end
	end
	return false
end

return Tags
