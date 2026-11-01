local serde = require("@lune/serde")
local fixture = require("./helpers/owner_test_fixture")
local count = 0
local function test(name, fn)
	fn()
	count += 1
	print("PASS " .. name)
end
test("private channel created without autostart; only original owner receives complete report", function()
	local f = fixture()
	assert(f.ok and f.folder.Parent == f.gui and f.runs == 0)
	f.ask("start", nil, { UserId = f.owner.UserId })
	assert(#f.sent == 0 and #f.jobs == 0)
	f.ask("start")
	f.drain()
	assert(f.runs == 1 and f.ask("status").phase == "complete")
	local result = serde.decode("json", f.ask("report", 1).data)
	assert(result.runCompleted and result.cleanup and not result.dynamicsAccepted)
	f.ask("start")
	assert(#f.jobs == 0)
	f.stop()
	f.stop()
	assert(not f.restart(), "transport must not allow a second run after teardown")
	f.noLeaks()
end)
test("extra join timeout destination change stop worker and export truthful failure", function()
	for _, mode in { "extra", "timeout", "destination-change" } do
		local f = fixture(mode)
		f.ask("start")
		f.drain()
		assert(f.cleaned and f.cancels == 1 and f.ask("status").phase == "failed")
		local report = serde.decode("json", f.ask("report", 1).data)
		assert(not report.matrixPassed and not report.runCompleted)
		f.stop()
		f.noLeaks()
	end
end)
test("leave destroys transport but worker still cleans; idle removal and replaced GUI close", function()
	local f = fixture("leave")
	f.ask("start")
	f.drain()
	assert(f.cleaned and f.cancels == 1)
	f.noLeaks()
	for _, mode in { "owner", "gui", "folder" } do
		f = fixture()
		if mode == "owner" then
			f.owner.Parent = nil
		elseif mode == "gui" then
			f.gui.Parent = nil
		else
			f.folder.Parent = nil
		end
		f.run.Heartbeat:Fire()
		f.noLeaks()
	end
end)
test("unsafe startup refuses and partial signal acquisition unwinds", function()
	for _, mode in { "studio", "wrong-place", "acquire" } do
		local f = fixture(mode)
		assert(not f.ok and f.runs == 0)
		f.noLeaks()
	end
end)
test("100 actual transport cycles release every engine handle", function()
	for _ = 1, 100 do
		local f = fixture()
		f.ask("start")
		f.drain()
		f.stop()
		f.noLeaks()
	end
end)
test("same-ID replacement during idle cannot start; startup/runtime guards are separate", function()
	local f = fixture()
	f.list = { { UserId = f.owner.UserId } }
	f.ask("start")
	assert(#f.jobs == 0 and f.ask("status").phase == "closed")
	f.stop()
	f.noLeaks()
end)
test("idle deadline and saturated owner requests never create a second worker", function()
	local f = fixture()
	f.now = 120
	f.run.Heartbeat:Fire()
	f.ask("start")
	assert(#f.jobs == 0 and f.ask("status").phase == "closed")
	f.stop()
	f.noLeaks()
	f = fixture()
	local remote = f.folder:FindFirstChild("Request").OnServerEvent
	for _ = 1, 1000 do
		remote:Fire(f.owner, "start")
	end
	assert(#f.jobs == 1 and #f.sent == 1)
	f.drain()
	f.stop()
	f.noLeaks()
end)
test("owner leaves before scheduled work; no fixture work and no stale listener restarts", function()
	local f = fixture()
	f.ask("start")
	f.players.PlayerRemoving:Fire(f.owner)
	f.drain()
	assert(f.runs == 0 and f.cancels == 1)
	f.players.PlayerAdded:Fire(f.owner)
	assert(not f.restart())
	f.noLeaks()
end)
print("Owner test transport: " .. count .. " groups PASS (mock engine only)")
