# R-021 Ability/effect frameworks (S8, 2026-10-30)

Goal: a data-driven model where Kith, Weaves and Paths are data and a new Kith needs no new code. Scored against the R-021p checklist (`research/notes/R-021p-ability-catalogue.md` §6; D-043).

## 1. Candidates
- **A. Unreal GAS (ported concepts):** Attributes, Gameplay Effects as the only state mutators, Modifiers (Add/Multiply/Override) with one aggregation formula, Execution Calculations for complex damage, stacking by source or target with caps and refresh, hierarchical Gameplay Tags, Abilities that orchestrate costs, cooldowns and effects [1][2][3].
- **B. Path of Exile support gems:** supports modify the *resulting* skill (not the gem); compatibility by skill types (`requireSkillTypes` / `excludeSkillTypes`) [4][5]. Covers Weaves only.
- **C. Warframe mods:** each mod drains capacity; capacity grows with item rank; polarity match halves drain, mismatch +25% [6][7]. Covers the loadout budget only.
- **D. Roblox Character Controller Library (CCL):** abilities as Luau tables with OnSetup/OnStart/OnUpdate/OnStop; server authority, client prediction, rollback resimulation; **Studio beta** [8][9][10].
- **E. Hand-written per-Kith modules (the spike today):** one Luau module per move (`CrescentCut.luau`).

## 2. Score vs R-021p §6 (P pass · ~ partial · F fail · — out of scope)
| # | Checklist point | A GAS | B PoE | C WF | D CCL | E per-Kith | **F Hybrid** |
|---|---|---|---|---|---|---|---|
| 1 | All triggers | P | — | — | ~ | F (code each) | P |
| 2 | All deliveries incl. Inh, Sum | ~ (no delivery layer) | P (Inh) | — | ~ | F | P |
| 3 | Composable effect lists | P | ~ | — | F | F | P |
| 4 | Timed/channel/persistent/stack | P | — | — | ~ | F | P |
| 5 | Costs incl. HP-for-Qi, reserve | P (cost effects) | — | P (capacity) | F | F | P |
| 6 | One Channel primitive | ~ | — | — | P (OnUpdate) | F | P |
| 7 | Tags/states queried | P | P (skill types) | ~ (polarity) | F | F | P |
| 8 | Path-scoped modifiers, one calc | P | ~ | ~ | F | F | P |
| 9 | Non-combat systems use same types | P | — | — | F | F | P |
| 10 | Per-viewer info, server-trusted | ~ (replicated tags only) | — | — | F | F | P |
| 11 | Server authority + client FX prediction | P | — | — | P | P (spike) | P |
| 12 | FX hooks by id | P (cues) | — | — | ~ | F | P |
| 13 | Moveset override + restore | P (granted abilities) | — | — | ~ | F | P |
| 14 | Save stores sources, not numbers | P | P | P | — | F | P |
| 15 | Tick/entity budgets | ~ | — | — | ? | ~ | P |
- **E fails 1–10:** every Kith would need new code. Rejected.
- **D fails 3, 5, 7–10** and is beta; it is a movement/lifecycle layer, not an effect system. Parked: re-check in R-025 for dash/movement prediction only.
- **A passes most** but has no delivery layer and no per-viewer info, and a full port is heavy. **B** and **C** solve one slice each.
- **F = A's core + B's supports + C's budget + our own delivery and viewer layers.** Passes all 15 by design; T-002 tests prove it row by row.

