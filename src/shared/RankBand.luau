--!strict
-- Rank colour band for enemy labels (T-022c, D-135; GDD "Rank gap": 1 Rank above = warning, 2 above = near
-- unwinnable). Pure: compares the viewer's Rank with the enemy's.

local RankBand = {}

export type Band = { name: string, r: number, g: number, b: number }

RankBand.BANDS = {
	weak = { name = "weak", r = 160, g = 160, b = 160 },
	even = { name = "even", r = 235, g = 235, b = 235 },
	warn = { name = "warn", r = 255, g = 170, b = 40 },
	danger = { name = "danger", r = 255, g = 60, b = 60 },
} :: { [string]: Band }

local function rankOf(v: any): number
	return if typeof(v) == "number" and v >= 1 then math.floor(v) else 1
end

function RankBand.of(viewerRank: any, enemyRank: any): Band
	local gap = rankOf(enemyRank) - rankOf(viewerRank)
	if gap >= 2 then
		return RankBand.BANDS.danger
	elseif gap == 1 then
		return RankBand.BANDS.warn
	elseif gap <= -1 then
		return RankBand.BANDS.weak
	end
	return RankBand.BANDS.even
end

return RankBand
