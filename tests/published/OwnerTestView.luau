--!strict
-- Isolated diagnostic UI only. Shows server evidence, never authorizes gameplay.
local View = {}
function View.start(Client: any, owner: Player, channel: Folder): () -> ()
	local RunService = game:GetService("RunService")
	local HttpService = game:GetService("HttpService")
	local gui = owner:FindFirstChildOfClass("PlayerGui")
	assert(gui and channel.Parent == gui, "original owner channel required")
	local request = channel:FindFirstChild("Request") :: RemoteEvent
	local response = channel:FindFirstChild("Response") :: RemoteEvent
	assert(request and request:IsA("RemoteEvent") and response and response:IsA("RemoteEvent"), "invalid channel")
	local state = Client.new(os.clock())
	local connections: { RBXScriptConnection } = {}
	local screen: ScreenGui? = nil
	local stopped, decoded = false, false
	local pages: { string }, page, summary = {}, 1, ""
	local function stop()
		if stopped then
			return
		end
		stopped = true
		for _, c in connections do
			pcall(function()
				c:Disconnect()
			end)
		end
		table.clear(connections)
		if screen then
			pcall(function()
				screen:Destroy()
			end)
		end
	end
	local ok, err = pcall(function()
		local ui = Instance.new("ScreenGui")
		screen = ui
		ui.Name, ui.ResetOnSpawn = "WindStepOwnerReport", false
		ui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		local panel = Instance.new("Frame")
		panel.Size, panel.Position = UDim2.new(1, -24, 1, -24), UDim2.fromOffset(12, 12)
		panel.BackgroundColor3, panel.Parent = Color3.fromRGB(19, 25, 29), ui
		local function label(text: string, y: number, height: number): TextLabel
			local obj = Instance.new("TextLabel")
			obj.Size, obj.Position = UDim2.new(1, -16, 0, height), UDim2.fromOffset(8, y)
			obj.BackgroundTransparency, obj.TextColor3 = 1, Color3.fromRGB(235, 242, 238)
			obj.TextSize, obj.TextWrapped, obj.TextXAlignment = 16, true, Enum.TextXAlignment.Left
			obj.Text, obj.Parent = text, panel
			return obj
		end
		label("Wind Step — PRIVATE TEST • not the live game", 4, 26)
		local status = label("Connecting…", 32, 44)
		local function button(text: string, x: number, width: number): TextButton
			local obj = Instance.new("TextButton")
			obj.Size, obj.Position = UDim2.new(width, -6, 0, 40), UDim2.new(x, 4, 0, 82)
			obj.Text, obj.TextSize, obj.TextWrapped = text, 15, true
			obj.BackgroundColor3, obj.TextColor3 = Color3.fromRGB(40, 66, 60), Color3.fromRGB(255, 255, 255)
			obj.Selectable, obj.Parent = true, panel
			return obj
		end
		local start = button("Start test", 0, 0.28)
		local previous = button("Previous", 0.28, 0.23)
		local nextPage = button("Next", 0.51, 0.23)
		local selectPage = button("Select page", 0.74, 0.26)
		local info = label("No movement until Start. One run/server; stay connected and alone.", 126, 44)
		local scroll = Instance.new("ScrollingFrame")
		scroll.Size, scroll.Position = UDim2.new(1, -16, 1, -184), UDim2.fromOffset(8, 176)
		scroll.AutomaticCanvasSize, scroll.CanvasSize = Enum.AutomaticSize.Y, UDim2.fromOffset(0, 0)
		scroll.BackgroundColor3, scroll.ScrollBarThickness = Color3.fromRGB(12, 17, 20), 8
		scroll.Parent = panel
		local text = Instance.new("TextBox")
		text.Name = "ReportPage"
		text.Size, text.AutomaticSize = UDim2.new(1, -16, 0, 80), Enum.AutomaticSize.Y
		text.Position = UDim2.fromOffset(4, 4)
		text.TextEditable, text.MultiLine, text.ClearTextOnFocus = false, true, false
		text.TextWrapped, text.TextSize, text.RichText = true, 14, false
		text.TextXAlignment, text.TextYAlignment = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top
		text.TextColor3, text.BackgroundTransparency = Color3.fromRGB(230, 240, 235), 1
		text.Text, text.Parent = "Full JSON will appear here after cleanup and download.", scroll
		local function showPage()
			if #pages == 0 then
				return
			end
			text.Text = pages[page]
			scroll.CanvasPosition = Vector2.zero
			info.Text = string.format(
				"JSON page %d/%d • %d bytes total. Select, Ctrl+C; paste pages in order with NO added separators.",
				page,
				#pages,
				state.bytes
			)
		end
		local function render()
			if state.report and not decoded then
				decoded = true
				local valid, report = pcall(function()
					return HttpService:JSONDecode(state.report)
				end)
				if not valid or type(report) ~= "table" or report.dynamicsAccepted ~= false then
					state.failed, state.reason = true, "Invalid JSON evidence; do not submit."
				else
					pages = Client.displayPages(state.report)
					summary = if report.matrixPassed == true
						then "Matrix passed; real dynamics acceptance still OPEN."
						else "Matrix incomplete/failed; return full JSON for diagnosis."
					showPage()
				end
			end
			start.Active, start.AutoButtonColor =
				state.phase == "idle" and not state.started and not state.failed,
				state.phase == "idle" and not state.started and not state.failed
			start.Text = if state.started then "Started (once)" else "Start test"
			status.Text = if state.failed
				then (state.reason or "Reader stopped")
				else string.format("%s • %d/106 cases • %s", state.phase, state.progress, summary)
		end
		table.insert(
			connections,
			start.Activated:Connect(function()
				Client.start(state)
				render()
			end)
		)
		table.insert(
			connections,
			previous.Activated:Connect(function()
				page = math.max(1, page - 1)
				showPage()
			end)
		)
		table.insert(
			connections,
			nextPage.Activated:Connect(function()
				page = math.min(math.max(1, #pages), page + 1)
				showPage()
			end)
		)
		table.insert(
			connections,
			selectPage.Activated:Connect(function()
				if #pages > 0 then
					text:CaptureFocus()
					text.CursorPosition = #text.Text + 1
					text.SelectionStart = 1
				end
			end)
		)
		table.insert(
			connections,
			response.OnClientEvent:Connect(function(message)
				Client.receive(state, message)
				render()
			end)
		)
		table.insert(
			connections,
			RunService.Heartbeat:Connect(function()
				if stopped then
					return
				end
				if gui.Parent ~= owner or channel.Parent ~= gui then
					-- Preserve fully retrieved copyable evidence when server closes its channel.
					if not state.report then
						state.failed, state.reason = true, "Original test channel closed; no complete report."
					end
				else
					local action, index = Client.next(state, os.clock())
					if action then
						local sent = pcall(function()
							request:FireServer(action, index)
						end)
						if not sent then
							state.failed, state.reason = true, "Request failed; no automatic restart."
						end
					end
				end
				render()
			end)
		)
		ui.Parent = gui -- expose only after all handlers are owned
	end)
	if not ok then
		stop()
		error(err, 0)
	end
	return stop
end
return View
