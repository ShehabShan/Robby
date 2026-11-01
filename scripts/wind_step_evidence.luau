-- Recompute the first-slice policy; never execute report content as code.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local Evidence = require("../tests/studio/WindStepEvidence")
local report = serde.decode("json", fs.readFile(process.args[1]))
local calculated = Evidence.finish(report.environment, report.results, report.cleanup)
calculated.matrixPassed = calculated.matrixPassed and report.runCompleted == true
local failed = {}
for _, row in report.results do
	if not Evidence.accept(row) then
		table.insert(failed, row.name)
	end
end
print(serde.encode("json", {
	passed = calculated.passed,
	expected = calculated.expected,
	matrixPassed = calculated.matrixPassed,
	dynamicsAccepted = calculated.dynamicsAccepted,
	remaining = calculated.remaining,
	failed = failed,
}))
