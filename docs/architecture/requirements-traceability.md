# Architecture Traceability Index

> **Generated from** `docs/architecture/tr-registry.yaml` on 2026-08-15.
> The registry is the source of truth. **When it changes, regenerate this file** —
> a hand-edit here that the registry does not carry is drift, not a correction.

---

## Document Status

| Field | Value |
|---|---|
| **Baseline** | 52 technical requirements |
| **Systems** | `gravity` (13) · `watering` (18) · `oxygen` (12) · `props` (9) |
| **ADRs written** | 6 of 12 — all **Accepted** 2026-08-15 |
| **Last updated** | 2026-08-15 |
| **Source review** | `docs/architecture/architecture-review-2026-08-15.md` |

> **Read the registry's provenance warning before citing any ID.** 45 of the 52
> requirements are `derived`, not recovered. The ID *allocation* and the *owning
> ADR* are reliable; which numbered slot a given GDD rule occupies is this
> project's assignment. Do not present a derived slot number as history.

---

## Coverage Summary

| Status | Count | % |
|---|---|---|
| ✅ Covered by an **Accepted** ADR | 22 | 42% |
| ❌ Gap — assigned to an unwritten ADR | 28 | 54% |
| ◻ Parked by design | 1 | 2% |
| ◻ Implemented, no ADR required | 1 | 2% |
| **Total** | **52** | **100%** |

**Coverage by system**

| System | Covered | Gap | Parked / Implemented | Total |
|---|---|---|---|---|
| Gravity | 6 | 5 | 2 | 13 |
| Watering | 6 | 12 | 0 | 18 |
| Oxygen | 5 | 7 | 0 | 12 |
| Props | 5 | 4 | 0 | 9 |
| **Total** | **22** | **28** | **2** | **52** |

> **The 22 figure is new.** The source review recorded coverage-by-accepted as
> **0 of 52**, correctly — every ADR was `Proposed` when it ran. Session 12
> accepted all six on 2026-08-15. Any document still quoting 0 of 52 is stale,
> including `architecture.md`'s Traceability coverage section.

---

## Traceability Matrix

Requirement → owning ADR. Italicised ADRs do not exist yet.

### Gravity — 13

| TR-ID | Requirement | GDD anchor | ADR | Status |
|---|---|---|---|---|
| TR-gravity-001 | Gravity is a `Vector2` with derived basis; one owner | R1 | ADR-0001 | ✅ |
| TR-gravity-002 | Zones are setters; global broadcast; no per-region gravity | R2, R9 | ADR-0001 | ✅ |
| TR-gravity-003 | Direction eases, strength snaps | R3 | ADR-0001 | ✅ |
| TR-gravity-004 | Asymmetric ascent/descent applied to the player | R4 | *ADR-0007* | ❌ |
| TR-gravity-005 | `jump_velocity` derived once, never recomputed | R5 | *ADR-0007* | ❌ |
| TR-gravity-006 | Variable jump height; release caps at `min_jump_velocity` | R6 | *ADR-0007* | ❌ |
| TR-gravity-007 | Carried mass affects speed only | R10 | *ADR-0007* | ❌ |
| TR-gravity-008 | `zone_priority` overlap resolution | R8 | — | ◻ Parked |
| TR-gravity-009 | Multiplier semantics; reject zero direction | R7, AC7 | ADR-0001 | ✅ |
| TR-gravity-010 | Camera rotation follows gravity | §6 | — | ◻ Implemented |
| TR-gravity-011 | `direction_ease_rate` exported, not hardcoded | §7 | ADR-0001 | ✅ |
| TR-gravity-012 | Props adopt the vector on the player's frame | AC12 | ADR-0001 | ✅ |
| TR-gravity-013 | Visual mirrors movement axis inversion at any angle | §6, AC8, AC10 | *ADR-0007* | ❌ |

### Watering — 18

