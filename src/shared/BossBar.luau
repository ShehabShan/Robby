--!strict
-- Boss HP bar view (T-023c, D-139). Pure: no services, tested under Lune; client `BossHud` draws it.
-- Turns boss HP + `Phase` into the bar fill, the HP text and the phase cue shown at the top of the screen.

local BossBar = {}

BossBar.SHOW_DISTANCE = 70 -- studs; the bar shows for the nearest boss within this range

export type View = { frac: number, text: string, phaseText: string, enraged: boolean }

function BossBar.view(hp: unknown, maxHp: unknown, phase: unknown): View
	local m = if typeof(maxHp) == "number" and maxHp > 0 then maxHp else 1
	local h = if typeof(hp) == "number" then math.clamp(hp, 0, m) else 0
	local enraged = phase == 2
	return {
		frac = h / m,
		text = `{math.ceil(h)} / {math.floor(m)}`,
		phaseText = if enraged then "Enraged" else "",
		enraged = enraged,
	}
end

-- Index of the nearest distance within SHOW_DISTANCE, or nil.
function BossBar.pick(dists: { number }): number?
	local best, bestD = nil, BossBar.SHOW_DISTANCE
	for i, d in dists do
		if d <= bestD then
			best, bestD = i, d
		end
	end
	return best
end

return BossBar
