# T-026a — R15 movement system: inspection + plan (S28, D-160)

Source: `assets/source/R15 Movement System.rbxm` (owner upload, inbox 2026-10-30-r15-movement).
Tool: `lune run scripts/inspect_rbxm.luau "<file>" build/rbxm` prints the tree and extracts script sources to `build/rbxm/` (gitignored, never committed).

## What it is
A third-party Studio kit, "R15 Arczis Movement System". Top-level folders are named after Roblox services ("move each folder into the matching service", per its `Tutorial` script). About 3,800 lines of Luau, no `--!strict`, no loadstring/HttpService/require-by-id.

| Part | Scripts (lines) | What it does |
|---|---|---|
| StarterCharacterScripts | Animate2 (495) | Replaces the default `Animate`: idle/walk/run/jump/fall/climb/crouch; LeftShift = run (sets WalkSpeed client-side) |
| | Crouching (394) + 2 sounds + 2 anims | Crouch / crouch-walk on C, ButtonL |
| | Turning (237), Lean (151), LandAnim (12) | Body turn toward move direction, lean into turns, landing anim |
| | CustomShiftLock (7) → SmoothShiftLock (172), Maid (223), Spring (246) | Custom shift lock on LeftControl (changes MouseBehavior) |
| StarterGUI | Bobbing Camera (59) | Camera bob while walking |
| StarterPlayerScripts | Footsteps (296), RbxCharacterSounds (453) + AtomicBinding (277) | Footstep sounds by material; replaces default character sounds |
| ReplicatedStorage | FootstepModule (206) + Footsteps/Landing/Jumping × Default/Water/Fart | Sound tables per surface |
| | RemoteEvent `UpdateRunningState` | Fired by Animate2, Crouching, Lean; no server handler in the kit |
| ServerScriptService | DisableDefaultShiftLock (8) | Turns off Roblox shift lock |
| Animations | 1 rig Model, 7 KeyframeSequences | Animation sources (Studio saves), not uploaded assets |
| SoundService | SoundGroup Main/Character | Volume groups |

Asset references: 267 unique `rbxassetid://` ids (sounds + animations owned by the kit author).

## Conflicts with Robby
- **Keys:** kit LeftShift (run) = Robby Dash (`CombatInput`); kit C (crouch) = Robby Crucible (`CrucibleHud`); kit ButtonL is used by Robby too.
- **Camera/mouse:** SmoothShiftLock changes `MouseBehavior`; Robby aims at the mouse (D-067).
- **Server authority:** run speed is set only on the client; no server cap.
- **Content (D-014 / mild rating):** "Fart" sound variants.
- **Assets:** animations owned by another creator usually will not play in our experience; they must be re-uploaded under the owner (unverified; needs `roblox-open-cloud`).

## Plan (D-160)
Port selectively, not as a drop-in. Logic goes in pure `src/shared` modules with specs; client scripts stay thin.
- **T-026b1** Feel: Turning, Lean, Bobbing Camera, LandAnim → pure `Shared.MoveFeel` (tilt/turn/bob math) + client `MoveFeelClient`.
- **T-026b2** Footsteps: Default + Water tables only → pure `Shared.Footsteps` (material → sound set, step interval by speed) + client player. Keep Roblox's default character sounds.
- **T-026b3** Sprint: hold LeftControl / gamepad ButtonL3; speed from `Config`, server caps WalkSpeed. Crouch is deferred (not in GDD).
- **Dropped:** CustomShiftLock/SmoothShiftLock, DisableDefaultShiftLock, `UpdateRunningState` (no server need), Fart variants, Tutorial, RbxCharacterSounds replacement.
- **T-026c** Animate2-style animation set, after the KeyframeSequences are uploaded under the owner (needs `roblox-open-cloud`).