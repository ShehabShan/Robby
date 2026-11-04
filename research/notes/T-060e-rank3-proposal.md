# T-060e — Stronger Rank 3 (plan only, owner picks) — S158

Problem (owner 2026-11-04): Rank 3 has only Full Moon (defensive Guard Ring, D-411), so it feels weaker than Rank 2.
All options keep Full Moon's guard, reuse GuardRing/Volley/Projectile code, server-validated, one cost.

**A. Release Burst (recommended).** Press = ring as today. Press again (or ring times out) = the 4 ring blades fire
straight outward from where they are, each = 1 Crescent Cut hit, range ~30. If the ring shatters on a touch it does not
fire. Small build: GuardRing state + Volley ring directions already exist (Ring.directions).

**B. Aimed Release.** Like A but all 4 blades converge forward along the free 3D aim (T-053a1), crossing like Twin
Crescent. Higher single-target damage, more code (paths).

**C. Charged Moon.** Hold to grow the ring (radius 5→8 over 1 s); release = outward burst; damage scales with charge.
Most feel, most work (hold input + charge state + UI).

Default if no pick: A. Build task after pick: T-060e1 (pure rule + specs), T-060e2 (server wiring + FX).
