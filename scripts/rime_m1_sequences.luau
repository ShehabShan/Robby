--!strict
-- Offline prototype authoring. No live game require; frames are visual cues, never damage authority.
local roblox = require("@lune/roblox")
local Instance, CFrame, Enum = roblox.Instance, roblox.CFrame, roblox.Enum
local Export = {}

function Export.build(data: any): { any }
	assert(data.schema == 1 and data.priority == "Action" and data.loop == false, "invalid format")
	local sequences = {}
	for _, clip in data.clips do
		local sequence = Instance.new("KeyframeSequence")
		sequence.Name = "Robby_M1_" .. clip.name
		sequence.Priority = Enum.AnimationPriority.Action
		sequence.Loop = false
		local previous = -1
		for _, frame in clip.frames do
			assert(frame.t > previous and frame.t <= clip.duration, "unordered frame")
			previous = frame.t
			local kf = Instance.new("Keyframe")
			kf.Name = if frame.marker then frame.marker else "Pose"
			kf.Time = frame.t
			kf.Parent = sequence
			local function container(name: string, parent: any): any
				local p = Instance.new("Pose")
				p.Name = name
				p.CFrame = CFrame.identity
				p.Weight = 0 -- hierarchy only, never override root/waist/locomotion
				p.Parent = parent
				return p
			end
			local root = container("HumanoidRootPart", kf)
			local lower = container("LowerTorso", root)
			local upper = container("UpperTorso", lower)
			for _, side in { "Left", "Right" } do
				local parent = upper
				for _, segment in { "UpperArm", "LowerArm", "Hand" } do
					local name = side .. segment
					local angles = frame.arms[name]
					assert(angles and #angles == 3, "missing arm transform")
					local p = Instance.new("Pose")
					p.Name = name
					p.Weight = if frame.t == clip.duration then 0 else 1
					p.CFrame = CFrame.Angles(math.rad(angles[1]), math.rad(angles[2]), math.rad(angles[3]))
					p.EasingStyle = Enum.PoseEasingStyle.Linear
					p.EasingDirection = Enum.PoseEasingDirection.InOut
					p.Parent = parent
					parent = p
				end
			end
			if frame.marker then
				local marker = Instance.new("KeyframeMarker")
				marker.Name = frame.marker
				marker.Value = "presentation-only"
				marker.Parent = kf
			end
		end
		assert(clip.frames[1].t == 0 and previous == clip.duration, "bad clip bounds")
		table.insert(sequences, sequence)
	end
	return sequences
end

return Export
