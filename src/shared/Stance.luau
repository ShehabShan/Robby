--!strict
-- Kith stance (T-027d1, D-184): the pure state machine behind the left-click swap. Off: left click is the
-- light chain (CombatService). On: left click fires the active Kith's chain move (Rimeshard Needle shots 1–2),
-- the third press its finisher, then a finisher pause (D-182). Z/X/C specials work in both stances (D-186);
-- while the stance is on, Needle shot 2 can cancel straight into a special (R-028 note §6).
-- The client runs it to pick the move and show FX at once; the server runs the same machine on its own clock
-- to verify every CastRequest, so the client never decides what lands (server authority).

local Combat = require("./Combat")

export type Cfg = { chain: Combat.ChainCfg, finisherRecovery: number }
export type Kit = { chain: string, finisher: string, specials: { string } }
export type State = { on: boolean, chain: Combat.Chain, finisherAt: number }

local Stance = {}

Stance.FINISHER_SUFFIX = "_finisher"

function Stance.new(): State
	return { on = false, chain = Combat.newChain(), finisherAt = -math.huge }
end

-- Builds a Kith's Kit from its Registry entry: the chain move is the one carrying a `chain` table, the finisher
-- is `<chain id>_finisher` (D-185), every other move is a special. nil when the Kith has no chain move.
function Stance.kit(kith: any, moves: { [string]: any }): Kit?
	local chainId: string? = nil
	for _, id in kith.moves do
		local move = moves[id]
		if move and move.chain then
			chainId = id
			break
		end
	end
	if chainId == nil then
		return nil
	end
	local finisher = chainId .. Stance.FINISHER_SUFFIX
	local specials: { string } = {}
	for _, id in kith.moves do
		if id ~= chainId and id ~= finisher then
			table.insert(specials, id)
		end
	end
	return { chain = chainId, finisher = finisher, specials = specials }
end

-- Flips the stance; a chain in progress is dropped. Returns the new state.
function Stance.toggle(s: State): boolean
	s.on = not s.on
	s.chain = Combat.newChain()
	return s.on
end

local function inPause(s: State, now: number, cfg: Cfg): boolean
	return now - s.finisherAt < cfg.finisherRecovery
end

local function inRecovery(s: State, now: number, cfg: Cfg): boolean
	return s.chain.step > 0 and now - s.chain.lastAt < cfg.chain.recovery
end

-- A left click while the stance is on: the chain move, the finisher on the last step, or nil while blocked
-- (chain recovery or the finisher pause). nil when the stance is off: the caller sends a light attack instead.
function Stance.press(s: State, now: number, cfg: Cfg, kit: Kit): string?
	if not s.on or inPause(s, now, cfg) then
		return nil
	end
	local step = Combat.press(s.chain, now, cfg.chain)
	if step == nil then
		return nil
	end
	if step >= cfg.chain.steps then
		s.finisherAt = now
		s.chain = Combat.newChain()
		return kit.finisher
	end
	return kit.chain
end

-- Z/X/C: true when `moveId` is a Kit special the player may fire now. Blocked by the finisher pause and by chain
-- recovery, except that shot 2 of the chain cancels into a special (note §6). A special ends the chain.
-- Qi, cooldown and Strain are the server's job (Moves.pay), not the stance's.
function Stance.special(s: State, now: number, cfg: Cfg, kit: Kit, moveId: string): boolean
	if table.find(kit.specials, moveId) == nil or inPause(s, now, cfg) then
		return false
	end
	if inRecovery(s, now, cfg) and not Stance.canCancel(s, now, cfg) then
		return false
	end
	s.chain = Combat.newChain()
	return true
end

-- True while the chain sits on shot 2 inside its combo window: the moment a special may cancel in.
function Stance.canCancel(s: State, now: number, cfg: Cfg): boolean
	return s.on and s.chain.step == 2 and not inPause(s, now, cfg) and now - s.chain.lastAt <= cfg.chain.window
end

-- Server check of a CastRequest: the machine must produce exactly `moveId` now. A mismatch leaves the state as it
-- was, so one bad request cannot desync an honest client. Moves outside the Kit pass untouched.
function Stance.verify(s: State, now: number, cfg: Cfg, kit: Kit, moveId: string): boolean
	if table.find(kit.specials, moveId) ~= nil then
		return Stance.special(s, now, cfg, kit, moveId)
	end
	if moveId ~= kit.chain and moveId ~= kit.finisher then
		return true
	end
	local saved = { on = s.on, step = s.chain.step, lastAt = s.chain.lastAt, finisherAt = s.finisherAt }
	if Stance.press(s, now, cfg, kit) == moveId then
		return true
	end
	s.on = saved.on
	s.chain = { step = saved.step, lastAt = saved.lastAt }
	s.finisherAt = saved.finisherAt
	return false
end

return Stance
