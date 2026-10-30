--!strict
-- Player profile schema (SCHEMAS §7, D-047, T-002d1). Load = migrate → reconcile → validate.
-- Pure: the DataService (ProfileStore) calls `load` and saves the result. No player data is
-- ever dropped (D-042): unknown or retired ids stay in the save and are reported as issues.

-- Retired ids are resolved through an injected `resolve` (the server passes Retired.resolve),
-- so this module stays dependency-free like the rest of src/shared.
export type Resolve = (id: string) -> (string?, boolean)

local function keep(id: string): (string?, boolean)
	return id, false
end

export type Migration = { from: number, to: number, run: (data: any) -> () }

local TALENTS = { A = true, B = true, C = true, D = true }

local ProfileSchema = {}

ProfileSchema.VERSION = 1

-- The default profile for a new player. Talent is rolled by the server at creation.
function ProfileSchema.template(): any
	return {
		schemaVersion = ProfileSchema.VERSION,
		talent = "C",
		rank = 1,
		stage = 1,
		cores = { {} },
		marks = {},
		imprints = {},
		kith = {},
		loadout = { slots = {}, weaves = {} },
		journal = { recipes = {}, weaves = {}, codex = {} },
		wallet = { shards = 0 },
		timers = {},
		onboarding = { step = 0, done = false },
		stats = { earned = {}, spent = {} },
		receipts = {},
		settings = {},
	}
end

-- Ordered migrations. A save with no `schemaVersion` is version 0 (pre-schema test data).
-- Every past version must have a Lune test that migrates it to VERSION.
ProfileSchema.migrations = {
	{
		from = 0,
		to = 1,
		run = function(data: any)
			data.schemaVersion = 1
		end,
	},
} :: { Migration }

-- Runs migrations in order. Returns (ok, err). A save from a newer version is refused untouched,
-- so an old server can never overwrite newer data.
function ProfileSchema.migrate(data: any): (boolean, string?)
	local v = data.schemaVersion
	if v == nil then
		v = 0
	end
	if typeof(v) ~= "number" or v % 1 ~= 0 or v < 0 then
		return false, "bad schemaVersion"
	end
	if v > ProfileSchema.VERSION then
		return false, `save is newer (v{v}) than this server (v{ProfileSchema.VERSION})`
	end
	while v < ProfileSchema.VERSION do
		local step: Migration? = nil
		for _, m in ProfileSchema.migrations do
			if m.from == v then
				step = m
				break
			end
		end
		if step == nil then
			return false, `no migration from v{v}`
		end
		step.run(data)
		v = step.to
		data.schemaVersion = v
	end
	return true, nil
end

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

-- Fills keys missing from `data` with template defaults (recursing into nested tables).
-- Existing values are never overwritten; a wrong-typed value is replaced and reported.
function ProfileSchema.reconcile(data: any, template: any?, path: string?, issues: { string }?): { string }
	local t = template or ProfileSchema.template()
	local list: { string } = issues or {}
	for k, default in t do
		if typeof(k) ~= "string" then
			continue -- list entries (e.g. the default core) are data, not schema keys
		end
		local here = if path then `{path}.{k}` else tostring(k)
		local current = data[k]
		if current == nil then
			data[k] = deepCopy(default)
		elseif typeof(current) ~= typeof(default) then
			table.insert(list, `{here}: wrong type {typeof(current)}, reset to default`)
			data[k] = deepCopy(default)
		elseif typeof(default) == "table" and typeof(k) == "string" then
			ProfileSchema.reconcile(current, default, here, list)
		end
	end
	return list
end

local function wholeAtLeast(n: any, min: number): boolean
	return typeof(n) == "number" and n == n and n % 1 == 0 and n >= min
end

-- Checks values and fixes only what is safe to fix. Retired Kith species are remapped to their
-- replacement; with no replacement the Kith is kept as-is and reported. Returns issues.
function ProfileSchema.validate(data: any, resolve: Resolve?): { string }
	local resolveId: Resolve = resolve or keep
	local issues: { string } = {}
	if not TALENTS[data.talent] then
		table.insert(issues, `talent: {tostring(data.talent)} → C`)
		data.talent = "C"
	end
	for _, field in { "rank", "stage" } do
		if not wholeAtLeast(data[field], 1) then
			table.insert(issues, `{field}: {tostring(data[field])} → 1`)
			data[field] = 1
		end
	end
	if #data.cores < 1 then
		table.insert(issues, "cores: empty → one core")
		table.insert(data.cores, {})
	end
	for tier, amount in data.wallet do
		if typeof(amount) ~= "number" or amount ~= amount or amount < 0 then
			table.insert(issues, `wallet.{tostring(tier)}: {tostring(amount)} → 0`)
			data.wallet[tier] = 0
		end
	end
	for uid, inst in data.kith do
		if typeof(inst) == "table" and typeof(inst.speciesId) == "string" then
			local live, retired = resolveId(inst.speciesId)
			if retired and live then
				table.insert(issues, `kith.{tostring(uid)}: {inst.speciesId} → {live}`)
				inst.speciesId = live
			elseif retired then
				table.insert(issues, `kith.{tostring(uid)}: {inst.speciesId} retired, no replacement (kept)`)
			end
		else
			table.insert(issues, `kith.{tostring(uid)}: malformed (kept)`)
		end
	end
	return issues
end

-- Full load pipeline for a raw saved table (or nil for a new player).
-- Returns (profile or nil, issues). nil means "do not use or save this profile".
function ProfileSchema.load(raw: any, resolve: Resolve?): (any, { string })
	if raw == nil then
		return ProfileSchema.template(), {}
	end
	if typeof(raw) ~= "table" then
		return nil, { "save is not a table" }
	end
	local ok, err = ProfileSchema.migrate(raw)
	if not ok then
		return nil, { err or "migration failed" }
	end
	local issues = ProfileSchema.reconcile(raw)
	for _, issue in ProfileSchema.validate(raw, resolve) do
		table.insert(issues, issue)
	end
	return raw, issues
end

return ProfileSchema
