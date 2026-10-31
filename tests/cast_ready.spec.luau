local Ready = require("../src/shared/CastReady")
return {
	["snapshot before character binds only exact identity"] = function()
		local s, old, nextCharacter = Ready.new(), {}, {}
		assert(not Ready.ready(s, old))
		Ready.receive(s, 2, "server:2", nextCharacter)
		assert(not Ready.ready(s, old) and not Ready.ready(s, nil))
		assert(Ready.ready(s, nextCharacter))
	end,
	["unresolved character recovers on same epoch without accepting stale epoch"] = function()
		local s, character = Ready.new(), {}
		Ready.receive(s, 4, "server:4", nil)
		assert(not Ready.ready(s, character))
		assert(not Ready.receive(s, 3, "server:3", character))
		assert(not Ready.receive(s, 4, "wrong:4", character))
		assert(not Ready.ready(s, character))
		assert(not Ready.receive(s, 4, "server:4", character))
		assert(Ready.ready(s, character))
	end,
	["duplicate cannot retarget character or undo removal"] = function()
		local s, a, b = Ready.new(), {}, {}
		Ready.receive(s, 2, "server:2", a)
		Ready.receive(s, 2, "server:2", b)
		assert(Ready.ready(s, a) and not Ready.ready(s, b))
		Ready.receive(s, 3, "server:3", nil)
		Ready.receive(s, 2, "server:2", a)
		assert(not Ready.ready(s, a))
	end,
}
