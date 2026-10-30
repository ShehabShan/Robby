# ROADMAP (P-005, S6, 2026-10-30)

Inputs: GDD v1 (§11 vertical slice, §12 out of scope), ART.md (quality bar), ARCHITECTURE.md (module map), D-025…D-030.
Every task is S-sized (≤ 30 OLU of work, AGENTS §0). Split a task before starting it if it might not fit. Building starts only after **P-006** (owner approval).

## Milestones
| # | Milestone | Exit criteria |
|---|---|---|
| M1 | **Vertical slice** | GDD §11 content playable on PC, mobile and gamepad; ART §5 quality bar met; owner playtest done |
| M2 | Core content | Mistvale complete (3 zones, rival camp); 8 Kith; 3 Crucible recipes; 3 Weaves; Ranks 1→3 |
| M3 | Progression & economy | Ranks 1→5, Paths and Marks, Clans vs Rogues, shop and Jade, ProfileStore migrations tested |
| M4 | Polish | Owner/animator art pass, music, performance budgets on device, onboarding tuning from playtests |
| M5 | Soft launch | Public release of Mistvale; analytics on retention and funnel; live-ops plan |

## Prerequisites (before M1)
- **T-002** Refactor the spike into the ARCHITECTURE §3 module map; add Wally deps (Blink, ProfileStore, Trove, Signal). AC: check PASS.
- **T-010** Cloud test pipeline (Open Cloud place upload + Luau Execution + test runner). Needs the key fix (T-005b).

## M1 tasks
| ID | Task | AC |
|---|---|---|
| T-011 | Blink networking replaces spike RemoteEvents | Cast/hit flow works through Blink; check PASS |
| T-012 | DataService + ProfileSchema v1 (ProfileStore) | Profile load/save/migrate tested in Lune + cloud |
| T-013 | Combat core: 5-hit chain, dash (i-frames), parry, guard-break | Pure modules tested; server rewind ≤ 250 ms |
| T-014 | HitFeel module (hit-stop, shake, flash, numbers) shared by all moves | ART §5 items 2 and 5 |
| T-015 | Stone guard Kith + Wind dash Kith moves | Two new moves with VFX, server-validated |
| T-016 | Core slots, loadout, role tags and Qi/Strain/Satiety HUD | 3 slots at Rank 1; gap warning; phone HUD readable (mock first); UI on all platforms |
| T-017 | Binding tug-of-war + Heart Kith | Channel-vs-Will bar, Shards top up Qi; guided first bind cannot fail and becomes the Heart Kith |
| T-018 | Upkeep (Satiety), Strain, Stages as Core Shell + breakthrough trial | Dormant/Exhausted states tested in Lune; Shell visual per Stage; Rank 1→2 wave trial |
| T-019 | Crucible: 1 recipe + focus mini-game | Merges two Kith; fail odds shown; fail = catalyst lost + Wounded, never destroyed |
| T-020 | Weave Loom: 1 Weave (core + 1 support) + Path Marks | Resonance hint; Weave recorded in journal; Marks add % power; Friction shown |
| T-021 | Mistvale terrain + hub kit (code terrain, Blender kit) | Hub and 1 zone walkable; budgets met |
| T-022 | Enemies: 2 beasts (brain + telegraphs) | Telegraphs ≥ 0.4 s; server-owned AI |
| T-023 | Boss + arena | Every attack telegraphed; beatable at Rank 1–2 |
| T-025 | Qi-refining utility Kith (before T-024) | Speeds Stage gain; obtainable in Mistvale |
| T-024 | First 10 minutes (GDD §8) + mentor/rival NPCs | Full flow playable end to end; owner playtest (T-006 path) |

## Risks
- **Animation throughput** (D-029): code tweens are the fallback; an animator budget is the owner's decision.
- **Cloud testing** depends on the Open Cloud key fix (T-005b).