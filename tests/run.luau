-- Lune test runner. Discovers tests/*.spec.luau; each spec returns { [testName]: () -> () }.
-- Run from the repo root: `lune run tests/run.luau`. Prints a short summary.

local fs = require("@lune/fs")
local process = require("@lune/process")

local specs = {}
for _, name in fs.readDir("tests") do
	if string.match(name, "%.spec%.luau$") then
		table.insert(specs, name)
	end
end
table.sort(specs)

local passed, failed = 0, 0
local failures = {}

for _, file in specs do
	local modulePath = "./" .. string.gsub(file, "%.luau$", "")
	local suite = require(modulePath) :: any
	local names = {}
	for testName in suite do
		table.insert(names, testName)
	end
	table.sort(names)
	for _, testName in names do
		local ok, err = pcall(suite[testName])
		if ok then
			passed += 1
		else
			failed += 1
			table.insert(failures, `{file} > {testName}: {err}`)
		end
	end
end

for _, line in failures do
	print("  FAIL " .. line)
end
print(`tests: {passed} passed, {failed} failed ({#specs} specs)`)

if failed > 0 or #specs == 0 then
	process.exit(1)
end
