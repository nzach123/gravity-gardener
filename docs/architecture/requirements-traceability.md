# Architecture Traceability Index

> **Generated from** `docs/architecture/tr-registry.yaml` on 2026-08-16, by
> `/architecture-review`. The registry is the source of truth. **When it
> changes, regenerate this file** — a hand-edit here that the registry does
> not carry is drift, not a correction.

---

## Document Status

| Field | Value |
|---|---|
| **Baseline** | 52 technical requirements |
| **Systems** | `gravity` (13) · `watering` (18) · `oxygen` (12) · `props` (9) |
| **ADRs written** | 12 of 12 — all **Accepted** |
| **Last updated** | 2026-08-16 |
| **Source review** | this `/architecture-review` pass (verdict: PASS) |

> **Read the registry's provenance warning before citing any ID.** 45 of the 52
> requirements are `derived`, not recovered. The ID *allocation* and the *owning
> ADR* are reliable; which numbered slot a given GDD rule occupies is this
> project's assignment. Do not present a derived slot number as history.

---

## Coverage Summary

| Status | Count | % |
|---|---|---|
| ✅ Covered by an **Accepted** ADR | 49 | 94% |
| ❌ Gap — deliberately unowned | 1 | 2% |
| ◻ Parked by design | 1 | 2% |
| ◻ Implemented, no ADR required | 1 | 2% |
| **Total** | **52** | **100%** |

**Coverage by system**

| System | Covered | Gap | Parked / Implemented | Total |
|---|---|---|---|---|
| Gravity | 11 | 0 | 2 | 13 |
| Watering | 17 | 1 | 0 | 18 |
| Oxygen | 12 | 0 | 0 | 12 |
| Props | 9 | 0 | 0 | 9 |
| **Total** | **49** | **1** | **2** | **52** |

> **All 12 planned ADRs are Accepted.** The only requirement not `covered` is
> `TR-watering-002` (carry scales `max_speed` only) — **deliberately unowned**,
> not a gap anyone forgot. Both ADR-0007 and ADR-0009 were drafted and each
> explicitly declines it in writing: closing it needs a new decision that
> reopens ADR-0007's frozen `Player._physics_process` D7.3 signature. Any
> document still quoting 28/52, 22 gaps, or "7 ADRs" is stale — this file was
> that document until this regeneration.

---

## Traceability Matrix

Requirement → owning ADR. All ADRs listed here exist and are Accepted.

### Gravity — 13 (11 covered, 2 parked/implemented, 0 gap)

| TR-ID | Requirement | GDD anchor | ADR | Status |
|---|---|---|---|---|
| TR-gravity-001 | Gravity is a `Vector2` with derived basis; one owner | R1 | ADR-0001 | ✅ |
| TR-gravity-002 | Zones are setters; global broadcast; no per-region gravity | R2, R9 | ADR-0001 | ✅ |
| TR-gravity-003 | Direction eases, strength snaps | R3 | ADR-0001 | ✅ |
| TR-gravity-004 | Asymmetric ascent/descent applied to the player | R4 | ADR-0007 | ✅ |
| TR-gravity-005 | `jump_velocity` derived once, never recomputed | R5 | ADR-0007 | ✅ |
| TR-gravity-006 | Variable jump height; release caps at `min_jump_velocity` | R6 | ADR-0007 | ✅ |
| TR-gravity-007 | Carried mass affects speed only | R10 | ADR-0007 | ✅ |
| TR-gravity-008 | `zone_priority` overlap resolution | R8 | — | ◻ Parked |
| TR-gravity-009 | Multiplier semantics; reject zero direction | R7, AC7 | ADR-0001 | ✅ |
| TR-gravity-010 | Camera rotation follows gravity | §6 | — | ◻ Implemented — see GDD Revision Flags |
| TR-gravity-011 | `direction_ease_rate` exported, not hardcoded | §7 | ADR-0001 | ✅ |
| TR-gravity-012 | Props adopt the vector on the player's frame | AC12 | ADR-0001 | ✅ — verification still open, see Known Open Items |
| TR-gravity-013 | Visual mirrors movement axis inversion at any angle | §6, AC8, AC10 | ADR-0007 | ✅ |

### Watering — 18 (17 covered, 1 gap)

