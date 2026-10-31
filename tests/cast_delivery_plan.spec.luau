local Plan = require("../src/shared/CastDeliveryPlan")
local Geometry = require("../src/shared/CastGeometry")
local Receipts = require("../src/shared/CastReceipts")
local Map = require("../src/shared/CastCommandMap")
local Volley = require("../src/shared/Deliveries/Volley")
local Gate = require("../src/shared/CastWarningGate")
local Config = require("../src/shared/Config")
local function metadata(kind)
	local g = assert(Geometry.capture({
		delivery = {
			kind = kind,
			params = {
				speed = 10,
				range = 40,
				count = 5,
				spreadDeg = 60,
				radius = 17,
				hitbox = { x = 2, y = 3, z = 4 },
			},
		},
	}, {}))
	local a = {
		castId = "g:1",
		generation = "g",
		seq = 1,
		casterUserId = 42,
		characterKey = "old",
		slotRevision = 4,
		moveId = "m",
		acceptedAt = 100,
		releaseAt = 101,
		endsAt = 105,
		geometry = g,
		aim = { x = 0, y = 0, z = -1 },
		origin = { x = 2, y = 3, z = 4 },
		centre = { x = 5, y = 6, z = 7 },
	}
	return { acceptance = a, style = { delivery = kind, worldWarning = kind ~= "Self" } }
end
local function pose()
	return { generation = "g", characterKey = "old", slotRevision = 4, casterUserId = 42, alive = true }
end
local function near(a, b)
	assert(math.abs(a - b) < 1e-8, tostring(a) .. " vs " .. tostring(b))
