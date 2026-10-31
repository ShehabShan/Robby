--!strict
-- Fresh, non-yielding cosmetic lookup. Never caches a replacement or labels it from a receipt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Identity = require(ReplicatedStorage.Shared.CastCharacterIdentity)
local Plan = require(ReplicatedStorage.Shared.CastDeliveryPlan)
local Client = {}
function Client.snapshot(player: Player): (Model?, Identity.Value?)
	if player.Parent ~= Players then
		return nil, nil
	end
	local character = player.Character
	if not character or not character:IsDescendantOf(workspace) then
		return nil, nil
	end
	local identity = Identity.decode(character:GetAttribute(Identity.attribute))
	if not identity or identity.casterUserId ~= player.UserId then
		return nil, nil
	end
	return character, identity
end
function Client.resolve(expected: Identity.Value): (Model?, Plan.Pose?)
	if not Identity.valid(expected) then
		return nil, nil
	end
	local player = Players:GetPlayerByUserId(expected.casterUserId)
	if not player then
		return nil, nil
	end
	local character, identity = Client.snapshot(player)
	if not character or not identity or not Identity.matches(expected, identity) then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not (humanoid.Health > 0 and humanoid.Health < math.huge) then
		return nil, nil
	end
	return character,
		table.freeze({
			generation = identity.generation,
			characterKey = identity.characterKey,
			slotRevision = identity.slotRevision,
			casterUserId = identity.casterUserId,
			alive = true,
		})
end
-- Burst follows original model continuity, not animation/slot eligibility.
-- Fresh sample only; never retain a model or root across streamed/replaced characters.
function Client.burst(expected: Identity.Value, now: number): Plan.BurstSample?
	if not Identity.valid(expected) or now ~= now or math.abs(now) == math.huge then
		return nil
	end
	local player = Players:GetPlayerByUserId(expected.casterUserId)
	if not player then
		return nil
	end
	local character, identity = Client.snapshot(player)
	if
		not character
		or not identity
		or identity.characterKey ~= expected.characterKey
		or identity.casterUserId ~= expected.casterUserId
	then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or not (humanoid.Health > 0 and humanoid.Health < math.huge) then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local p = root.Position
	for _, n in { p.X, p.Y, p.Z } do
		if n ~= n or math.abs(n) == math.huge then
			return nil
		end
	end
	return table.freeze({
		characterKey = identity.characterKey,
		casterUserId = identity.casterUserId,
		alive = true,
		observedAt = now,
		position = table.freeze({ x = p.X, y = p.Y, z = p.Z }),
	})
end
return Client
