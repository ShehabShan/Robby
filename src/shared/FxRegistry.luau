--!strict
-- FX registry (T-002c4, SCHEMAS §5/§9): maps the fx ids named in Content (Move.fx, Effect.fx)
-- to client handlers. CastFx/HitFx carry an fx id; the client looks it up here.
-- Pure: no services, so it is tested under Lune. Unknown ids and failing handlers never throw.

export type Handler = (ctx: any) -> ()
export type Registry = {
	handlers: { [string]: Handler },
	missing: { [string]: number },
}

local MAX_ID = 64

local FxRegistry = {}

-- Fx ids look like `fx.<kith>.<slot>` (e.g. `fx.crescent.hit`).
function FxRegistry.isValidId(id: unknown): boolean
	return typeof(id) == "string" and #id <= MAX_ID and string.match(id, "^fx%.[%w_]+%.[%w_]+$") ~= nil
end

function FxRegistry.new(): Registry
	return { handlers = {}, missing = {} }
end

-- Returns false for a malformed or already-registered id (first registration wins).
function FxRegistry.register(reg: Registry, id: string, handler: Handler): boolean
	if not FxRegistry.isValidId(id) or reg.handlers[id] ~= nil then
		return false
	end
	reg.handlers[id] = handler
	return true
end

-- Plays the handler for `id`. Returns false when none is registered (the id is counted in
-- `missing`) or when the handler errors; a broken effect must never break gameplay.
function FxRegistry.play(reg: Registry, id: unknown, ctx: any): boolean
	if typeof(id) ~= "string" then
		return false
	end
	local handler = reg.handlers[id]
	if handler == nil then
		if FxRegistry.isValidId(id) then
			reg.missing[id] = (reg.missing[id] or 0) + 1
		end
		return false
	end
	local ok = pcall(handler, ctx)
	return ok
end

-- Fx ids referenced by built Content (Registry.build) that have no handler, sorted.
function FxRegistry.missingFor(reg: Registry, built: any): { string }
	local seen: { [string]: boolean } = {}
	local out: { string } = {}
	local function check(id: unknown)
		if typeof(id) == "string" and reg.handlers[id] == nil and not seen[id] then
			seen[id] = true
			table.insert(out, id)
		end
	end
	for _, move in built.moves or {} do
		for _, id in move.fx or {} do
			check(id)
		end
	end
	for _, effect in built.effects or {} do
		check(effect.fx)
	end
	table.sort(out)
	return out
end

return FxRegistry
