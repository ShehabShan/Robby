--!strict
-- T-026c: list Animation ids and write each KeyframeSequence of a .rbxm to its own .rbxm (for Open Cloud upload).
-- Usage: lune run scripts/extract_anims.luau "<path.rbxm>" [outdir]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local path = process.args[1]
assert(path, "usage: lune run scripts/extract_anims.luau <file.rbxm> [outdir]")
local outDir = process.args[2] or "build/anims"
if not fs.isDir(outDir) then
	fs.writeDir(outDir)
end
local roots = roblox.deserializeModel(fs.readFile(path))

local function walk(inst: any)
	if inst.ClassName == "Animation" then
		local ok, id = pcall(function()
			return inst.AnimationId
		end)
		print(`ANIM {inst:GetFullName()} = {if ok then id else "(unset)"}`)
	elseif inst.ClassName == "KeyframeSequence" then
		local file = `{outDir}/{string.gsub(inst.Name, "[^%w_]", "_")}.rbxm`
		fs.writeFile(file, roblox.serializeModel({ inst:Clone() }))
		local n = #inst:GetChildren()
		print(`KFS {inst.Name} keyframes={n} loop={inst.Loop} priority={inst.Priority} -> {file}`)
	end
	for _, child in inst:GetChildren() do
		walk(child)
	end
end
for _, r in roots do
	walk(r)
end
