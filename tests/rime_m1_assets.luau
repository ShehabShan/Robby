--!strict
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local Export = require("../scripts/rime_m1_sequences")
local Config = require("../src/shared/Config")
local data = serde.decode("json", fs.readFile("art/poses/rime_m1.json"))
local function sequenceData()
	return roblox.deserializeModel(roblox.serializeModel(Export.build(data)))
end
local suite = {
	["M1 prototype preserves current recovery and projectile counts"] = function()
		assert(#data.clips == 3)
		for i, clip in data.clips do
			assert(clip.frames[1].t == 0 and clip.frames[1].marker == "Release")
			assert(clip.projectiles == (if i == 3 then Config.Abilities.Rimeshard.needle.finisher.shards else 1))
			assert(
				clip.duration
					== (
						if i == 3
							then Config.Abilities.Rimeshard.needle.finisherRecovery
							else Config.Abilities.Rimeshard.needle.chain.recovery
					)
			)
		end
	end,
	["R15 export has only arm weights with neutral zero-weight containers"] = function()
		for _, seq in sequenceData() do
			assert(seq.Priority == roblox.Enum.AnimationPriority.Action and not seq.Loop)
			for _, frame in seq:GetChildren() do
				local root = frame:FindFirstChild("HumanoidRootPart")
				local lower = root:FindFirstChild("LowerTorso")
				local upper = lower:FindFirstChild("UpperTorso")
				assert(#upper:GetChildren() == 2)
				for _, p in { root, lower, upper } do
					assert(p.Weight == 0 and p.CFrame == roblox.CFrame.identity)
				end
				local arms = 0
				for _, p in frame:GetDescendants() do
					assert(not string.find(p.Name, "Leg") and not string.find(p.Name, "Foot") and p.Name ~= "Head")
					if p.ClassName == "Pose" and data.containerWeights[p.Name] == nil then
						arms += 1
						assert(p.CFrame.Position.Magnitude == 0)
					end
				end
				assert(arms == 6)
			end
		end
	end,
	["Three distinct releases, one marker each, zero-weight terminal arms"] = function()
		local signatures = {}
		for _, seq in sequenceData() do
			local frames = seq:GetChildren()
			table.sort(frames, function(a: any, b: any): boolean
				return a.Time < b.Time
			end)
			local markers = 0
			for _, p in seq:GetDescendants() do
				if p.ClassName == "KeyframeMarker" then
					markers += 1
					assert(p.Name == "Release" and p.Parent.Time == 0)
				end
			end
			assert(markers == 1)
			local upper = frames[1].HumanoidRootPart.LowerTorso.UpperTorso
			local signature = tostring(upper.LeftUpperArm.CFrame) .. tostring(upper.RightUpperArm.CFrame)
			assert(not signatures[signature])
			signatures[signature] = true
			for _, p in frames[#frames]:GetDescendants() do
				if p.ClassName == "Pose" then
					assert(p.Weight == 0 and p.CFrame == roblox.CFrame.identity)
				end
			end
		end
	end,
}

local passed = 0
for _, test in suite do
	test()
	passed += 1
end
print(`M1 authoring: {passed} passed (offline export gate, not a cloud gameplay spec)`)
