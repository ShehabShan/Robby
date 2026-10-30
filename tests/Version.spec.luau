local Version = require("../src/shared/Version")

local function eq(actual: any, expected: any, msg: string?)
	if actual ~= expected then
		error(`{msg or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

return {
	["version: STRING matches the parts and parses back"] = function()
		local p = Version.parse(Version.STRING)
		assert(p, "parses")
		eq(p.major, Version.MAJOR, "major")
		eq(p.minor, Version.MINOR, "minor")
		eq(p.patch, Version.PATCH, "patch")
		eq(Version.parse("v1.2.3") ~= nil, true, "leading v ok")
		eq(Version.parse("1.2"), nil, "two parts rejected")
		eq(Version.parse("a.b.c"), nil, "letters rejected")
	end,
	["version: compare is numeric, not textual"] = function()
		local v9 = Version.parse("0.0.9") :: any
		local v17 = Version.parse("0.0.17") :: any
		local v100 = Version.parse("0.1.0") :: any
		eq(Version.compare(v9, v17), -1, "9 < 17")
		eq(Version.compare(v17, v9), 1, "17 > 9")
		eq(Version.compare(v17, v17), 0, "equal")
		eq(Version.compare(v17, v100), -1, "minor beats patch")
	end,
	["version: label shows the Roblox place version when known"] = function()
		eq(Version.label(nil), `v{Version.STRING}`, "no place version")
		eq(Version.label(0), `v{Version.STRING}`, "zero = unknown (Studio)")
		eq(Version.label(18), `v{Version.STRING} (Roblox 18)`, "with place version")
	end,
}
