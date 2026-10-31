-- Exports actual pure planner output for the offline art board (not a Roblox renderer).
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Motion = require("../src/shared/WindStep")
local Visual = require("../src/shared/WindStepVisual")
local motion = assert(Motion.profile(Motion.PROPOSED))
local snapshot = assert(Visual.snapshot({ version=1, distance=motion.distance, duration=motion.duration, brake=motion.brake, fade=0.12 }))
local phases = {}
for _, row in { {"Launch",0.02}, {"Travel",0.10}, {"Brake",0.20}, {"Stopped by wall",0.11}, {"Fade",0.30}, {"Expired",0.38} } do
	local name, t = row[1], row[2]
	local position, speed = Motion.sample(motion,t)
	local stopped = if name=="Stopped by wall" then 0.08 else nil
	if stopped then position=Motion.sample(motion,stopped); speed=0 end
	table.insert(phases, {label=name,elapsed=t,position=position,frame=Visual.sample(snapshot,t,speed,stopped,false)})
end
local animation = {}
for i=0,59 do
	local t=i/60
	local distance,speed=Motion.sample(motion,t)
	table.insert(animation,{elapsed=t,position=distance,frame=Visual.sample(snapshot,t,speed,nil,false)})
end
fs.writeFile("build/wind_preview.json",serde.encode("json",{snapshot=snapshot,phases=phases,animation=animation},true))
print("WIND PREVIEW: actual pure planner exported (offline, not Roblox)")
