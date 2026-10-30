# STATE

## Now (after S25)
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
  - T-021b Mistvale hub kit (Blender) · —
  - T-022c Beast feel + playtest · — (T-022a/b done)
  - T-021c Hub assembly · T-021b (T-021a done)
  - T-023 Boss + arena · — (T-022a/b done)
  - T-025b Lotus in the world · T-021c (T-025a done)
  - T-021a-v Cloud walk check · owner reconnects `roblox-open-cloud`
  - T-024 First 10 minutes · all above
- **Budget:** 50 OLU hard cap per session. Wrap up at 43; close-out by 45 (AGENTS.md §1).
- **Blockers:** T-006: owner playtest of the published build (feedback → inbox). Owner: reconnect the `roblox-open-cloud` integration (cloud tests + publish fail: "not enabled for this project", S19).
- **Last check.sh:** CHECK: PASS (2026-10-30, S25)
- **Notes:** Remotes are Blink (`net/remotes.blink` → `src/*/Net.luau`). Crucible key: PC C (F is Parry), gamepad D-pad Right.