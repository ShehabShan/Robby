--!strict
-- Disabled published candidate; separate explicit staging/release is required.
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
	-- GetRobloxVersion is RobloxScriptSecurity; ordinary test Scripts must use the public global.
	-- selene: allow(undefined_variable)
	engine = version(),
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
-- Player membership can precede PlayerGui creation. Keep the original owner,
-- share the admission deadline, and never acquire a transport after invalidation.
local originalOwner = current[1]
local function stillAdmitted(): boolean
	local players = Players:GetPlayers()
	return #players == 1
		and players[1] == originalOwner
		and originalOwner.Parent == Players
		and originalOwner.UserId == target.ownerUserId
		and not RunService:IsStudio()
		and RunService:IsServer()
		and RunService:IsRunning()
		and script:GetAttribute("RunWindStep") == true
		and not script:GetAttribute("HasRun")
		and game.GameId == target.universeId
		and game.PlaceId == target.placeId
end
while not originalOwner:FindFirstChildOfClass("PlayerGui") do
	if not stillAdmitted() or os.clock() >= untilPlayer then
		warn("WIND_STEP_BLOCKED: owner UI unavailable or admission changed; use a fresh server")
		return
	end
	task.wait(0.1)
end
if not stillAdmitted() or os.clock() >= untilPlayer then
	warn("WIND_STEP_BLOCKED: owner UI admission expired or changed")
	return
end
