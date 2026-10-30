--!strict
-- Effects (SCHEMAS §4, D-052): the only way state changes. Pure rules; dependencies come in as arguments
-- (the tag library and an op handler), so this module never requires a service or another module.

export type TagSet = { [string]: number }
export type TagLib = {
	add: (TagSet, string) -> (),
	remove: (TagSet, string) -> (),
	hasAll: (TagSet, { string }?) -> boolean,
	hasAny: (TagSet, { string }?) -> boolean,
}
export type Bucket = "Add" | "Boost" | "Surge" | "Override"
export type Modifier = { attr: string, bucket: Bucket, value: number, requireTags: { string }? }
export type Op = { kind: string, params: { [string]: any }? }
export type Stack = { cap: number, by: "source" | "target", refresh: boolean }
export type Effect = {
	id: string,
	duration: "Inst" | "Timed" | "Chan" | "Pers",
	seconds: number?,
	period: number?,
	stack: Stack?,
	modifiers: { Modifier }?,
	ops: { Op }?,
	grantTags: { string }?,
	removeTags: { string }?,
	requireTags: { string }?,
	blockTags: { string }?,
	fx: string?,
}
export type Active = {
	effectId: string,
	sourceUid: string,
	stacks: number,
	endsAt: number?,
	nextTickAt: number?,
}
export type Holder = { tags: TagSet, active: { Active } }
export type OpHandler = (op: Op, effect: Effect, stacks: number, sourceUid: string) -> ()
export type Lookup = (effectId: string) -> Effect?
export type Ctx = { now: number, tags: TagLib, onOp: OpHandler? }

local Effects = {}

Effects.MIN_PERIOD = 0.5 -- server tick budget (R-021 §6)

function Effects.newHolder(tags: TagSet?): Holder
	return { tags = tags or {}, active = {} }
end

local function runOps(effect: Effect, stacks: number, sourceUid: string, ctx: Ctx)
	local ops = effect.ops
	local onOp = ctx.onOp
	if ops and onOp then
		for _, op in ops do
			onOp(op, effect, stacks, sourceUid)
		end
	end
end

local function setTags(holder: Holder, list: { string }?, ctx: Ctx, adding: boolean)
	if list then
		for _, tag in list do
			if adding then
				ctx.tags.add(holder.tags, tag)
			else
				ctx.tags.remove(holder.tags, tag)
			end
		end
	end
end

-- No stack rule = one instance per source, refreshed on re-apply.
local function find(holder: Holder, effect: Effect, sourceUid: string): Active?
	local st = effect.stack
	local shared = st ~= nil and st.by == "target"
	for _, a in holder.active do
		if a.effectId == effect.id and (shared or a.sourceUid == sourceUid) then
			return a
		end
	end
	return nil
end

-- Returns false when the target's tags reject the effect (requireTags / blockTags).
function Effects.apply(holder: Holder, effect: Effect, sourceUid: string, ctx: Ctx): boolean
	if not ctx.tags.hasAll(holder.tags, effect.requireTags) then
		return false
	end
	if ctx.tags.hasAny(holder.tags, effect.blockTags) then
		return false
	end
	setTags(holder, effect.removeTags, ctx, false)
	if effect.duration == "Inst" then
		runOps(effect, 1, sourceUid, ctx)
		return true
	end
	local seconds = effect.seconds
	local existing = find(holder, effect, sourceUid)
	if existing then
		local st = effect.stack
		local cap = if st then st.cap else 1
		existing.stacks = math.min(existing.stacks + 1, cap)
		if (st == nil or st.refresh) and seconds and effect.duration ~= "Pers" then
			existing.endsAt = ctx.now + seconds
		end
		return true
	end
	local period = effect.period
	table.insert(holder.active, {
		effectId = effect.id,
		sourceUid = sourceUid,
		stacks = 1,
		endsAt = if effect.duration ~= "Pers" and seconds then ctx.now + seconds else nil,
		nextTickAt = if period then ctx.now + math.max(period, Effects.MIN_PERIOD) else nil,
	})
	setTags(holder, effect.grantTags, ctx, true)
	return true
end

local function drop(holder: Holder, index: number, effect: Effect?, ctx: Ctx)
	table.remove(holder.active, index)
	if effect then
		setTags(holder, effect.grantTags, ctx, false)
	end
end

-- Fires due periodic ops (catching up after a long gap) and expires finished effects.
function Effects.tick(holder: Holder, lookup: Lookup, ctx: Ctx)
	for i = #holder.active, 1, -1 do
		local a = holder.active[i]
		local effect = lookup(a.effectId)
		if effect == nil then
			drop(holder, i, nil, ctx) -- retired content: drop silently
			continue
		end
		local period = effect.period
		if period then
			local step = math.max(period, Effects.MIN_PERIOD)
			local nextAt = a.nextTickAt
			while nextAt ~= nil and nextAt <= ctx.now and (a.endsAt == nil or nextAt <= (a.endsAt :: number)) do
				runOps(effect, a.stacks, a.sourceUid, ctx)
				nextAt += step
			end
			a.nextTickAt = nextAt
		end
		local endsAt = a.endsAt
		if endsAt ~= nil and endsAt <= ctx.now then
			drop(holder, i, effect, ctx)
		end
	end
end

-- Dispel / channel cancel. Removes every instance of the id (or only one source's). Returns the count.
function Effects.remove(holder: Holder, effectId: string, lookup: Lookup, ctx: Ctx, sourceUid: string?): number
	local n = 0
	for i = #holder.active, 1, -1 do
		local a = holder.active[i]
		if a.effectId == effectId and (sourceUid == nil or a.sourceUid == sourceUid) then
			drop(holder, i, lookup(effectId), ctx)
			n += 1
		end
	end
	return n
end

-- Active modifiers for Stats.compute, scaled by stacks (Add/Boost × n, Surge ^ n).
function Effects.modifiers(holder: Holder, lookup: Lookup): { Modifier }
	local out: { Modifier } = {}
	for _, a in holder.active do
		local effect = lookup(a.effectId)
		local mods = effect and effect.modifiers
		if mods then
			for _, m in mods do
				local value = m.value
				if m.bucket == "Add" or m.bucket == "Boost" then
					value *= a.stacks
				elseif m.bucket == "Surge" then
					value = value ^ a.stacks
				end
				table.insert(out, { attr = m.attr, bucket = m.bucket, value = value, requireTags = m.requireTags })
			end
		end
	end
	return out
end

return Effects