| TR-ID | Requirement | GDD anchor | ADR | Status |
|---|---|---|---|---|
| TR-watering-001 | Buckets single-use; contact pickup; one at a time | R1 | *ADR-0009* | ❌ |
| TR-watering-002 | Carry scales `max_speed` only | R2 | *ADR-0007* | ❌ |
| TR-watering-003 | Pour is time-based, held-input, locks the player | R3 | *ADR-0009* | ❌ |
| TR-watering-004 | Early release zeroes progress, retains the bucket | R4 | *ADR-0009* | ❌ |
| TR-watering-005 | Plants cap intake at `buckets_required` | R5 | *ADR-0009* | ❌ |
| TR-watering-006 | Airlock gates on the level-wide counter | R6 | ADR-0002 | ✅ |
| TR-watering-007 | Spent jug is flung and freed | R7 | *ADR-0012* | ❌ |
| TR-watering-008 | `buckets_total == Σ buckets_required`, validated at load | R8 | ADR-0003 | ✅ |
| TR-watering-009 | Nearest plant with capacity receives the pour | §5, AC12 | *ADR-0009* | ❌ |
| TR-watering-010 | Pour survives a flip; area exit equals early release | §5 | *ADR-0009* | ❌ |
| TR-watering-011 | Restart clears carry and watering state | §5, AC8 | ADR-0002 | ✅ |
| TR-watering-012 | Final pour on the depletion frame yields death | AC13 | ADR-0005 | ✅ |
| TR-watering-013 | `carry_speed_multiplier`, `throw_*` in `WateringTuning` | §7 | ADR-0006 | ✅ |
| TR-watering-014 | Carrying leaves jump apex unchanged | AC1 | *ADR-0007* | ❌ |
| TR-watering-015 | Load logs an error on bucket-sum mismatch | AC7 | ADR-0003 | ✅ |
| TR-watering-016 | `Bucket` must be an `Area2D` | §6 | *ADR-0009* | ❌ |
| TR-watering-017 | HUD reads `carrying_bucket`; carry state is diegetic | §6 | *ADR-0010* | ❌ **corrected** |
| TR-watering-018 | Capped plant shows a positive refusal marker | §5 | *ADR-0010* | ❌ **corrected** |

### Suit Oxygen — 12

| TR-ID | Requirement | GDD anchor | ADR | Status |
|---|---|---|---|---|
| TR-oxygen-001 | Per-level countdown from `oxygen_capacity` | R1 | *ADR-0008* | ❌ |
| TR-oxygen-002 | Drain is unconditional in every player state | R2, AC1 | *ADR-0008* | ❌ |
| TR-oxygen-003 | Zero is death via the shared restart path | R3, AC2 | *ADR-0008* | ❌ |
| TR-oxygen-004 | Nothing refills the suit | R4, AC3 | *ADR-0008* | ❌ |
| TR-oxygen-005 | Restart refills; never carries between levels | R5, AC4, AC5 | ADR-0002 | ✅ |
| TR-oxygen-006 | Pause halts drain | §5 | **— none —** | ❌ **UNOWNED** |
| TR-oxygen-007 | Readout is always visible | R7, AC9 | *ADR-0010* | ❌ |
| TR-oxygen-008 | Load logs an error when `oxygen_capacity <= 0` | AC7 | ADR-0003 | ✅ |
| TR-oxygen-009 | Threshold feedback at 50 / 25 / 10 % | R7, AC10 | *ADR-0010* | ❌ |
| TR-oxygen-010 | Airlock entry on the depletion frame completes | AC8 | ADR-0005 | ✅ |
| TR-oxygen-011 | `margin`, `drain_rate`, `threshold_*` in `OxygenTuning` | §7 | ADR-0006 | ✅ |
| TR-oxygen-012 | Capacity derived from `O_level` on the level root | R6 | ADR-0002 | ✅ |

### Physics Props — 9

