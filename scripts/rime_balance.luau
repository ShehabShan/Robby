-- T-027g balance runner: `lune run scripts/rime_balance.luau`. Prints TTK (s) and cast counts; log results in RESEARCH.
local Config = require("../src/shared/Config")
local Sim = require("../src/shared/RimeshardSim")

local function casts(c: { [string]: number }): string
	local parts = {}
	for k, v in c do
		table.insert(parts, `{k}={v}`)
	end
	table.sort(parts)
	return table.concat(parts, " ")
end

local function row(label: string, hp: number, n: number, opts)
	local cres = Sim.crescent(Config, Sim.targets(hp, n))
	local rime = Sim.rimeshard(Config, Sim.targets(hp, n), opts)
	print(
		`{label}: Crescent {string.format("%.1f", cres.ttk or -1)} s [{casts(cres.casts)}] | Rimeshard {string.format(
			"%.1f",
			rime.ttk or -1
		)} s [{casts(rime.casts)}]`
	)
end

row("Mistfang 60 x1", 60, 1)
row("Boar 140 x1", 140, 1)
row("Mistmaw 800 x1", 800, 1)
row("Mistfang 60 x5 pack", 60, 5)
row("Boar 140 x3 pack", 140, 3)
row("Mistmaw 800 x1 (finisher recovery 0.25)", 800, 1, { finisherRecovery = 0.25 })