| TR-ID | Requirement | GDD anchor | ADR | Status |
|---|---|---|---|---|
| TR-watering-001 | Buckets single-use; contact pickup; one at a time | R1 | ADR-0009 | ✅ |
| TR-watering-002 | Carry scales `max_speed` only | R2 | — | ❌ **Gap — deliberately unowned** |
| TR-watering-003 | Pour is time-based, held-input, locks the player | R3 | ADR-0009 | ✅ (gesture-agnostic toggle alternative not addressed — see Known Open Items) |
| TR-watering-004 | Early release zeroes progress, retains the bucket | R4 | ADR-0009 | ✅ |
| TR-watering-005 | Plants cap intake at `buckets_required` | R5 | ADR-0009 | ✅ |
| TR-watering-006 | Airlock gates on the level-wide counter | R6 | ADR-0002 | ✅ |
| TR-watering-007 | Spent jug is flung and freed | R7 | ADR-0012 | ✅ |
| TR-watering-008 | `buckets_total == Σ buckets_required`, validated at load | R8 | ADR-0003 | ✅ |
| TR-watering-009 | Nearest plant with capacity receives the pour | §5, AC12 | ADR-0009 | ✅ |
| TR-watering-010 | Pour survives a flip; area exit equals early release | §5 | ADR-0009 | ✅ |
| TR-watering-011 | Restart clears carry and watering state | §5, AC8 | ADR-0002 | ✅ |
| TR-watering-012 | Final pour on the depletion frame yields death | AC13 | ADR-0005 | ✅ |
| TR-watering-013 | `carry_speed_multiplier`, `throw_*` in `WateringTuning` | §7 | ADR-0006 | ✅ |
| TR-watering-014 | Carrying leaves jump apex unchanged | AC1 | ADR-0007 | ✅ |
| TR-watering-015 | Load logs an error on bucket-sum mismatch | AC7 | ADR-0003 | ✅ |
| TR-watering-016 | `Bucket` must be an `Area2D` | §6 | ADR-0009 | ✅ |
| TR-watering-017 | HUD reads `carrying_bucket`; carry state is diegetic | §6 | ADR-0010 | ✅ |
| TR-watering-018 | Capped plant shows a positive refusal marker | §5 | ADR-0010 | ✅ |

### Suit Oxygen — 12 (all covered)

| TR-ID | Requirement | GDD anchor | ADR | Status |
|---|---|---|---|---|
| TR-oxygen-001 | Per-level countdown from `oxygen_capacity` | R1 | ADR-0008 | ✅ |
| TR-oxygen-002 | Drain is unconditional in every player state | R2, AC1 | ADR-0008 | ✅ |
| TR-oxygen-003 | Zero is death via the shared restart path | R3, AC2 | ADR-0008 | ✅ — see GDD Revision Flags |
| TR-oxygen-004 | Nothing refills the suit | R4, AC3 | ADR-0008 | ✅ |
| TR-oxygen-005 | Restart refills; never carries between levels | R5, AC4, AC5 | ADR-0002 | ✅ |
| TR-oxygen-006 | Pause halts drain | §5 | ADR-0008 | ✅ (via `SceneTree.paused` + `PROCESS_MODE_INHERIT`) |
| TR-oxygen-007 | Readout is always visible | R7, AC9 | ADR-0010 | ✅ |
| TR-oxygen-008 | Load logs an error when `oxygen_capacity <= 0` | AC7 | ADR-0003 | ✅ |
| TR-oxygen-009 | Threshold feedback at 50 / 25 / 10 % | R7, AC10 | ADR-0010 | ✅ — GDD internal tension noted, see Known Open Items |
| TR-oxygen-010 | Airlock entry on the depletion frame completes | AC8 | ADR-0005 | ✅ |
| TR-oxygen-011 | `margin`, `drain_rate`, `threshold_*` in `OxygenTuning` | §7 | ADR-0006 | ✅ |
| TR-oxygen-012 | Capacity derived from `O_level` on the level root | R6 | ADR-0002 | ✅ |

### Physics Props — 9 (all covered)

| TR-ID | Requirement | GDD anchor | ADR | Status |
|---|---|---|---|---|
| TR-props-001 | Props obey the global vector, including during easing | R3, R4 | ADR-0001 | ✅ |
| TR-props-002 | Cosmetic isolation by layer and mask | R1, R2, AC1, AC2 | ADR-0004 | ✅ |
| TR-props-003 | Props reset to authored transforms on restart | R6, AC8 | ADR-0011 | ✅ |
| TR-props-004 | Sleeping props force-woken on every change | R5, AC3 | ADR-0001 | ✅ |
| TR-props-005 | Props leaving level bounds are freed | R7, AC9 | ADR-0011 | ✅ |
| TR-props-006 | Fall-speed cap; per-prop mass and damping | §4, §7, AC7 | ADR-0011 | ✅ |
| TR-props-007 | Prop count budgeted and flagged at load | R8, §5 | ADR-0003 | ✅ |
| TR-props-008 | A room at budget holds 60 FPS during a flip | AC10 | ADR-0011 | ✅ (evidence-type unresolved: GDD types this Performance, coding standards define no Performance gate row — flagged, not fixed, by ADR-0011) |
| TR-props-009 | `PropTuning` knobs and defaults | §7 | ADR-0006 | ✅ |

