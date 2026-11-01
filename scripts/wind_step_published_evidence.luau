-- Offline calculation only; never execute report content as code.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local Evidence = require("../tests/studio/WindStepEvidence")
local Policy = require("../tests/published/WindStepPublishedPolicy")
local report = serde.decode("json", fs.readFile(process.args[1]))
local calculated = Policy.finish(report.target, report.environment, report.results, report.cleanup, Evidence)
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
