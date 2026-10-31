--!strict
-- Owned confirmed-impact engine slice. No prediction, hit inference, or legacy FX calls.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Dispatch = require(ReplicatedStorage.Shared.CastContactDispatch)
local CommandMap = require(ReplicatedStorage.Shared.CastCommandMap)
local Feel = require(ReplicatedStorage.Shared.HitFeel)
local CastContactFx = {}

-- Transfer new children into the bound tree before configuring them. A failed
-- parent assignment must not strand an unowned Instance outside that tree.
local function child(className: string, parent: Instance): any
	local object = Instance.new(className)
	local ok, problem = pcall(function()
		object.Parent = parent
	end)
	if not ok then
		object:Destroy()
		error(problem)
	end
	return object
end

function CastContactFx.render(frame: Dispatch.Frame, command: CommandMap.Contact): boolean
	-- One owned tree per contact. Bind while unparented, before emitting anything.
	local anchor = Instance.new("Part")
	local ticket = frame.bind("impact", function()
		anchor:Destroy()
	end)
	if not ticket then
		return false
	end
	anchor.Name = "ConfirmedCastImpact"
	anchor.Size = Vector3.new(0.1, 0.1, 0.1)
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	local position = command.receipt.position
	anchor.Position = Vector3.new(position.x, position.y, position.z)
	-- Style only; missing acceptance is still a real confirmed impact. No crit,
	-- target pose, camera shake or frost status is inferred from this receipt.
	local frost = command.fx ~= nil and string.sub(command.fx, 1, 8) == "fx.rime."
	local color = if frost then Color3.fromRGB(180, 235, 255) else Color3.new(1, 1, 1)
	local seconds = math.max(0, frame.expiresAt - frame.now)
	local sparks = child("ParticleEmitter", anchor)
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Rate = 0
	sparks.Color = ColorSequence.new(color)
	sparks.LightEmission = 1
	sparks.Lifetime = NumberRange.new(math.min(0.2, seconds), math.min(0.35, seconds))
	sparks.Speed = NumberRange.new(8, 16)
	sparks.SpreadAngle = Vector2.new(180, 180)
	local gui = child("BillboardGui", anchor)
	gui.Size = UDim2.fromOffset(80, 40)
	gui.StudsOffset = Vector3.new(0, 2, 0)
	gui.AlwaysOnTop = true
	local label = child("TextLabel", gui)
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = Feel.damageText(command.receipt.amount)
	if not frame.isCurrent(ticket) then
		frame.release(ticket)
		return false
	end
	anchor.Parent = workspace
	sparks:Emit(math.clamp(math.floor(Config.HitFeel.sparks), 0, 32))
	return true
end

return CastContactFx