| TR-ID | Requirement | GDD anchor | ADR | Status |
|---|---|---|---|---|
| TR-props-001 | Props obey the global vector, including during easing | R3, R4 | ADR-0001 | ✅ |
| TR-props-002 | Cosmetic isolation by layer and mask | R1, R2, AC1, AC2 | ADR-0004 | ✅ |
| TR-props-003 | Props reset to authored transforms on restart | R6, AC8 | *ADR-0011* | ❌ |
| TR-props-004 | Sleeping props force-woken on every change | R5, AC3 | ADR-0001 | ✅ |
| TR-props-005 | Props leaving level bounds are freed | R7, AC9 | *ADR-0011* | ❌ |
| TR-props-006 | Fall-speed cap; per-prop mass and damping | §4, §7, AC7 | *ADR-0011* | ❌ |
| TR-props-007 | Prop count budgeted and flagged at load | R8, §5 | ADR-0003 | ✅ |
| TR-props-008 | A room at budget holds 60 FPS during a flip | AC10 | *ADR-0011* | ❌ |
| TR-props-009 | `PropTuning` knobs and defaults | §7 | ADR-0006 | ✅ |

---

## Known Gaps

### Foundation Layer — **NONE**

**All six Foundation ADRs are written and Accepted.** No Foundation requirement
is uncovered. This layer is closed.

### Core Layer Gaps — 12 (must resolve before the relevant system is built)

| ADR | Requirements | Count |
|---|---|---|
| *ADR-0007* — Player component contract | `TR-gravity-004/005/006/007/013`, `TR-watering-002/014` | 7 |
| *ADR-0008* — Oxygen drain and death path | `TR-oxygen-001/002/003/004` | 4 |
| **unowned** | `TR-oxygen-006` | 1 |

> **ADR-0007 is the front of the queue.** It owns the most gaps of any single
> ADR, `watering-system.md` names it as the one to write first, and it is blocked
> by nothing. `TR-watering-014` is a cross-document invariant — one test serving
> both `watering-system.md` AC1 and `gravity.md` AC11.

> 🔴 **`TR-oxygen-006` has no owner and this blocks ADR-0008.**
> `architecture.md` QQ-04 routes it to ADR-0010, whose scope is HUD and Control
> offset usage. The node that must consult pause state is `OxygenDrain`, which
> ADR-0008 owns. **Neither ADR claims it.** Assign an owner before either is
> written. `hud.md` U10.3 already specifies a frozen-HUD state that depends on it,
> and `design/accessibility-requirements.md` commits to pause-anywhere at Basic
> tier — so three documents now depend on a requirement nobody owns.

### Feature Layer Gaps — 7

| ADR | Requirements | Count |
|---|---|---|
| *ADR-0009* — Watering interaction model | `TR-watering-001/003/004/005/009/010/016` | 7 |

> ADR-0009 inherits three standing obligations: **C3** (ADR-0005 D5.5's clock
> discipline restated against `PlayerWateringComponent`), **C8** (`Plant`'s
> missing priority row, self-resolving if C3 moves pour driving off `Plant`), and
> **gesture-agnostic pour abandonment**, newly added by
> `design/accessibility-requirements.md`.

### Presentation Layer Gaps — 9

| ADR | Requirements | Count |
|---|---|---|
| *ADR-0010* — HUD architecture | `TR-watering-017/018`, `TR-oxygen-007/009` | 4 |
| *ADR-0011* — Physics props implementation | `TR-props-003/005/006/008` | 4 |
| *ADR-0012* — Spent jug throw and lifetime | `TR-watering-007` | 1 |

> **ADR-0010 carries the heaviest inherited load of any unwritten ADR**: the two
> corrected requirements above, `hud.md` Q17 (Z2 occlusion under non-default
> gravity), the on-demand tally committed by
> `design/accessibility-requirements.md`, and the obligation that `hud` moves to
> **Required** in ADR-0003's consumer table on acceptance — after which every
> level must wire one.

---

## Cross-ADR Conflicts

Eight were raised by the 2026-08-15 review. **Five are closed.**

