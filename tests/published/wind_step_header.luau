--!strict
-- Disabled published candidate. Owner UI and intake/release gates remain incomplete.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Evidence = require(script.Evidence)
local Policy = require(script.PublishedPolicy)
local target = {
	universeId = script:GetAttribute("TestUniverseId"),
	placeId = script:GetAttribute("TestPlaceId"),
	ownerUserId = script:GetAttribute("TestOwnerUserId"),
}
if
	not Policy.target(target)
	or RunService:IsStudio()
	or not RunService:IsServer()
	or not RunService:IsRunning()
	or script:GetAttribute("RunWindStep") ~= true
	or game.GameId ~= target.universeId
	or game.PlaceId ~= target.placeId
then
	warn("WIND_STEP_BLOCKED: requires separate configured published test and explicit opt-in")
	return
end
local untilPlayer = os.clock() + 120
repeat
	task.wait(0.1)
until #Players:GetPlayers() > 0 or os.clock() >= untilPlayer
local current = Players:GetPlayers()
local environment = {
	studio = RunService:IsStudio(),
	running = RunService:IsRunning(),
	server = RunService:IsServer(),
	optIn = script:GetAttribute("RunWindStep") == true,
	players = #current,
	playerUserId = if #current == 1 then current[1].UserId else 0,
	universeId = game.GameId,
	placeId = game.PlaceId,
	placeVersion = game.PlaceVersion,
	jobId = game.JobId,
	engine = RunService:GetRobloxVersion(),
	gravity = workspace.Gravity,
	sourceRevision = script:GetAttribute("SourceRevision") or "UNRECORDED",
	sourceHashes = script:GetAttribute("SourceHashes") or "UNRECORDED",
	generatedServerSha256 = script:GetAttribute("GeneratedServerSha256") or "UNRECORDED",
}
if not Policy.guard(target, environment) then
	warn("WIND_STEP_BLOCKED: requires one owner Player in the exact published test server")
	return
end
if script:GetAttribute("HasRun") then
	warn("WIND_STEP_BLOCKED: this server already ran; use a fresh server")
	return
end
