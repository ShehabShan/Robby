--!strict
-- The server's one shared status table (T-015b): Abilities grants Self-move tags, CombatService and
-- Abilities read them when resolving hits.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Status = require(ReplicatedStorage.Shared.Status)

return Status.new()
