--!strict
-- Server entry point: thin wiring for the Crescent Cut spike (.ai/SPIKE.md).

local Abilities = require(script.Abilities)
local CombatService = require(script.CombatService)
local DataService = require(script.DataService)
local Dummy = require(script.Dummy)
local LoadoutService = require(script.LoadoutService)

LoadoutService.start()
DataService.start()
Dummy.start()
Abilities.start()
CombatService.start()
