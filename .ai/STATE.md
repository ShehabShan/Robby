# STATE

## Now (after S27)
- S27: T-021c hub assembly (D-147): pure `Shared.MistvaleHub` plan + `validate`, server `MistvaleHubBuilder` builds code proxies (houses, RestSpot, Crucible shrine, gate, lanterns, pines, Binding grove marker). Mesh swap waits for `roblox-open-cloud`.
- S25 (cont.): T-023 boss: pure `BossBrain` + Mistmaw Elder (3 telegraphed attacks, phase 2 at 50 %, D-137), `BossService` (D-138), boss HP bar + "Enraged" cue (D-139), arena area in Mistvale layout (D-140). Beast warning sound + boss rings/cones via `BeastFx` (D-136). T-023c doing (Rank-test credit + tuning).
- S26: T-021b Mistvale hub kit (D-146): `art/blender/hub_kit.py` → 14 low-poly pieces (FBX/GLB + manifest, max 824 tris). Roblox upload waits for `roblox-open-cloud`.
- Ops (D-134): CLAIMS has a Bot column; owner can say "release <bot link>" to free a stopped bot's claim.
- S25 (2nd claim): T-022c part 1, beast labels: Rank colour band + red "!" during the wind-up (D-135), plus a red ground ring of strike reach (D-157). T-022c stays doing (Resume from: telegraph VFX/SFX, playtest).
- S25: T-022a/b beasts (D-124, D-125): pure `BeastBrain` + `BeastService`, Mistfang + Stonehide Boar in zone 1, telegraphs ≥ 0.4 s, Shards on kill. T-022c (feel/playtest) open.
- S22: T-025a Mist Lotus utility Kith: ×1.5 Refine while equipped (D-112). T-025b (world placement) waits for T-021c.
- S19: T-021a Mistvale code terrain + StreamingEnabled (D-100). Cloud walk check blocked: `roblox-open-cloud` "not enabled for this project".
- S24: T-020g Unweave now says "Weave removed." (D-123).
- S23: T-020f Path Marks to client (D-122): Loom panel shows real Friction + Marks boost.
- S21: T-020e Loom client `LoomHud` (D-111) → **T-020 done**.
- S20: T-020d Loom UI pure `Shared.LoomUi` + spec + mock (D-110). T-020e (client) split out.
- S18: T-020c Weave content + server Loom (D-090): Piercing Edge support, Blink `WeaveSet` at rest spots, `LoomService`, woven casts.
- S17: T-019e client CrucibleHud (D-086) → **T-019 done**. Parallel sessions via git branches (D-087: `.ai/CLAIMS.md`, `claim.sh`, `merge.sh`, AGENTS §9). T-020 split a–d; T-020a Loom core (D-088) and T-020b Path Marks (D-089) done.
- S16: T-018f breakthrough wiring; T-019a–d Crucible core, focus mini-game, server + Recoil, Twin Crescent (D-080–D-085).
- Last publish: v14 (S15, D-078). Crucible, Loom (incl. Weaves) and Marks are not yet cloud-tested or published.

- **Phase:** 3 — Building (P-006 approved, D-049).
- **Doing:** —
- **NEXT:** T-021 … T-024 (ROADMAP.md order).
- **Parallel sessions:** check `.ai/CLAIMS.md` first (AGENTS §9).
- **Parallel lanes** (task · after):
  
  - T-022c Beast feel + playtest (doing: tuning + real SFX left) · —
  - T-023c Boss Rank-test credit + tuning · playtest needs `roblox-open-cloud` (T-023a/b done)
  - T-025b Lotus in the world · — (T-021c done)
  - T-021a-v Cloud walk check · owner reconnects `roblox-open-cloud`
  - T-024 First 10 minutes · all above
- **Budget:** 50 OLU hard cap per session. Wrap up at 43; close-out by 45 (AGENTS.md §1).
- **Blockers:** T-006: owner playtest of the published build (feedback → inbox). Owner: reconnect the `roblox-open-cloud` integration (cloud tests + publish fail: "not enabled for this project", S19).
- **Last check.sh:** CHECK: PASS (2026-10-30, S27)
- **Notes:** Remotes are Blink (`net/remotes.blink` → `src/*/Net.luau`). Crucible key: PC C (F is Parry), gamepad D-pad Right.