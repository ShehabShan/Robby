# R-022 — Stats, modifiers & damage maths (S7, 2026-10-30)

Draft model for P-008. Numbers are starting points; P-007b tunes them. Curve check: `research/sims/r022_curves.py`.

## 1. Findings (sourced) → Robby rule

| # | Finding | Src | Robby rule (draft) |
|---|---|---|---|
| 1 | Two stacking buckets: "increased" mods are summed then applied once (diminishing value as the sum grows); "more" mods each multiply (compounding, more valuable). | [1][2][3] | **Two buckets only:** *Boost* (additive %, summed: Marks, gear, buffs) and *Surge* (multiplicative: Weave supports, Mastery, Path Ground). Few Surge sources, each small, so power stays readable. |
| 2 | A fixed order (base → added → increased → more → mitigation) keeps damage predictable and testable. | [1][4] | **Fixed pipeline:** Base × Potency(Rank, Stage) × (1 + ΣBoost) × ΠSurge → Guard → Friction. One pure module (`DamageMath`), unit-tested in Lune. |
| 3 | Hyperbolic reduction `taken = raw × K/(K+Armor)` gives diminishing returns with no hard cap and no immunity; K = armor for 50% reduction. | [5][6][7] | **Guard:** `taken = raw × K/(K+Guard)`, with K scaled by the *attacker's* Rank (K = 50 × 1.6^(Rank−1)). Guard never reaches 100%; high-Rank hits pierce low-Rank Guard. |
| 4 | Soft caps / hyperbolic curves stop stacking one stat from breaking the game (power creep). | [6][8] | **Marks boost** = 0.6 × M/(M+60): 10 Marks → +9%, 60 → +30%, 200 → +46%, capped below +60%. Surge product capped at ×3. |
| 5 | MMOs apply level-gap factors (e.g. ±10–20% per level beyond a gap, with a floor) to keep out-leveled content safe and over-levelled content harmful. | [9][10] | **No extra gap penalty needed:** the Rank gap comes from Potency (×1.6/Rank) and Guard K. An optional ±10%/Rank factor stays in Config, off by default. |

## 2. Curve check (sim output, base 20 dmg × 1.5 hits/s, enemy HP 300 × Potency)
| Player Rank 1 vs enemy | Fresh build TTK | Best build TTK |
|---|---|---|
| same Rank | 10.0 s | 3.4 s |
| +1 Rank | 16.0 s | 5.4 s |
| +2 Rank | 25.6 s | 8.7 s |
- Best/fresh DPS ≈ 2.95 (target ≤ 3): build skill matters, but a fresh player can still contribute.
- Peak Stage → next Rank's First Stage = ×1.23 jump (breakthroughs feel big).
- Guard 50 halves a same-Rank hit but only cuts a +2-Rank hit to 72%.

## 3. Unknowns
- Enemy damage/HP per zone tier and Strain/Qi cost curves (P-007b).
- Whether ×1.6/Rank stays fair in opt-in PvP (needs Rank-banded arenas, GDD §9).

## 4. Sources
1. https://www.poe2.dev/mechanics/damage-types
2. https://www.poewiki.net/wiki/Damage_variance
3. https://www.pathofexile.com/forum/view-thread/320366
4. https://poedb.tw/us/StatsAndMods1
5. https://darky-lucera.github.io/roguelike-tutorial-python-tcod/append-1.html
6. https://gamemechanicshoard.com/mechanic/soft-caps-diminishing-returns/
7. https://blog.lokkij.com/reduction-systems-in-games/
8. https://warcraft.wiki.gg/wiki/Damage_reduction
9. https://github.com/TrinityCore/TrinityCore/issues/15244
10. https://pso2.arks-visiphone.com/wiki/Damage_Formula_(NGS)