--!strict
-- Stateless seek plan for an admitted frame. Owns no resources/clocks/replays.
-- Only outer CastWarningGate may authorize rendering. Never infers a hit.
local Geometry = require("./CastGeometry")
local Receipts = require("./CastReceipts")
local Map = require("./CastCommandMap")
local Presentation = require("./CastPresentation")
local Volley = require("./Deliveries/Volley")
local Plan = {}
export type Identity = { generation: string, characterKey: string, slotRevision: number, casterUserId: number }
export type Pose = {
	generation: string,
	characterKey: string,
	slotRevision: number,
	casterUserId: number,
	alive: boolean,
}
export type Shape = {
	slot: string,
	kind: string,
	position: Receipts.Vec,
	direction: Receipts.Vec?,
	size: Receipts.Vec?,
	radius: number?,
}
export type Frame = { phase: string, progress: number, speculative: boolean, pose: boolean, world: { Shape } }
local function finite(n: any): boolean
	return type(n) == "number" and n == n and math.abs(n) < math.huge
end
local function vector(v: any): boolean
	return type(v) == "table" and finite(v.x) and finite(v.y) and finite(v.z)
end
local function vec(x: number, y: number, z: number): Receipts.Vec
	return table.freeze({ x = x, y = y, z = z })
end
function Plan.poseEligible(identity: Identity, pose: Pose?, allowed: boolean): boolean
	return allowed
		and pose ~= nil
		and pose.alive == true
		and #identity.generation > 0
		and #identity.characterKey > 0
		and identity.generation == pose.generation
		and identity.characterKey == pose.characterKey
		and identity.slotRevision == pose.slotRevision
		and identity.casterUserId == pose.casterUserId
end
-- Prediction is a reversible current-character anticipation ONLY. No speculative
-- area, projectile, damage label, contact burst or base-catalog world geometry.
function Plan.predicted(identity: Identity, pose: Pose?, allowed: boolean): Frame
	return table.freeze({
		phase = "predicted",
		progress = 0,
		speculative = true,
		pose = Plan.poseEligible(identity, pose, allowed),
		world = table.freeze({}),
	})
end
-- Metadata must come from an immutable validated receipt. now is the OUTER gate's
-- admitted common clock, not a fresh workspace/OS sample. Late starts seek directly.
function Plan.accepted(metadata: Map.Metadata, now: number, pose: Pose?, allowed: boolean): (Frame?, string?)
	local a, style = metadata.acceptance, metadata.style
	local g = a.geometry
	if not g or not Geometry.valid(g) or g.kind ~= style.delivery then
		return nil, "geometry"
	end
	if
		not finite(now)
		or not finite(a.acceptedAt)
		or not finite(a.releaseAt)
		or not finite(a.endsAt)
		or a.releaseAt < a.acceptedAt
		or a.endsAt < a.releaseAt
	then
		return nil, "clock"
	end
	if now < a.acceptedAt then
		return nil, "future"
	end
	if now >= a.endsAt then
		return nil, "expired"
	end
	if not vector(a.origin) or not vector(a.aim) then
		return nil, "position"
	end
	-- Legacy Burst selects around the original caster at release. A static captured
	-- origin, or a replacement character's pose, is not its authoritative centre.
	if g.centreMode == "CasterAtRelease" then
		return nil, "moving_centre"
	end
	local timeline = {
		acceptedAt = a.acceptedAt,
		releaseAt = a.releaseAt,
		endsAt = a.endsAt,
		x = a.origin.x,
		y = a.origin.y,
		z = a.origin.z,
	}
	local phase, progress = Presentation.phase(timeline, now)
	local world: { Shape } = {}
	if g.kind == "Projectile" or g.kind == "Volley" then
		local magnitude = math.sqrt(a.aim.x * a.aim.x + a.aim.z * a.aim.z)
		if not finite(magnitude) or math.abs(magnitude - 1) > 0.01 or math.abs(a.aim.y) > 0.001 then
			return nil, "aim"
		end
		local directions = Volley.directions(a.aim.x, a.aim.z, {
			count = g.count,
			spreadDeg = g.spreadDeg,
			speed = g.speed,
			range = g.range,
			maxHits = 1,
			perTargetCap = 1,
		})
		local distance = math.min(g.range, math.max(0, now - a.releaseAt) * g.speed)
		for i, d in directions do
			local position = vec(a.origin.x + d.x * distance, a.origin.y, a.origin.z + d.z * distance)
			if not vector(position) then
				return nil, "position"
			end
			table.insert(
				world,
				table.freeze({
					slot = "shot:" .. tostring(i),
					kind = "Box",
					position = position,
					direction = vec(d.x, 0, d.z),
					size = vec(g.hitboxX, g.hitboxY, g.hitboxZ),
				})
			)
		end
	elseif g.kind == "Zone" then
		if not a.centre or not vector(a.centre) then
			return nil, "centre"
		end
		table.insert(
			world,
			table.freeze({
				slot = "zone",
				kind = "Disc",
				position = vec(a.centre.x, a.centre.y, a.centre.z),
				radius = g.radius,
			})
		)
	end
	return table.freeze({
		phase = phase,
		progress = progress,
		speculative = false,
		pose = Plan.poseEligible(a, pose, allowed),
		world = table.freeze(world),
	}),
		nil
end
return Plan