end
return {
	["primary failure reserve uses identical admitted geometry and survives local death"] = function()
		local m = metadata("Zone")
		local r = Receipts.new(Config.CastClientReceipt)
		assert(Receipts.put(r, m.acceptance, 0) == "stored")
		local cmd = Map.accepted({ m = m.style }, Receipts.get(r, "g:1", 0))
		local primaryClean, reserveClean, radius = 0, 0, 0
		local gate = Gate.new(Config.CastWarning, function(frame)
			assert(frame.bind("partial", "world", function()
				primaryClean += 1
			end))
			return false
		end, function(frame)
			assert(primaryClean == 1)
			local plan = assert(Plan.accepted(cmd.metadata, frame.now, nil, false))
			radius = plan.world[1].radius
			assert(not plan.pose)
			if frame.action == "start" then
				assert(frame.bind("warning", function()
					reserveClean += 1
				end))
			end
			return true
		end)
		Gate.accept(gate, "g:1", cmd.timeline, 0, 100.5)
		assert(radius == 17 and reserveClean == 0)
		Gate.retirePose(gate, "g:1", 0.5, 101)
		assert(Gate.tick(gate, 1, 101.5) and reserveClean == 0)
		Gate.cancel(gate, "g:1", 1.5, 102)
		assert(reserveClean == 1)
		Gate.destroy(gate)
		assert(reserveClean == 1)
	end,
	["both renderers fail closed on unresolved Burst instead of counting a visible cue"] = function()
		local m = metadata("Burst")
		local r = Receipts.new(Config.CastClientReceipt)
		assert(Receipts.put(r, m.acceptance, 0) == "stored")
		local cmd = Map.accepted({ m = m.style }, Receipts.get(r, "g:1", 0))
		local function render(frame)
			local result, reason = Plan.accepted(cmd.metadata, frame.now, nil, false)
			assert(result == nil and reason == "moving_centre")
			return false
		end
		local gate = Gate.new(Config.CastWarning, render, render)
		Gate.accept(gate, "g:1", cmd.timeline, 0, 100.5)
		assert(gate.gate.bridge.renderFailures == 1 and gate.reserve.bridge.renderFailures == 1)
		Gate.destroy(gate)
	end,

	["projectile late start seeks current distance not full travel replay"] = function()
		local m = metadata("Projectile")
		local f = assert(Plan.accepted(m, 103, pose(), true))
		assert(f.phase == "active" and f.progress == 0.5 and not f.speculative and f.pose and #f.world == 1)
		local shot = f.world[1]
		assert(
			shot.slot == "shot:1" and shot.kind == "Box" and shot.size.x == 2 and shot.size.y == 3 and shot.size.z == 4
		)
		near(shot.position.x, 2)
		near(shot.position.y, 3)
		near(shot.position.z, -16)
		near(shot.direction.x, 0)
		near(shot.direction.z, -1)
	end,
	["all fan trajectories use authoritative count spread and server direction math"] = function()
		local m = metadata("Volley")
		local f = assert(Plan.accepted(m, 103, nil, false))
		local dirs = Volley.directions(0, -1, { count = 5, spreadDeg = 60 })
		assert(#f.world == 5 and not f.pose)
		for i, d in dirs do
			local shot = f.world[i]
			assert(shot.slot == "shot:" .. i)
			near(shot.position.x, 2 + d.x * 20)
			near(shot.position.z, 4 + d.z * 20)
			near(shot.direction.x, d.x)
			near(shot.direction.z, d.z)
		end
	end,
	["seek is stateless bounded stable keyed and cannot mutate earlier frames"] = function()
		local m = metadata("Volley")
		m.acceptance.geometry = table.clone(m.acceptance.geometry)
		m.acceptance.geometry.count = 16
		local late = assert(Plan.accepted(m, 104, nil, false))
		local early = assert(Plan.accepted(m, 101.5, nil, false))
		local again = assert(Plan.accepted(m, 104, nil, false))
		assert(#late.world == 16 and #early.world == 16)
		for i, shape in late.world do
			assert(shape.slot == early.world[i].slot and shape.slot == again.world[i].slot)
			assert(shape.position.z == again.world[i].position.z and shape.position.z ~= early.world[i].position.z)
		end
		assert(table.isfrozen(late) and table.isfrozen(late.world) and table.isfrozen(late.world[1]))
		assert(not pcall(function()
			late.world[1].position.x = 0
		end))
		assert(not pcall(function()
			late.world[1].size.x = 0
		end))
	end,
	["warning release boundary and projectile range clamp"] = function()
		local m = metadata("Projectile")
		local warning = assert(Plan.accepted(m, 100.5, nil, false))
		local released = assert(Plan.accepted(m, 101, nil, false))
		assert(warning.phase == "warning" and warning.progress == 0.5 and warning.world[1].position.z == 4)
		assert(released.phase == "active" and released.progress == 0 and released.world[1].position.z == 4)
		m.acceptance.endsAt = 109
		near(assert(Plan.accepted(m, 108, nil, false)).world[1].position.z, -36)
	end,
	["zone exact centre radius persists without any character after death"] = function()
		local m = metadata("Zone")
		local f = assert(Plan.accepted(m, 100.5, pose(), true))
		local dead = pose()
		dead.alive = false
		local later = assert(Plan.accepted(m, 103, dead, false))
		local absent = assert(Plan.accepted(m, 104, nil, false))
		assert(f.pose and not later.pose and not absent.pose)
		for _, v in { f, later, absent } do
			assert(#v.world == 1 and v.world[1].kind == "Disc" and v.world[1].slot == "zone")
			assert(
				v.world[1].radius == 17
					and v.world[1].position.x == 5
					and v.world[1].position.y == 6
					and v.world[1].position.z == 7
			)
		end
	end,
	["Burst unavailable samples never fall back to acceptance origin or centre"] = function()
		local m = metadata("Burst")
		for _, now in { 100, 100.5, 101, 104 } do
			local f = assert(Plan.accepted(m, now, pose(), true))
			assert(#f.world == 0)
			assert(f.centreStatus == (if now < 101 then "unavailable" else "release_unknown"))
		end
	end,
	["Burst follows fresh original position only before exact release boundary"] = function()
		local m = metadata("Burst")
		local sample = {
			characterKey = "old",
			casterUserId = 42,
			alive = true,
			observedAt = 100.5,
			position = {
				x = 20,
				y = 3,
				z = 40,
			},
		}
		local first = assert(Plan.accepted(m, 100.5, nil, false, sample))
		assert(first.centreStatus == "provisional" and not first.pose and first.phase == "warning")
		assert(first.world[1].radius == 17 and first.world[1].position.x == 20)
		sample.position.x = 30
		local moved = assert(Plan.accepted(m, 100.5, nil, false, sample))
		assert(moved.world[1].position.x == 30 and first.world[1].position.x == 20)
		assert(table.isfrozen(first.world[1].position))
		for _, now in { 101, 101.001, 104 } do
			sample.observedAt = now
			local late = assert(Plan.accepted(m, now, nil, false, sample))
			assert(#late.world == 0 and late.centreStatus == "release_unknown")
		end
	end,
	["Burst rejects stale dead missing wrong original and malformed samples"] = function()
		local m = metadata("Burst")
		local good = {
			characterKey = "old",
			casterUserId = 42,
			alive = true,
			observedAt = 100.5,
			position = {
				x = 20,
				y = 3,
				z = 40,
			},
		}
		for field, value in
			{
				characterKey = "replacement",
				casterUserId = 99,
				alive = false,
				observedAt = 100.4,
				position = {
					x = 0 / 0,
					y = 0,
					z = 0,
				},
			}
		do
			local bad = table.clone(good)
			bad[field] = value
			local f = assert(Plan.accepted(m, 100.5, pose(), true, bad))
			assert(#f.world == 0 and f.centreStatus == "unavailable", field)
		end
		local f = assert(Plan.accepted(m, 100.5, nil, false, good))
		assert(#f.world == 1 and not f.pose) -- original continuity is not pose eligibility
	end,
	["Self owns no world warning and never synthesizes a hit"] = function()
		local f = assert(Plan.accepted(metadata("Self"), 103, pose(), true))
		assert(#f.world == 0 and f.pose and f.contact == nil and f.damage == nil)
	end,
	["prediction is pose only then same-key acceptance uses authoritative geometry"] = function()
		local m = metadata("Zone")
		local f = Plan.predicted(m.acceptance, pose(), true)
		assert(f.speculative and f.phase == "predicted" and f.pose and #f.world == 0)
		local accepted = assert(Plan.accepted(m, 103, pose(), true))
		assert(not accepted.speculative and accepted.world[1].radius == 17 and #f.world == 0)
	end,
	["pose eligibility requires every identity field plus live and lease permission"] = function()
		local m = metadata("Zone")
		for _, field in { "generation", "characterKey", "slotRevision", "casterUserId", "alive" } do
			local p = pose()
			p[field] = if type(p[field]) == "number"
				then p[field] + 1
				elseif field == "alive" then false
				else "replacement"
			local f = assert(Plan.accepted(m, 103, p, true))
			assert(not f.pose and #f.world == 1, field)
			assert(not Plan.predicted(m.acceptance, p, true).pose)
		end
		assert(
			not Plan.predicted(m.acceptance, pose(), false).pose and not Plan.predicted(m.acceptance, nil, true).pose
		)
	end,
	["missing malformed or mismatched geometry fails without base reconstruction"] = function()
		for _, mode in { "missing", "malformed", "wrong-style" } do
			local m = metadata("Zone")
			if mode == "missing" then
				m.acceptance.geometry = nil
			elseif mode == "malformed" then
				m.acceptance.geometry = table.clone(m.acceptance.geometry)
				m.acceptance.geometry.radius = 0 / 0
			else
				m.style.delivery = "Projectile"
			end
			local f, reason = Plan.accepted(m, 103, nil, false)
			assert(f == nil and reason == "geometry")
		end
	end,
	["invalid clocks future exact expiry and zero length all refuse"] = function()
		local m = metadata("Zone")
		for _, t in { 0 / 0, math.huge, -math.huge, 99, 105, 106 } do
			assert(Plan.accepted(m, t, nil, false) == nil)
		end
		for _, field in { "acceptedAt", "releaseAt", "endsAt" } do
			local bad = metadata("Zone")
			bad.acceptance[field] = 0 / 0
			assert(Plan.accepted(bad, 103, nil, false) == nil)
		end
		m.acceptance.releaseAt = 99
		assert(Plan.accepted(m, 103, nil, false) == nil)
		m.acceptance.releaseAt, m.acceptance.endsAt = 100, 100
		assert(Plan.accepted(m, 100, nil, false) == nil)
	end,
	["invalid aim centres and overflow cannot emit invalid geometry"] = function()
		for _, a in
			{
				{ x = 0, y = 0, z = 0 },
				{ x = 0, y = 1, z = -1 },
				{ x = 0, y = 0, z = -2 },
				{ x = math.huge, y = 0, z = 0 },
			}
		do
			local m = metadata("Projectile")
			m.acceptance.aim = a
			assert(Plan.accepted(m, 103, nil, false) == nil)
		end
		local m = metadata("Zone")
		m.acceptance.centre = nil
		assert(Plan.accepted(m, 103, nil, false) == nil)
		m.acceptance.centre = { x = 0, y = 0 / 0, z = 0 }
		assert(Plan.accepted(m, 103, nil, false) == nil)
	end,
	["actual outer gate adopts seeks and retires only pose while keeping world warning"] = function()
		local m = metadata("Zone")
		local inbox = Receipts.new(Config.CastClientReceipt)
		assert(Receipts.put(inbox, m.acceptance, 0) == "stored")
		local command = assert(Map.accepted({ m = m.style }, Receipts.get(inbox, "g:1", 0)))
		local frames, actions = {}, {}
		local currentPose = pose()
		local cleanup = 0
		local gate = Gate.new(Config.CastWarning, function(frame)
			local planned
			if frame.action == "predict" then
				planned = Plan.predicted(m.acceptance, currentPose, frame.poseAllowed)
			else
				planned = assert(Plan.accepted(command.metadata, frame.now, currentPose, frame.poseAllowed))
			end
			table.insert(frames, planned)
			table.insert(actions, frame.action)
			if frame.action == "adopt" then
				assert(frame.bind("world", "world", function()
					cleanup += 1
				end))
				assert(frame.bind("pose", "pose", function()
					cleanup += 1
				end))
			end
			return true
		end, function()
			error("unexpected fallback")
		end)
		assert(Gate.predict(gate, "g:1", 0, 100) == "predict")
		assert(Gate.accept(gate, "g:1", command.timeline, 0.5, 100.5) == "adopt")
		currentPose = nil
		assert(Gate.retirePose(gate, "g:1", 1, 101))
		assert(cleanup == 1 and Gate.tick(gate, 2, 102))
		local latest = frames[#frames]
		assert(not latest.pose and #latest.world == 1 and latest.world[1].radius == 17)
		assert(actions[1] == "predict" and actions[2] == "adopt")
		Gate.destroy(gate)
		assert(cleanup == 2)
	end,
}
