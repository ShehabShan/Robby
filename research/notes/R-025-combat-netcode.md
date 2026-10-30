# R-025 Combat netcode & anti-exploit (S8, 2026-10-30)

Goal: confirm or adjust D-030 (Blink, server rewind ≤ 250 ms for melee).

## 1. Findings
- **Server authority:** the server is the single source of truth. Clients send inputs and predict ahead, then roll back and resimulate when the server state differs [1][5]. Roblox's server-authority mode (Studio beta) builds this in; it pairs with the CCL (R-021, parked to here).
- **Melee pattern:** the client plays animation and VFX at once (local prediction) and sends a start-attack intent. The server checks cooldown and cost, then logs the attacker's position with a time [2].
- **Hit validation:** the client may detect hits locally and send a hit request. The server rewinds targets using a **position history buffer** and rebuilds the hitbox. It estimates latency from ping and **ignores client timestamps**, because those can be faked [2]. General lag compensation interpolates between stored snapshots to rebuild what the client saw [6][7][8].
- **UnreliableRemoteEvent:** messages may drop or arrive out of order. Use it only for cosmetic or continuous data (aim direction, FX), with a sequence number so old packets are ignored [3][4].
- **Anti-exploit:** assume every client value is manipulated. Use a server-side **token bucket** rate limit per remote (allows bursts, enforces an average rate). Check that targets are alive and in range, that no static geometry blocks the path, and that cooldown, cost and state are valid (search summary; sources not captured).
- Not found this session: how Rell Seas, Deepwoken and Blox Fruits do it internally (closed source).

## 2. Rules for Robby (D-050, confirms D-030 with additions)
1. **Intent-only remotes (D-043):** one reliable `CastRequest(moveId, aim, seq)` via Blink. The client never sends damage, targets as truth, or timestamps the server trusts.
2. **Client predicts cosmetics only:** animation, VFX, sound, and the local hit flash. The server confirms damage; when it rejects, the flash is undone quietly (no rollback of HP shown).
3. **Server hit check with rewind:** keep a 20 Hz position buffer (1 s) for every character and NPC. Rewind = min(estimated one-way ping + interpolation delay, **250 ms**), then run the hitbox. Above 250 ms, no rewind is applied (high-ping players aim ahead).
4. **Sanity checks for every hit:** target alive and not invulnerable (dash i-frames), range ≤ move range + 4 studs of tolerance, line of sight (one raycast against static geometry), cooldown, Qi and Strain valid, and the caster not stunned.
5. **Rate limits:** a token bucket per player per remote (CastRequest: 10 per second, burst 15). Repeated violations are logged and flagged; there are no auto-bans in M1.
6. **Unreliable channel:** aim updates and FX replication use UnreliableRemoteEvent with `seq`; anything that changes state stays reliable.
7. **Projectiles:** the server runs the sweep (R-021p §5); clients draw a cosmetic copy from the cast event.
8. **Parry and dash windows** are judged on the server at the rewound time, so lag does not unfairly cancel a parry within 250 ms.
9. **CCL / server-authority beta:** re-check at T-010; adopt only for movement if it leaves beta. Combat stays on this model either way.

## 3. Unknowns
- The real ping spread of mobile players (measure in M1 playtests); tune the 250 ms cap and range tolerance from that data.
- Blink packet sizes for 4-player co-op fights (P-008).

## 4. Sources
1. https://create.roblox.com/docs/en-us/projects/server-authority.md
2. https://devforum.roblox.com/t/combat-system-with-rollback/3685525
3. https://create.roblox.com/docs/en-us/scripting/events/remote.md
4. https://devforum.roblox.com/t/introducing-unreliableremoteevents/2724155
5. https://devforum.roblox.com/t/studio-beta-build-fair-responsive-games-with-server-authority/4139157/1
6. https://docs.colyseus.io/netcode/lag-compensation
7. https://snapnet.dev/blog/performing-lag-compensation-in-unreal-engine-5/
8. https://netick.net/docs/2/articles/lag-compensation