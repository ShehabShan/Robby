--!strict
-- T-026a (D-160): print the instance tree of a .rbxm and extract script sources to build/rbxm/<name>/.
-- Usage: lune run scripts/inspect_rbxm.luau "<path.rbxm>" [outdir]
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local path = process.args[1]
assert(path, "usage: lune run scripts/inspect_rbxm.luau <file.rbxm> [outdir]")
local outDir = process.args[2] or "build/rbxm"
local roots = roblox.deserializeModel(fs.readFile(path))
local SCRIPT = { Script = true, LocalScript = true, ModuleScript = true }
local counts: { [string]: number } = {}

local function lines(src: string): number
	local _, n = string.gsub(src, "\n", "")
	return n + 1
end

local function walk(inst: any, depth: number, dir: string)
	counts[inst.ClassName] = (counts[inst.ClassName] or 0) + 1
	local info = ""
	if SCRIPT[inst.ClassName] then
		local src: string = inst.Source
		info = string.format(" [%d lines]", lines(src))
		local acc = ""
		for part in string.gmatch(dir, "[^/]+") do
			acc = if acc == "" then part else acc .. "/" .. part
			if not fs.isDir(acc) then
				fs.writeDir(acc)
			end
		end
		local ext = if inst.ClassName == "LocalScript"
			then ".client.luau"
			elseif inst.ClassName == "Script" then ".server.luau"
			else ".luau"
		fs.writeFile(dir .. "/" .. inst.Name .. ext, src)
	end
	print(string.rep("  ", depth) .. inst.ClassName .. " " .. inst.Name .. info)
	for _, child in inst:GetChildren() do
		walk(child, depth + 1, dir .. "/" .. inst.Name)
	end
end

for _, root in roots do
	walk(root, 0, outDir)
end
local summary = {}
for class, n in counts do
	table.insert(summary, class .. "=" .. n)
end
table.sort(summary)
print("CLASSES: " .. table.concat(summary, " "))
