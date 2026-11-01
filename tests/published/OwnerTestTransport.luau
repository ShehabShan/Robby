--!strict
-- Isolated published-test engine binding. No inclusion/activation in any place yet.
-- A private PlayerGui channel carries bounded owner-only requests/responses.
local Transport = {}
local claimed = false -- One successfully acquired transport per server/module lifetime.
function Transport.start(policy: any, adapter: any, admission: any, options: any): () -> ()
	assert(not claimed, "test server session already claimed; use a fresh server")
	local Players = game:GetService("Players")
	local RunService = game:GetService("RunService")
	local HttpService = game:GetService("HttpService")
	local owner, target = options.owner, table.clone(options.target)
	local function valid(): boolean
		local players = Players:GetPlayers()
		return owner.Parent == Players
			and #players == 1
			and players[1] == owner
			and admission.guard(target, {
				studio = RunService:IsStudio(),
				server = RunService:IsServer(),
				running = RunService:IsRunning(),
				optIn = options.optIn == true,
				players = #players,
				playerUserId = owner.UserId,
				universeId = game.GameId,
				placeId = game.PlaceId,
				placeVersion = game.PlaceVersion,
				jobId = game.JobId,
			})
	end
	assert(valid(), "unsafe published test environment")
	local gui = owner:FindFirstChildOfClass("PlayerGui")
	assert(gui and not gui:FindFirstChild("WindStepTestSession"), "owner UI missing or session already exists")
	local folder: any = nil
	local handle: any = nil
	local closed = false
	local function stop()
		if closed then
			return
		end
		closed = true
		if handle then
			pcall(handle.stop)
		end
		if folder then
			pcall(function()
				folder:Destroy()
			end)
		end
	end
	claimed = true
	local ok, err = pcall(function()
		folder = Instance.new("Folder")
		folder.Name = "WindStepTestSession"
		local request = Instance.new("RemoteEvent")
		request.Name, request.Parent = "Request", folder
		local response = Instance.new("RemoteEvent")
		response.Name, response.Parent = "Response", folder
		handle = adapter.start(policy, {
			owner = owner,
			clock = os.clock,
			valid = function()
				return valid() and folder.Parent == gui and gui.Parent == owner
			end,
			onRequest = function(fn)
				return request.OnServerEvent:Connect(fn)
			end,
			onHeartbeat = function(fn)
				return RunService.Heartbeat:Connect(function()
					fn()
					if owner.Parent ~= Players or folder.Parent ~= gui or gui.Parent ~= owner then
						stop()
					end
				end)
			end,
			onInvalidated = function(fn: () -> ())
				local connections: { RBXScriptConnection } = {}
				local function disconnect()
					for _, c in connections do
						pcall(function()
							c:Disconnect()
						end)
					end
					table.clear(connections)
				end
				local acquired, failure = pcall(function()
					table.insert(
						connections,
						Players.PlayerAdded:Connect(function()
							fn()
						end)
					)
					table.insert(
						connections,
						Players.PlayerRemoving:Connect(function(player)
							fn()
							if player == owner then
								stop()
							end
						end)
					)
				end)
				if not acquired then
					disconnect()
					error(failure, 0)
				end
				return { Disconnect = disconnect }
			end,
			send = function(player, message)
				if not closed and player == owner and owner.Parent == Players then
					response:FireClient(owner, message)
				end
			end,
			spawn = task.defer,
			run = options.run,
			cancelWorker = options.cancelWorker,
			encode = function(report)
				return HttpService:JSONEncode(report)
			end,
		})
		-- All handlers are acquired before replication exposes the channel.
		folder.Parent = gui
	end)
	if not ok then
		stop()
		claimed = false -- Nothing was exposed before acquisition completed.
		error(err, 0)
	end
	return stop
end
return Transport