---

## Known Open Items (carried forward — none are new findings this pass)

Everything below was already surfaced by an earlier ADR, review, or the
registry's own `open_items` section. Listed here so a reader of this index
doesn't have to cross-reference `tr-registry.yaml` to find them.

| # | Item | Owner | Status |
|---|---|---|---|
| 1 | **Camera's first-broadcast gap** — if the camera's `gravity_changed` subscription wires after `GravityAuthority.reset_to()`'s first broadcast (ADR-0003 D3.1 step order), the camera renders unrotated on level load until the next zone change. Named by ADR-0011, explicitly declined by ADR-0010 ("no planned ADR remains to absorb it"). | **Unassigned** | Open — needs a new ADR if pursued |
| 2 | **Settings screen** — ADR-0008 names ADR-0010 as owner of the future settings screen calling `OxygenAccessibility.set_drain_rate_multiplier()`. ADR-0010 explicitly does not deliver it; no settings-screen UX spec exists yet. | **Unassigned** | Open — prerequisite: a settings-screen UX spec |
| 3 | **Camera three-way decouple** (`TR-gravity-010`) — `camera_moving` still gates rotation and follow together, blocking the reduced-motion accessibility commitment. The third leg, the input basis, is closed: ADR-0013 D13.4 deletes `camera_rotation_enabled` and D13.2 reads the camera's live rotation instead. D13.5 specifies the follow/rotate split and declines to apply it, per the ADR-0011 D11.6 precedent. | ADR-0013 (split specified, not applied) | Open — input-basis leg closed; follow/rotate split awaiting a human playtest of `level_01`/`level_07` |
| 4 | **`TR-gravity-012` verification** — ADR-0001's Verification Required #2 (a default-space gravity write in `_physics_process` reaches every `RigidBody2D` in the same step) is confirmed by engine source reasoning but not yet executed against running code, because no code exists yet. | ADR-0001 | Open — confirm at implementation (Migration Plan) |
| 5 | **`TR-watering-002`** — carry-speed penalty, deliberately unowned. See Coverage Summary above. | **Unassigned** | Open by decision |
| 6 | **`TR-watering-003`'s gesture-agnostic sub-requirement** — `accessibility-requirements.md` Motor tier commits to a toggle alternative to the interact hold; ADR-0009's call site reads the hold action directly with no abstraction a toggle handler could hook. | **Unassigned** | Open — flagged explicitly in ADR-0009, not fixed |
| 7 | **BUG-0001** — the out-of-bounds kill plane in `level_05`/`level_06` is dead (mask defaults leave `1 & 2 == 0`). ADR-0011 D11.6 names the correct fix (`collision_mask = 2`) and declines to apply it — applying it changes live player-death behaviour in two shipped levels and needs a playtest first. | Fix specified, not applied | Open |

---

## Cross-ADR Conflicts

All conflicts raised by earlier reviews (C1–C8, and the two "new findings"
F1/F2 from the session-18 traceability snapshot) are now closed by a later
ADR's text or a registry correction, **except** open item #1 above (the old
F2), which stays open and unowned.

| # | Conflict | Status |
|---|---|---|
| C1–C6 | (see `tr-registry.yaml` / individual ADR "Related Decisions" sections for detail) | ✅ Closed |
| C3 (old) | ADR-0005 D5.5 migrates `plant.gd`'s pour-driving; the approved `watering-system.md` §6 Code table assigns it to `PlayerWateringComponent` instead | ✅ Closed — ADR-0009 §1 resolves in the GDD's favor; ADR-0005's registry entry gained the `frame_ordering_contract.plant_removed` narrowing note |
| C8 (old) | `Plant` held a `process_physics_priority = 0` row with no per-frame work left to justify it | ✅ Closed — same ADR-0009 narrowing note; also registered as forbidden pattern `plant_gains_process_physics_priority` |
| F1 (old) | ADR-0001 part 4a's easing-gated space write never fires on level load/restart, since `reset_to()` sets `gravity == target_gravity` immediately | ✅ Closed — ADR-0011 D11.5 adds a synchronous `reset_to()` space write; ADR-0001's V6 extended to assert the space parameter, not only the `gravity` field |
| F2 (old) | ADR-0003 D3.1's wiring-after-broadcast step order vs. the camera's `gravity_changed` subscription | ❌ **Still open** — see Known Open Items #1 |