## 3. Recommended model F: "Kith GAS-lite" (pure Luau, `src/shared`)
- **Attributes:** HP, Qi, QiMax, QiRegen, Strain, Will, Power per Path, MoveSpeed, … Base values from Rank/Talent; current values = one aggregation over active Modifiers (R-022 order: base → additive % → multiplicative → caps such as Friction ≥ −20%).
- **Tags:** hierarchical strings (`Path.Moon`, `Role.Strike`, `State.Guarding`, `State.Stealthed`, `Delivery.Proj`). Effects add/remove tags; conditions query them.
- **Effect** (data): `{id, duration = Inst|Timed|Chan|Pers, period?, stack = {cap, by = source|target, refresh}, modifiers = {...}, ops = {Dmg|Heal|Res|Drain|Disp|Intr|Spawn|Reveal|Xform|Rewind}, grantTags, removeTags, requireTags, fx}`. The only way state changes — combat, Crucible (Recoil, Wounded), Upkeep (Dormant) and Strain (Exhausted) all apply Effects.
- **Move** (data, one per Kith move): `{id, kith, trigger, target, delivery = {kind, params}, costs = {qi, strain, hp?, use?}, cooldown, effects = {onHit, onCast, onEnd}, tags, fx = {cast, travel, hit, loop, end}}`. Cooldowns keyed (caster, moveId).
- **Deliveries** (~8 code modules, written once): Melee box, Projectile (the spike's server sweep), Beam, AoE, Zone (persistent; optional HP for Qi Wells), Summon (owner, HP, lifetime, drain, Will cap), Self, System. Each takes params from data.
- **Channel primitive:** ticks with per-tick cost and effect, interrupt tags (`Intr.Stagger`, `Intr.Parry`, `Intr.Burst`), cancel event. Used by Guard, Binding, Crucible focus, Scatter, beams, drains.
- **Weave supports (PoE-style):** `{id, requireTags, excludeTags, deliveryMods = {range, pierce, bounce, …}, addEffects = {onHit = …}, costMult}`. The Loom validates tags and shows Friction; supports never have their own delivery (Inh).
- **Loadout budget (Warframe-style):** passives and auras reserve % of QiMax (Qi Reserve); the Heart Kith's Path cuts reserve/cost like a polarity match. Talent sets QiMax, so it shapes builds.
- **Viewer layer:** the server sends tags per entity (`State.Stealthed`, exact Rank); each client renders by its own Seek/Path Sense effects. Targeting of stealthed foes is still checked on the server.
- **Persistence:** profile stores sources (Marks, Imprints, Bond, instances), never final numbers; stats rebuilt at login (ARCH §9).

## 4. Catalogue coverage (R-021p §2 → model F)
- Rows 1–3, 9, 14, 38–39, 43, 45, 49: Move + one Delivery + Dmg/Disp ops.
- Rows 4–6, 50: Effects with tags (`State.Guarding`, parry window) + OD/OH triggers.
- Rows 7, 10, 13, 16–18, 26, 33, 36, 51: persistent Effects with Path-scoped Modifiers (aura = Zone around owner).
- Rows 15, 40: Weave support `addEffects.onHit` + stack rules.
- Rows 19–21, 23–24, 34, 37: System delivery + Effects from non-combat systems; Rewind op restores a server snapshot.
- Rows 22, 29, 46: Channel primitive. Rows 12, 25, 30, 32, 47, 52: Zone/Summon deliveries.
- Rows 27–28: cost forms (reserve, HP substitution) + stacking Core Crack Effect.
- Rows 31, 35, 41: Reveal op + viewer layer. Row 44: Xform op (granted moves, restore on expiry). Row 48: Effect with `requireTags`/Will check.
- Rows 53–60 (Styles, Armaments, Talismans): Move records on Melee/Projectile deliveries, Xform for forming the weapon, Inh for infusion/Resonance, persistent modifiers for Talismans — no new delivery.
- Result: all 60 rows are data over 8 deliveries and 12 effect ops; no per-Kith code.

## 5. Migration of the spike (input for T-002)
- `CrescentCut.luau` → a Move record + the generic Projectile delivery (keep `stepProjectile`, `registerHit`, aim validation).
- `Qi.luau` → `Resource` (reserve, regen modifiers, HP substitution). `Abilities.luau` → one `CastRequest(moveId, aim)` remote, cooldowns per (caster, moveId), Effect pipeline. `CrescentFx.luau` → FX registry keyed by fx id.

## 6. Risks
- Over-engineering: build only the deliveries and ops the vertical slice needs first (Proj, Mel, Self, System, Channel, Zone); the rest when their Kith arrive.
- Performance: Effect ticks ≥ 0.5 s, modifier caches invalidated only on change, entity caps per player (P-008 sets numbers).

## 7. Sources
1. https://dev.epicgames.com/documentation/unreal-engine/gameplay-effects-for-the-gameplay-ability-system-in-unreal-engine?lang=en-US
2. https://gas.spoked.dev/gameplay-effects/modifiers/ · https://gas.spoked.dev/gameplay-effects/duration-and-lifecycle/ · https://gas.spoked.dev/gameplay-effects/execution-calculations/
3. https://gas.spoked.dev/getting-started/mental-model/
4. https://pathofexile.fandom.com/wiki/Support_Skill_Gems
5. https://deepwiki.com/PathOfBuildingCommunity/PathOfBuilding-PoE2/4.2-support-gems-system
6. https://wiki.warframe.com/w/Mod
7. https://wiki.warframe.com/w/Polarity
8. https://create.roblox.com/docs/en-us/characters/character-controller-library.md
9. https://devforum.roblox.com/t/studio-beta-expanding-the-character-controller-library-new-default-abilities-custom-abilities-api/4863739
10. https://create.roblox.com/docs/en-us/projects/server-authority.md