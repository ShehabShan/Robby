local Client = require("../src/shared/OwnerTestClient")
local function status(phase, bytes)
	return {
		phase = phase or "idle",
		progress = 0,
		bytes = bytes or 0,
		pages = math.ceil((bytes or 0) / 12000),
		dynamicsAccepted = false,
	}
end
local function transfer(text)
	local s = Client.new(0)
	Client.receive(s, status("complete", #text))
	for i = 1, math.ceil(#text / 12000) do
		local action, page = Client.next(s, i)
		assert(action == "report" and page == i)
		Client.receive(
			s,
			{ page = page, pages = s.pages, bytes = s.bytes, data = string.sub(text, (i - 1) * 12000 + 1, i * 12000) }
		)
	end
	return s
end
return {
	noAutoStart = function()
		local s = Client.new(0)
		assert(not Client.start(s))
		assert(Client.next(s, 0) == "status")
		Client.receive(s, status())
		assert(Client.start(s))
		assert(not Client.start(s))
		assert(Client.next(s, 0.1) == nil)
		assert(Client.next(s, 1) == "start")
		assert(Client.next(s, 2) == "status")
	end,
	utf8AcrossWireAndDisplayPages = function()
		local text = string.rep("a", 11999) .. "界🙂" .. string.rep("z", 20000)
		local s = transfer(text)
		assert(s.report == text and #s.chunks == 0)
		local pages = Client.displayPages(text)
		assert(table.concat(pages) == text)
		for _, page in pages do
			assert(utf8.len(page) and #page <= 6000)
		end
	end,
	maximumSizeAndNoFurtherRequests = function()
		local text = string.rep("a", 524288)
		local s = transfer(text)
		assert(s.report == text and Client.next(s, 100) == nil)
		assert(Client.next(s, 999) == nil and not s.failed)
	end,
	boundedRetryAndNoPartialEvidence = function()
		local s = Client.new(0)
		Client.receive(s, status("failed", 24000))
		for i = 1, 3 do
			local a, p = Client.next(s, i)
			assert(a == "report" and p == 1)
		end
		assert(Client.next(s, 4) == nil and s.failed and not s.report)
	end,
	duplicateUnrequestedPagesIgnored = function()
		local s = Client.new(0)
		Client.receive(s, {})
		assert(not s.failed)
		Client.receive(s, status("complete", 24000))
		Client.next(s, 0)
		local p = { page = 2, pages = 2, bytes = 24000, data = string.rep("a", 12000) }
		Client.receive(s, p)
		assert(#s.chunks == 0)
		p.page = 1
		Client.receive(s, p)
		Client.receive(s, p)
		assert(#s.chunks == 1)
	end,
	invalidStatusAndPageRefused = function()
		for _, field in { "phase", "bytes", "pages", "progress", "dynamicsAccepted" } do
			local s = Client.new(0)
			local m = status()
			m[field] = "invalid"
			Client.receive(s, m)
			assert(s.failed)
		end
		local s = Client.new(0)
		Client.receive(s, status("running", 10))
		assert(s.failed)
		s = Client.new(0)
		Client.receive(s, status("complete", 10))
		Client.next(s, 0)
		Client.receive(s, { page = 1, pages = 1, bytes = 10, data = "short" })
		assert(s.failed and not s.report)
	end,
	deadlineAndClock = function()
		for _, now in { -1, 750, math.huge, 0 / 0 } do
			local s = Client.new(0)
			assert(Client.next(s, now) == nil and s.failed)
		end
	end,
}