No new cross-ADR conflicts surfaced this pass.

---

## GDD Revision Flags

| GDD | Assumption | Reality | Action |
|---|---|---|---|
| `suit-oxygen.md` R3/§5 | Oxygen death is **"immediate"** | ADR-0005 D5.2 / ADR-0008 §1 deliberately defer the kill one physics frame (armed-death mechanism) — load-bearing, reconciles AC8 with `watering-system.md` AC13 | Revise GDD wording — flagged since 2026-08-15, still unresolved |
| `suit-oxygen.md` §2 vs §4 | §2 wants "roughly thirty seconds out" awareness | §4's caution threshold fires at 24 s for a 48 s level — *after* the 30-second mark | Internal GDD tension, not architecture-caused. `hud.md` resolves the practical intent (permanent bar, not threshold-triggered) but the GDD numbers themselves remain in tension |

---

## ADR → Requirement Coverage (Reverse Index)

| ADR | Status | Requirements owned | Count |
|---|---|---|---|
| ADR-0001 | **Accepted** | `TR-gravity-001/002/003/009/011/012`, `TR-props-001/004` | 8 |
| ADR-0002 | **Accepted** | `TR-watering-006/011`, `TR-oxygen-005/012` | 4 |
| ADR-0003 | **Accepted** | `TR-watering-008/015`, `TR-oxygen-008`, `TR-props-007` | 4 |
| ADR-0004 | **Accepted** | `TR-props-002` | 1 |
| ADR-0005 | **Accepted** | `TR-watering-012`, `TR-oxygen-010` | 2 |
| ADR-0006 | **Accepted** | `TR-watering-013`, `TR-oxygen-011`, `TR-props-009` | 3 |
| ADR-0007 | **Accepted** | `TR-gravity-004/005/006/007/013`, `TR-watering-014` | 6 |
| ADR-0008 | **Accepted** | `TR-oxygen-001/002/003/004/006` | 5 |
| ADR-0009 | **Accepted** | `TR-watering-001/003/004/005/009/010/016` | 7 |
| ADR-0010 | **Accepted** | `TR-watering-017/018`, `TR-oxygen-007/009` | 4 |
| ADR-0011 | **Accepted** | `TR-props-003/005/006/008` | 4 |
| ADR-0012 | **Accepted** | `TR-watering-007` | 1 |
| — | Unowned / parked / implemented | `TR-watering-002`, `TR-gravity-008`, `TR-gravity-010` | 3 |
| | | **Total** | **52** |

---

## Superseded and Corrected Requirements

**No requirement has been superseded.** Three were **corrected in place**
before this file gained the wording it inherits (see `tr-registry.yaml` for
the full corrected-text history):

| TR-ID | Was | Now | Why |
|---|---|---|---|
| `TR-watering-002` | Owned by ADR-0007, then by ADR-0009 | `adr: null`, `adr_status: unowned` | Both ADRs explicitly decline it in their own GDD Requirements Addressed tables |
| `TR-watering-017` | "HUD carry indicator (§6)" | HUD reads `carrying_bucket` as a prompt precondition; carry state is diegetic | `/propagate-design-change` closed Q9; `systems-index.md` matches |
| `TR-watering-018` | "Interact prompt suppressed on a fully grown plant (§5)" | Capped plant shows a **positive** refusal marker | `hud.md` E4 requires refusal be legible, not silent |

---

## How to Use This Document

**Writing an ADR**: find the requirements assigned to it in the reverse index.
Every one must be addressed or explicitly deferred with a named owner.

**Writing a story**: cite the TR-ID from `tr-registry.yaml`, not from this file.
Check the entry's `provenance` — if it is `derived`, the slot number is this
project's assignment rather than recovered fact.

**Adding a requirement**: add it to `tr-registry.yaml` first, then regenerate
this index. Never add an ID here alone.

**Finding an unowned requirement**: `TR-watering-002` is the only one, and it
is unowned by decision, not by oversight. If you find a genuinely new unowned
requirement, the registry's `open_items` section is where it goes.