| # | Conflict | Status |
|---|---|---|
| 🔴 C1 | `V-WIRING`'s required-consumer set was undefined | ✅ Closed — session 12, D12.2 |
| 🟠 C2 | ADR-0002 migration prose vs ADR-0003 D3.5 | ✅ Closed — session 12 |
| 🟠 C3 | ADR-0005 D5.5 migrates `plant.gd`; ADR-0009 empties it | ❌ **Open** — inherited by ADR-0009 |
| 🟠 C4 | Registry `frame_ordering_contract` misstated its ADR | ✅ Closed — session 12, corrected in place |
| 🟠 C5 | Registry omitted `_transition_pending` from the guard | ✅ Closed — session 12, corrected in place |
| 🟡 C6 | ADR-0001's unqualified `prop_tuning` reach | ✅ Closed — session 12 |
| 🟡 C7 | Registry carries two discharged verification items | ❌ **Open** — harmless, same file |
| 🟡 C8 | `Plant` in the ordering table with no assigned priority | ❌ **Open** — inherited by ADR-0009 |

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
| *ADR-0007* | Not written | `TR-gravity-004/005/006/007/013`, `TR-watering-002/014` | 7 |
| *ADR-0008* | Not written | `TR-oxygen-001/002/003/004` | 4 |
| *ADR-0009* | Not written | `TR-watering-001/003/004/005/009/010/016` | 7 |
| *ADR-0010* | Not written | `TR-watering-017/018`, `TR-oxygen-007/009` | 4 |
| *ADR-0011* | Not written | `TR-props-003/005/006/008` | 4 |
| *ADR-0012* | Not written | `TR-watering-007` | 1 |
| — | Parked / implemented | `TR-gravity-008`, `TR-gravity-010` | 2 |
| **unowned** | — | `TR-oxygen-006` | 1 |
| | | **Total** | **52** |

---

## Superseded and Corrected Requirements

**No requirement has been superseded.** Two were **corrected on creation**,
before this baseline gained binding force:

| TR-ID | Was | Now | Why |
|---|---|---|---|
| `TR-watering-017` | "HUD carry indicator (§6)" | HUD reads `carrying_bucket` as a prompt precondition; carry state is diegetic | `/propagate-design-change` closed Q9 on 2026-08-15. §6's HUD row states there is no carry indicator, and `systems-index.md:102` matches |
| `TR-watering-018` | "Interact prompt suppressed on a fully grown plant (§5)" | Capped plant shows a **positive** refusal marker | `hud.md` E4 makes refusal explicitly "not the absence of E2". §5 requires refusal be "legible rather than silent", which the old text contradicted |

> Correction is not supersession. Supersession records that a stance *changed*;
> these entries never matched their source. This follows the convention settled
> 2026-08-15 in `docs/registry/architecture.yaml`.

---

## Documents Contradicted by This Index

Recorded rather than fixed. **Route each through `/propagate-design-change`, not
by hand.**

| Document | Claim | Reality |
|---|---|---|
| `architecture.md:10` | "ADRs Referenced: none exist — 12 required" | 6 written, all Accepted |
| `architecture.md` § ADR Audit | "**No ADRs exist**, so there is nothing to audit" | 6 exist and are audited |
| `architecture.md` § Traceability coverage | "**0 of 52 requirements covered. 52 gaps.**" | 22 covered, 28 gaps, 2 parked |
| `architecture.md:108` | HUD "carry indicator" row | Removed by Q9. Matches `TR-watering-017`'s correction |
| `architecture-review-2026-08-15.md:125–126` | `TR-watering-017/018` original text | Corrected here |

---

## How to Use This Document

**Writing an ADR**: find the requirements assigned to it in the reverse index.
Every one must be addressed or explicitly deferred with a named owner.

**Writing a story**: cite the TR-ID from `tr-registry.yaml`, not from this file.
Check the entry's `provenance` — if it is `derived`, the slot number is this
project's assignment rather than recovered fact.

**Adding a requirement**: add it to `tr-registry.yaml` first, then regenerate
this index. Never add an ID here alone.

**Finding an unowned requirement**: `TR-oxygen-006` is the only one. If you find
another, the registry's `open_items` section is where it goes.
