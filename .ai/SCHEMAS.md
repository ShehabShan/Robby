# SCHEMAS (P-008, S9, 2026-10-30)

Data model for ARCHITECTURE v2 (D-052). Sources: R-021 model F, R-022, R-023, R-024, R-025, R-026, and ARCHITECTURE §9.
The types are written in Luau. T-002 turns them into `src/shared/Types.luau`. Numbers are first values; `Config` owns them.

## 1. Conventions
- Ids are stable strings: `kith.crescent`, `move.crescent_cut`, `fx.crescent.hit`. Ids are never reused. Removed ids go to `Retired` (old id → replacement or nil).
- Content is data in `src/shared/Content/*`. `Registry` loads and validates it at boot, and Lune tests validate every record.
- Saves hold **sources** (ids, Marks, Bond, timestamps), never derived numbers. Stats are rebuilt at login.
- Time is stored as Unix seconds (expiry or start) and resolved lazily. There are no ticks in saves.

## 2. Attributes & Modifiers
```lua
type AttrId = "HP"|"HPMax"|"Qi"|"QiMax"|"QiRegen"|"Strain"|"StrainMax"|"Will"|"Guard"|"MoveSpeed"|string -- "Power.<Path>"
type Bucket = "Add" | "Boost" | "Surge" | "Override" -- flat, additive %, multiplicative, set
type Modifier = { attr: AttrId, bucket: Bucket, value: number, requireTags: {string}? }
```
- One aggregation, `Stats.compute(base, mods)`, runs (base + ΣAdd) × (1 + ΣBoost) × ΠSurge (capped at ×3), then Override, then caps (Friction ≥ −20%).
- Damage goes through `DamageMath` (R-022): Base × Potency(Rank, Stage) × (1+ΣBoost) × ΠSurge → Guard `raw×K/(K+Guard)` (K by the attacker's Rank) → Friction. Potency is ×1.6 per Rank. The Marks boost is 0.6·M/(M+60).
- Caches are invalidated only when a modifier list changes.

## 3. Tags
- Tags are hierarchical strings: `Path.Moon`, `Role.Strike`, `Delivery.Proj`, `State.Guarding`, `State.Stealthed`, `State.Wounded`, `State.Dormant`, `Intr.Stagger`, `Intr.Parry`, `Intr.Burst`.
- `Tags.has(set, "State")` matches every child tag. Tag sets are counted, so two sources of the same tag need two removals.

## 4. Effect (the only state mutator)
```lua
type Op = { kind: "Dmg"|"Heal"|"Res"|"Drain"|"Disp"|"Intr"|"Spawn"|"Reveal"|"Xform"|"Rewind", params: {[string]: any} }
type Effect = {
	id: string,
	duration: "Inst" | "Timed" | "Chan" | "Pers",
	seconds: number?, period: number?, -- period >= 0.5 s
	stack: { cap: number, by: "source" | "target", refresh: boolean }?,
	modifiers: {Modifier}?, ops: {Op}?,
	grantTags: {string}?, removeTags: {string}?, requireTags: {string}?, blockTags: {string}?,
	fx: string?,
}
type ActiveEffect = { effectId: string, sourceUid: string, stacks: number, endsAt: number? }
```

## 5. Move & Delivery
```lua
type DeliveryKind = "Projectile"|"Melee"|"Beam"|"AoE"|"Zone"|"Summon"|"Self"|"System"
type Move = {
	id: string, kith: string?, trigger: "Press"|"Hold"|"Passive"|"OnHit"|"OnDamaged"|"System",
	target: "Aim"|"Self"|"Area"|"Lock",
	delivery: { kind: DeliveryKind, params: {[string]: any} }, -- e.g. speed, range, radius, pierce
	costs: { qi: number?, strain: number?, hp: number?, uses: number? },
	cooldown: number, channel: { tick: number, maxTime: number, interruptBy: {string} }?,
	effects: { onCast: {string}?, onHit: {string}?, onEnd: {string}? },
	tags: {string}, fx: { cast: string?, travel: string?, hit: string?, loop: string?, ["end"]: string? },
}
```
- Cooldowns are keyed by (caster, moveId). Each delivery is a code module in `Deliveries/*` that reads only `params`.
- Slice first: Projectile (from the spike's `stepProjectile`), Melee, Self, System, Zone, plus the Channel primitive.

## 6. Kith, Weave, Path
```lua
type KithSpecies = { id: string, rank: number, path: string, role: string, tags: {string},
	moves: {string}, food: string, reservePct: number?, rarity: "Common"|"Rare"|"Singular" }
type KithInstance = { uid: string, speciesId: string, satiety: number, strain: number,
	woundedUntil: number?, dormant: boolean, bond: number, obtainedAt: number }
type WeaveSupport = { id: string, requireTags: {string}, excludeTags: {string},
	deliveryMods: {[string]: number}?, addEffects: { onHit: {string}? }?, costMult: number }
type Weave = { id: string, core: string, supports: {string} } -- a core Move id + support ids; the Loom shows Friction
type Path = { id: string, tag: string, frictionWith: {[string]: number}, groundEffect: string? }
```
- Equip rules are checked in `Loadout`: Rank lock (Kith rank ≤ player Rank), Qi Reserve (Σ reservePct of QiMax), and a Heart Kith polarity discount on its Path.

## 7. Profile (ProfileStore, `schemaVersion` = 1)
```lua
type Profile = {
	schemaVersion: number,
	talent: "A"|"B"|"C"|"D", rank: number, stage: number,
	cores: { { heartKith: string? } }, -- a list, default 1, so a Twin Core needs no migration
	marks: {[string]: number}, imprints: { { path: string, slot: number } },
	kith: {[string]: KithInstance}, loadout: { slots: {string}, weaves: {Weave} },
	journal: { recipes: {string}, weaves: {string}, codex: {string} },
	wallet: {[string]: number}, -- by tier: { shards = 0 }; exchange is one-way upward
	timers: {[string]: number}, -- e.g. stipendClaimedAt (cap 7 unclaimed days), bountyResetAt
	onboarding: { step: number, done: boolean },
	stats: { earned: {[string]: number}, spent: {[string]: number} },
	receipts: {[string]: boolean}, settings: {[string]: any},
}
```
- Load runs ordered pure migrations (Lune-tested from every past version) → Reconcile → validate (unknown ids map through `Retired`).
- Shared world state (Singular Kith owners, Ascendant) is never stored in profiles. It needs a MemoryStore/DataStore lock, and not before Ascendant.

## 8. Config & flags
```lua
type Flag = { enabled: boolean, fallback: any } -- coded fallback if remote config is missing
type Bound = { min: number, max: number }       -- remote tuning is clamped to bounds
```
- Each new system ships behind a flag. First values are Rank costs [1000, 3700, 13200, 32300] and Refill ×1.4 per Rank (D-046).

## 9. Remotes (Blink, D-050)
| Remote | Dir | Reliability | Payload |
|---|---|---|---|
| `CastRequest` | C→S | reliable | moveId: string, aim: vector, seq: u16 |
| `Action` | C→S | reliable | kind: Attack/Dash/Parry/Guard, dir: vector?, seq |
| `Aim` | C→S | unreliable | aim: vector (FX only, never trusted) |
| `CastFx` / `HitFx` | S→C | unreliable | fxId, caster, pos, dir |
| `EntityState` | S→C | reliable | uid, hp, qi, tags (viewer layer), rank |
| `ProfileDelta` | S→C | reliable | changed paths only |
- The server rewinds a 20 Hz, 1 s position buffer by min(ping estimate, 250 ms), ignoring client timestamps. Every hit passes sanity checks (alive, i-frames, range + 4 studs, line of sight, cooldown/Qi/Strain). Rate limits are token buckets per remote.

## 10. Analytics (D-051, R-023)
- `AnalyticsService:LogOnboardingFunnelStepEvent` fires once per GDD §8 beat (steps 1–9).
- Economy events log every faucet and sink by tier. Rank-ups, Stage-ups and Binding results are custom events.