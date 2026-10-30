--!strict
-- Server entry point: thin wiring for the Crescent Cut spike (.ai/SPIKE.md).

local Abilities = require(script.Abilities)
local BindingService = require(script.BindingService)
local UpkeepService = require(script.UpkeepService)
local RefineService = require(script.RefineService)
local BreakthroughService = require(script.BreakthroughService)
local CombatService = require(script.CombatService)
local DataService = require(script.DataService)
local Dummy = require(script.Dummy)
local LoadoutService = require(script.LoadoutService)

LoadoutService.start()
DataService.start()
Dummy.start()
Abilities.start()
BindingService.start()
UpkeepService.start()
RefineService.start()
BreakthroughService.start()
CombatService.start()
