--!strict
-- lune run scripts/export_rime_m1.luau [outdir]
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Export = require("./rime_m1_sequences")
local data = serde.decode("json", fs.readFile("art/poses/rime_m1.json"))
local out = process.args[1] or "build/art/rime_m1"
if not fs.isDir(out) then
	fs.writeDir(out)
end
for _, sequence in Export.build(data) do
	local path = out .. "/" .. sequence.Name .. ".rbxm"
	fs.writeFile(path, roblox.serializeModel({ sequence }))
	local reloaded = roblox.deserializeModel(fs.readFile(path))[1]
	assert(reloaded.Name == sequence.Name and #reloaded:GetChildren() == #sequence:GetChildren())
	print(`M1 EXPORT: {sequence.Name} {#reloaded:GetChildren()} frames (round-trip PASS)`)
end
