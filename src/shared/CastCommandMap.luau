--!strict
-- Stateless cosmetic mapping of VALIDATED immutable inbox receipts. Does not
-- admit raw network payloads, retain a second receipt cache, or infer a hit.
local Receipts = require("./CastReceipts")
local Contacts = require("./CastContacts")
local Presentation = require("./CastPresentation")
local CastCommandMap = {}
export type Style = { delivery: string, castFx: string?, travelFx: string?, hitFx: string?, worldWarning: boolean }
export type Catalog = { [string]: Style }
export type Metadata = { acceptance: Receipts.Acceptance, style: Style }
export type Accepted = { key: string, timeline: Presentation.Timeline, metadata: Metadata }
export type Contact = { action: string, receipt: Contacts.Contact, metadata: Metadata?, delivery: string, fx: string? }
local SUPPORTED = table.freeze({ Projectile = true, Volley = true, Zone = true, Burst = true, Self = true })
local function fx(value: any): string?
	return if type(value) == "string" and #value > 0 and #value <= 128 then value else nil
end
-- Snapshot only presentation routing. Never copy base delivery timing/range/radius
-- as if it were the accepted woven cast's geometry or authoritative schedule.
function CastCommandMap.catalog(moves: { [string]: any }): Catalog
	local out: Catalog = {}
	for id, move in moves do
		local delivery = if type(move.delivery) == "table" then move.delivery.kind else nil
		if move.id == id and SUPPORTED[delivery] then
			local effects = if type(move.fx) == "table" then move.fx else {}
			out[id] = table.freeze({
				delivery = delivery,
				castFx = fx(effects.cast),
				travelFx = fx(effects.travel),
				hitFx = fx(effects.hit),
				worldWarning = delivery ~= "Self",
			})
		end
	end
	return table.freeze(out)
end
local function metadata(catalog: Catalog, acceptance: Receipts.Acceptance?): Metadata?
	if not acceptance then
		return nil
	end
	local style = catalog[acceptance.moveId]
	return if style then table.freeze({ acceptance = acceptance, style = style }) else nil
end
-- Caller still applies expiry/clock/terminal admission through CastWarningGate.
-- Returning a timeline never authorizes a contact, damage or new gameplay timing.
function CastCommandMap.accepted(catalog: Catalog, entry: Receipts.Entry): Accepted?
	if entry.terminal or not entry.acceptance then
		return nil
	end
	local a = entry.acceptance
	local m = metadata(catalog, a)
	if not m then
		return nil
	end
	-- Zone warnings must not silently use caster origin when their ground centre is
	-- absent. Projectiles originate at the captured origin; bursts prefer centre.
	if m.style.delivery == "Zone" and not a.centre then
		return nil
	end
	local point = if m.style.delivery == "Zone" or m.style.delivery == "Burst" then a.centre or a.origin else a.origin
	return table.freeze({
		key = a.castId,
		metadata = m,
		timeline = table.freeze({
			acceptedAt = a.acceptedAt,
			releaseAt = a.releaseAt,
			endsAt = a.endsAt,
			x = point.x,
			y = point.y,
			z = point.z,
		}),
	})
end
-- Render a confirmed contact NOW even with no acceptance, unknown content or a
-- terminal-only receipt. Generic is a real confirmed impact, never a prediction.
-- A retained acceptance after terminal is useful STYLE metadata, not permission.
function CastCommandMap.contact(catalog: Catalog, value: Contacts.Contact, entry: Receipts.Entry?): Contact
	local a = if entry then entry.acceptance else nil
	local m = if a and a.castId == value.castId then metadata(catalog, a) else nil
	return table.freeze({
		action = "contact",
		receipt = value,
		metadata = m,
		delivery = if m then m.style.delivery else "Generic",
		fx = if m then m.style.hitFx else nil,
	})
end
return CastCommandMap
