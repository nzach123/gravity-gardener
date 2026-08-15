# Architecture Review — Full Pass, All ADRs

> **Date**: 2026-08-15
> **Mode**: `/architecture-review all adr` — full review, Phases 1–9
> **Engine**: Godot 4.7 (pinned 2026-08-13; project runs 4.7.1-stable)
> **GDDs reviewed**: 4 (`gravity.md`, `watering-system.md`, `suit-oxygen.md`, `physics-props.md`) + `systems-index.md`
> **ADRs reviewed**: 6 (ADR-0001 … ADR-0006) — **all `Proposed`, none `Accepted`**
> **Also loaded**: `architecture.md`, `docs/registry/architecture.yaml`, 5 engine reference files, `architecture-review-2026-08-14.md`
> **Verdict**: **CONCERNS**

This is the first full `/architecture-review` this project has had. The
2026-08-14 review was an engine specialist consultation only and explicitly
deferred Phases 2–3 (traceability), 4 (cross-ADR conflicts), 5b (GDD revision
flags) and 6 (architecture-doc coverage). Those four phases are what this
document adds, over a set of ADRs that has since doubled from three to six.

`docs/consistency-failures.md` does not exist, so no reflexion log was read and
none was appended.

---

## The TR baseline was reconstructed, not read

`architecture.md:9` and `systems-index.md:58` both describe a 52-requirement
baseline as extracted and mapped. **`docs/architecture/tr-registry.yaml` does not
exist, and no file in the repository defines a single TR ID.** Every occurrence
across `architecture.md` and all six ADRs is a citation of a table that was never
written. This was recorded as a documentation gap during ADR-0006 authoring and
is confirmed here.

The baseline was rebuilt rather than replaced. The surviving citations allocate
IDs with no gaps and no overlaps in any range:

| System | Cited range | Count |
|---|---|---|
| `TR-gravity-*` | 001–013 | 13 |
| `TR-watering-*` | 001–018 | 18 |
| `TR-oxygen-*` | 001–012 | 12 |
| `TR-props-*` | 001–009 | 9 |
| | **Total** | **52** |

That is the documented figure exactly, so the original ID *allocation* is
recoverable even though the requirement *text* is not. GDD requirements were
fitted to those slots under the constraint that each ADR's cited IDs must land on
requirements that ADR actually addresses.

**Seven IDs are confirmed verbatim by surviving prose** and are not inferences:

| TR-ID | Confirmed by |
|---|---|
| `TR-gravity-008` | `architecture.md:707` — "`zone_priority`. `gravity.md` R8 parks it explicitly" |
| `TR-gravity-010` | `architecture.md:708` — "camera rotation, working in `main.gd`" |
| `TR-gravity-011` | `architecture.md:468` — "the hardcoded `32.0` ease rate" |
| `TR-watering-012` | ADR-0005 GDD table — "**AC13** (`TR-watering-012`)" |
| `TR-watering-016` | `architecture.md:632` — "`class_name Bucket extends Area2D  # was `extends Node` — TR-watering-016`" |
| `TR-oxygen-010` | ADR-0005 GDD table — "**AC8** (`TR-oxygen-010`)" |
| `TR-props-002` | ADR-0004 — "this ADR covers `TR-props-002`" |

**The remaining 45 are inferred.** They are correct at the level of *which ADR
owns them* — that constraint is hard — and plausible but unverifiable at the
level of *which GDD rule sits in which numbered slot*. Any future document
anchoring to a specific inferred ID should treat it as this review's assignment,
not as recovered fact.

---

## Traceability Summary

| Status | Count | % |
|---|---|---|
| ✅ Covered by a written ADR | 22 | 42% |
| ❌ Gap — assigned to an unwritten ADR | 28 | 54% |
| ◻ Parked by design / already implemented | 2 | 4% |
| **Total** | **52** | **100%** |

**Coverage by an *accepted* decision remains 0 of 52.** All six ADRs are
`Proposed`. `architecture.md`'s sign-off condition 1 — "All 6 Foundation ADRs
accepted before implementation begins. This is a hard gate" — is unmet, and the
figure is unchanged since 2026-08-13.

---

## Traceability Matrix

Italicised ADRs do not exist yet.

### Gravity — 13 requirements

| TR-ID | Requirement (GDD anchor) | ADR | Status |
|---|---|---|---|
| TR-gravity-001 | Gravity is a `Vector2` with derived `up_dir`/`right_dir` basis; one owner (R1) | ADR-0001 | ✅ |
| TR-gravity-002 | Zones are setters; global broadcast; no per-body or per-region gravity (R2, R9) | ADR-0001 | ✅ |
| TR-gravity-003 | Direction eases, strength snaps (R3) | ADR-0001 | ✅ |
| TR-gravity-004 | Asymmetric ascent/descent applied to the player (R4) | *ADR-0007* | ❌ |
| TR-gravity-005 | `jump_velocity` derived once, never recomputed (R5) | *ADR-0007* | ❌ |
| TR-gravity-006 | Variable jump height; release caps at `min_jump_velocity` (R6) | *ADR-0007* | ❌ |
| TR-gravity-007 | Carried mass affects speed only, never gravity or jump (R10) | *ADR-0007* | ❌ |
| TR-gravity-008 | `zone_priority` overlap resolution (R8) | — | ◻ Parked by GDD design |
| TR-gravity-009 | Multiplier semantics; reject zero direction / non-positive multiplier (R7, AC7) | ADR-0001 | ✅ |
| TR-gravity-010 | Camera rotation follows gravity | — | ◻ Implemented and stable |
| TR-gravity-011 | `direction_ease_rate` exported, not hardcoded `32.0` (§7) | ADR-0001 | ✅ |
| TR-gravity-012 | Props adopt the vector on the same frame as the player (AC12) | ADR-0001 | ✅ |
| TR-gravity-013 | Visual component mirrors movement axis inversion at any angle (§6, AC8, AC10) | *ADR-0007* | ❌ |

### Watering — 18 requirements

| TR-ID | Requirement | ADR | Status |
|---|---|---|---|
| TR-watering-001 | Buckets are single-use; pickup on contact; one carried at a time (R1) | *ADR-0009* | ❌ |
| TR-watering-002 | Carry scales `max_speed` only (R2) | *ADR-0007* | ❌ |
| TR-watering-003 | Pour is time-based, held-input, and locks the player (R3) | *ADR-0009* | ❌ |
| TR-watering-004 | Early release zeroes progress and retains the bucket (R4) | *ADR-0009* | ❌ |
| TR-watering-005 | Plants cap intake at `buckets_required` (R5) | *ADR-0009* | ❌ |
| TR-watering-006 | Airlock gates on the level-wide consumed counter, not on a plant (R6) | ADR-0002 | ✅ |
| TR-watering-007 | Spent jug is flung and freed (R7) | *ADR-0012* | ❌ |
| TR-watering-008 | `buckets_total == Σ buckets_required`, validated at load (R8) | ADR-0003 | ✅ |
| TR-watering-009 | Nearest plant with remaining capacity receives the pour (§5, AC12) | *ADR-0009* | ❌ |
| TR-watering-010 | Pour survives a gravity flip; area exit equals early release (§5) | *ADR-0009* | ❌ |
| TR-watering-011 | Restart clears carry state and all watering state (§5 defect, AC8) | ADR-0002 | ✅ |
| TR-watering-012 | Final pour on the depletion frame yields death, not completion (AC13) | ADR-0005 | ✅ |
| TR-watering-013 | `carry_speed_multiplier` and `throw_*` live in `WateringTuning` (§7) | ADR-0006 | ✅ |
| TR-watering-014 | Carrying leaves jump apex unchanged at every zone multiplier (AC1) | *ADR-0007* | ❌ |
| TR-watering-015 | Load logs an error on bucket-sum mismatch (AC7 — **Logic, BLOCKING**) | ADR-0003 | ✅ |
| TR-watering-016 | `Bucket` must be an `Area2D`, not a `Node` (§6) | *ADR-0009* | ❌ |
| TR-watering-017 | HUD carry indicator (§6) | *ADR-0010* | ❌ |
| TR-watering-018 | Interact prompt suppressed on a fully grown plant (§5) | *ADR-0010* | ❌ |

### Suit Oxygen — 12 requirements

| TR-ID | Requirement | ADR | Status |
|---|---|---|---|
| TR-oxygen-001 | Per-level countdown from `oxygen_capacity` (R1) | *ADR-0008* | ❌ |
| TR-oxygen-002 | Drain is unconditional in every player state (R2, AC1) | *ADR-0008* | ❌ |
| TR-oxygen-003 | Zero is death via the shared restart path, indistinguishable (R3, AC2) | *ADR-0008* | ❌ |
| TR-oxygen-004 | Nothing refills the suit (R4, AC3) | *ADR-0008* | ❌ |
| TR-oxygen-005 | Restart refills; oxygen never carries between levels (R5, AC4, AC5) | ADR-0002 | ✅ |
| TR-oxygen-006 | Pause halts drain (§5) | *ADR-0008 / ADR-0010* | ❌ **unowned** |
| TR-oxygen-007 | Readout is always visible (R7, AC9) | *ADR-0010* | ❌ |
| TR-oxygen-008 | Load logs an error when `oxygen_capacity <= 0` (AC7 — **Logic, BLOCKING**) | ADR-0003 | ✅ |
| TR-oxygen-009 | Threshold feedback fires at 50 / 25 / 10 % (R7, AC10) | *ADR-0010* | ❌ |
| TR-oxygen-010 | Airlock entry on the depletion frame completes the level (AC8) | ADR-0005 | ✅ |
| TR-oxygen-011 | `margin`, `drain_rate`, `threshold_*` live in `OxygenTuning` (§7) | ADR-0006 | ✅ |
| TR-oxygen-012 | Capacity derived from `O_level`, authored on the level root (R6) | ADR-0002 | ✅ |

### Physics Props — 9 requirements

| TR-ID | Requirement | ADR | Status |
|---|---|---|---|
| TR-props-001 | Props obey the global vector including during easing; symmetric (R3, R4) | ADR-0001 | ✅ |
| TR-props-002 | Cosmetic isolation enforced by layer and mask (R1, R2, AC1, AC2) | ADR-0004 | ✅ |
| TR-props-003 | Props reset to authored transforms on restart (R6, AC8) | *ADR-0011* | ❌ |
| TR-props-004 | Sleeping props are force-woken on every change (R5, AC3) | ADR-0001 | ✅ |
| TR-props-005 | Props leaving level bounds are freed (R7, AC9) | *ADR-0011* | ❌ |
| TR-props-006 | Fall-speed cap; per-prop mass and damping (§4, §7, AC7) | *ADR-0011* | ❌ |
| TR-props-007 | Prop count is budgeted and flagged at load (R8, §5) | ADR-0003 | ✅ |
| TR-props-008 | A room of props at budget holds 60 FPS during a flip (AC10) | *ADR-0011* | ❌ |
| TR-props-009 | `PropTuning` knobs and defaults (§7) | ADR-0006 | ✅ |

### Coverage gaps

All 28 gaps are assigned to a planned ADR, with one exception.

| Suggested ADR | Requirements | Domain | Engine Risk |
|---|---|---|---|
| ADR-0007 — Player component contract | `TR-gravity-004/005/006/007/013`, `TR-watering-002/014` | Core / Physics-2D | LOW |
| ADR-0008 — Oxygen drain and death path | `TR-oxygen-001/002/003/004/006` | Core | LOW |
| ADR-0009 — Watering interaction model | `TR-watering-001/003/004/005/009/010/016` | Feature | LOW |
| ADR-0010 — HUD architecture | `TR-watering-017/018`, `TR-oxygen-007/009` | Presentation / UI | **MEDIUM** — Control offset transforms are the one live deprecation entry, and `offset_transform_visual_only` defaults to `true` |
| ADR-0011 — Physics props implementation | `TR-props-003/005/006/008` | Presentation / Physics-2D | LOW |
| ADR-0012 — Spent jug throw and lifetime | `TR-watering-007` | Presentation | LOW |

**`TR-oxygen-006` (pause halts drain) has no owner.** `architecture.md` QQ-04
routes it to ADR-0010, whose scope is HUD and Control offset usage. The node that
would have to consult the pause state is `OxygenDrain`, which ADR-0008 owns.
Neither ADR claims it. `suit-oxygen.md` §5 states the requirement plainly — "when
one is added, halting the drain is a requirement, not a nicety" — and no pause
menu exists.

---

## Cross-ADR Conflicts

No conflict is a logical contradiction between two decisions. All eight are
**stale text or undefined scope**: an implementer following one document
literally would violate another. Three are in `docs/registry/architecture.yaml`,
which `/architecture-decision` reads as a blocking conflict gate — drift there
propagates into every future ADR.

### 🔴 C1 — `V-WIRING` makes the migration epic's exit criterion unachievable

**Type**: Integration contract / undefined scope
**Documents**: ADR-0003 D3.3 vs ADR-0002 part 3 vs ADR-0010 (unwritten)

ADR-0002 adds `@export var hud: HUD` to `LevelRoot` and lists `HUD` in its
injection table as a bound consumer. ADR-0003's `V-WIRING` requires "every
**required** consumer `NodePath` export on `LevelRoot` is non-empty and resolves"
— and never enumerates which consumers are required.

No HUD scene exists. `systems-index.md` lists it under *Designed but not built*;
it belongs to ADR-0010, which is Presentation tier and explicitly deferred. No
level wires one.

ADR-0003 D3.7 names only `V-GRAV-EXPORT` and `V-OXY-CAP` as the reasons the
suite-wide test is red today, and Migration Plan step 6 lists only
`default_gravity_*`, the bucket economy and a derived `oxygen_capacity`.

**Impact**: ADR-0003's stated close condition — "Every level must return empty
from `validate()` before the epic closes" (Migration step 6, Validation Criterion
5) — cannot be satisfied by the specified steps. The epic completes with the
gate still red, or `V-WIRING` gets quietly weakened during implementation, which
is how a validation rule turns into decoration.

**Resolution options**:
1. Enumerate the required-consumer set in D3.3 and scope `V-WIRING` to consumers
   whose ADR is Accepted, admitting `hud` when ADR-0010 lands. Preferred — it
   keeps the rule honest and makes the growth explicit.
2. Add HUD authoring to the migration epic, accepting that a Presentation-tier
   ADR now gates a Foundation-tier epic.
3. Split `V-WIRING` into a fixed core set and an advisory extended set. Weakest —
   an advisory validation rule is the failure P4 exists to close.

### 🟠 C2 — ADR-0002's migration prose contradicts ADR-0003 D3.5

**Type**: Data-source conflict
**Documents**: ADR-0002 Migration step 3 and Risks table vs ADR-0003 D3.2/D3.5

ADR-0002 says to seed `buckets_total` "from the bucket group count" in two
places: Migration Plan step 3 (line 488) and the Risks row on `buckets_total`
being seeded from the wrong source.

ADR-0003 D3.2 forbids group-based discovery outright — registered as
`group_based_level_discovery`, on the ground that `get_nodes_in_group()` is a
`SceneTree` method and is **unavailable** on the null-tree CI path — and D3.5
requires both `validate()` and `LevelRoot` to seed from the single
`count_buckets()` primitive.

The registry records this as a narrowing under `LevelValidation.contract`, and
ADR-0003 is explicit that the *quantity* ADR-0002 defines is unchanged. But
**ADR-0002's own text was never amended**, and ADR-0002 is the document whose
changeset an implementer works from.

**Impact**: seeding from a group count bypasses D3.5, producing exactly the
failure D3.5 exists to prevent — `V-BUCKET-SUM` passing while `LevelRoot` seeds
`buckets_total` from a subtly different count, so validation certifies a value
the game does not use.

**Resolution**: amend ADR-0002 Migration step 3 and the Risks row to name
`LevelValidation.count_buckets()`, citing ADR-0003 D3.5. The registry entry
already reads correctly and needs no change.

### 🟠 C3 — ADR-0005 D5.5 prescribes a migration into a file ADR-0009 will empty

**Type**: Forward integration conflict
**Documents**: ADR-0005 D5.5 and Migration step 6 vs `architecture.md` API
Boundaries (ADR-0009's scope)

ADR-0005 D5.5 enumerates four things that move from `plant.gd`'s `_process` to
its `_physics_process`: interact polling, `water_progress` accumulation, the
`water_duration` completion check, and the `_complete_watering()` /
`_reset_watering()` calls. The enumeration was added deliberately, in response to
specialist finding A5-04, because moving only the `+=` line would reproduce the
two-clocks defect while appearing to fix it.

But `architecture.md`'s API Boundaries make `Plant` **passive**: `water_progress`
and pour driving move to `PlayerWateringComponent`, and the doc states why —
"a plant cannot know whether a *different* plant is nearer to the player", which
is what `watering-system.md` AC12 requires. That relocation is ADR-0009's.

The registry's `gameplay_timing_in_idle_process` remediation names `plant.gd`
specifically.

**Impact**: whichever of ADR-0005 and ADR-0009 lands second inherits a migration
instruction written against the other's file. If ADR-0005's migration runs first,
the work is redone; if ADR-0009's runs first, D5.5's enumeration points at code
that no longer exists and the clock discipline can be lost in transit — silently,
because the symptom is frame-rate-dependent behaviour that survives testing at
60 FPS.

**Resolution**: ADR-0009 must restate the D5.5 clock requirement against
`PlayerWateringComponent` and update the forbidden-pattern remediation. Recording
it here so ADR-0009's author inherits the obligation rather than discovering it.

### 🟠 C4 — Registry `frame_ordering_contract` contradicts its own ADR

**Type**: Registry drift
**Documents**: `architecture.yaml:267` vs ADR-0005 D5.1 / Key Interfaces /
Migration step 0

The registry entry reads: "`process_physics_priority`, assigned in `_ready()`
from **LevelRoot constants**".

ADR-0005 hoisted the constants off `LevelRoot` into a const-only `FramePriority`
script, in response to specialist finding A5-05, and its Key Interfaces block
carries the reason inline: "**NOT** on `LevelRoot`: `GravityAuthority` is an
autoload present before any level scene loads, and must not source a constant
from a per-level scene script."

**Impact**: the registry is the blocking conflict gate every new ADR is checked
against. An ADR-0007 or ADR-0008 author reading it would place the constants back
on `LevelRoot`, re-inverting the dependency direction `architecture.md:359` ("no
module calls upward") forbids — and would pass the gate while doing so.

**Resolution**: correct the entry to name `FramePriority`. Note that the file's
own header states "Append only. Never edit or delete an existing entry", so this
is either a permitted correction of a transcription error or a supersession —
worth deciding which, since the same question will recur.

### 🟠 C5 — Registry records a guard ADR-0005 declared insufficient

**Type**: Registry drift
**Documents**: `architecture.yaml` `restart_level_chokepoint_guard` vs ADR-0005
D5.4

The entry states the choice as "`LevelRoot.restart_level()` returns early when
`level_complete` is true", with no mention of `_transition_pending`.

ADR-0005 D5.4 is explicit that the latch alone is **not sufficient**:
`body_entered` for different `Area2D` nodes in the same `flush_queries()` batch
is not ordered by `process_physics_priority`, and no deterministic inter-area
delivery order could be established from documentation or source. "Guarding on
`level_complete` alone cannot close this, because the order in which the two
handlers run is the very thing in question."

**Impact**: same as C4 — a future ADR checked against the registry sees the
weaker contract, and the sibling-area race A5-02 identified reopens. This is the
narrower of the two drifts but the more consequential, because the gap it leaves
is a race rather than a naming error.

**Resolution**: add `_transition_pending` to the entry's `choice` and
`implementation_notes`, citing D5.4 and A5-02.

### 🟡 C6 — ADR-0001's tuning reach predates ADR-0006

**Type**: Integration contract
**Documents**: ADR-0001 part 4 vs ADR-0006 D6.3

ADR-0001's part 4 snippet reads
`descent_magnitude() * prop_tuning.prop_gravity_scale` — an unqualified
reference with no stated origin. At the time it was written, no document defined
how a consumer obtains a tuning resource; ADR-0006's Problem Statement cites this
exact line as evidence.

ADR-0006 D6.3 makes `Tuning.PROP.prop_gravity_scale` the only sanctioned reach
and registers `tuning_path_literal_outside_holder` as forbidden. ADR-0006's own
architecture diagram shows the corrected form. ADR-0001 was not amended.

**Impact**: low in isolation — ADR-0006 is unambiguous and an implementer reading
both will use `Tuning.PROP`. But ADR-0001 is the document that owns the per-frame
easing write, and leaving the reach unspecified there is the no-owner condition
ADR-0006 exists to end.

**Resolution**: amend ADR-0001 part 4 to `Tuning.PROP.prop_gravity_scale` with a
pointer to ADR-0006 D6.3.

### 🟡 C7 — Registry carries two discharged verification items

**Type**: Registry drift

1. `prop_gravity_via_physics_space.verify_at_implementation` still lists "exact
   enum spelling of `AREA_PARAM_GRAVITY_VECTOR` / `AREA_PARAM_GRAVITY`". Resolved
   on 2026-08-14 (review R1): `AREA_PARAM_GRAVITY = 1`,
   `AREA_PARAM_GRAVITY_VECTOR = 2`, and `World2D.space` is documented as
   deliberately dual-registered as both space and area, making the part-4 snippet
   the officially sanctioned pattern. ADR-0001's Engine Compatibility row was
   updated; the registry was not.
2. `armed_death_one_frame_deferral.implementation_notes` still describes "the one
   unresolved phase question: whether `body_entered` is emitted at the tail of
   step N or at the query flush opening frame N+1". Resolved on 2026-08-14
   (review R4) to a third and stronger reading — `flush_queries()` fires signals
   from the *previous* substep's `step()`, so delivery is at the head of frame
   N+1, before *any* node's `_physics_process`. ADR-0005's F2 corollary was
   rewritten; the registry was not.

Neither is harmful — both notes say the decision holds either way. Both cost
future readers effort re-opening settled questions, which is the specific waste
the "Do not re-search these" convention exists to prevent.

### 🟡 C8 — `Plant` is in the ordering contract but assigned no priority

**Type**: Integration contract
**Documents**: `architecture.md:298` and `architecture.yaml:269` vs ADR-0005 D5.1
and Migration step 5

`architecture.md`'s frame table and the registry's `frame_ordering_contract` both
place `Plant` at priority `0` alongside `Player`. ADR-0005 D5.1's table has no
`Plant` row; `FramePriority` declares `GRAVITY`, `PLAYER` and `OXYGEN` only; and
Migration step 5 assigns priorities to `GravityAuthority`, `Player` and
`OxygenDrain`.

Functionally safe — an unassigned node defaults to `0`, which still precedes
`OxygenDrain` at `+100`, and that ordering is all AC13 needs. But it holds by the
engine default, which is the exact mechanism D5.1 says the contract exists to
replace ("tick order would have silently remained an accident of tree layout").
Validation Criterion 4's grep checks three `_ready()` methods and would not cover
`Plant`.

Interacts with C3: if pour driving moves to `PlayerWateringComponent`, `Plant`
leaves the ordering table entirely and this resolves itself.

---

## ADR Dependency Order

No cycles. No ADR depends on an ADR that does not exist.

```
Foundation — no dependencies
  1. ADR-0001  Gravity ownership and global broadcast
  2. ADR-0002  Level state ownership              (peer to ADR-0001)
  3. ADR-0004  Collision layer allocation         (fully independent)
  4. ADR-0006  Tuning resource strategy           (fully independent)

Depends on Foundation
  5. ADR-0003  Level load validation contract     (requires ADR-0001, ADR-0002;
                                                   ADR-0006 for V-PROP-BUDGET)
  6. ADR-0005  Frame ordering + level_complete    (requires ADR-0002)

Core / Feature — unwritten
  7. ADR-0007  Player component contract          (requires ADR-0001)
  8. ADR-0008  Oxygen drain and death path        (requires ADR-0002, 0005, 0006)
  9. ADR-0009  Watering interaction model         (requires ADR-0002, 0005, 0006)

Presentation — unwritten
 10. ADR-0010  HUD architecture                   (requires ADR-0002)
 11. ADR-0011  Physics props implementation       (requires ADR-0001, 0004, 0006)
 12. ADR-0012  Spent jug throw and lifetime       (requires ADR-0006)
```

⚠️ **Every dependency in this graph is unresolved. All six written ADRs are
`Proposed`.**

- ADR-0005 states "ADR-0002 … **Must be Accepted first**." ADR-0002 is Proposed.
- ADR-0003 depends on ADR-0001 and ADR-0002, both Proposed.
- ADR-0003's *Blocks* field names the level migration epic and the test evidence
  for `watering-system.md` AC7 and `suit-oxygen.md` AC7 — both Logic-typed and
  therefore BLOCKING under `.claude/docs/coding-standards.md`.

Two asymmetric declarations, both benign and both reconciled in prose:

- ADR-0001 lists ADR-0004 under *Enables*; ADR-0004 declares "**Depends On**:
  None … nothing here reads gravity state." ADR-0004 is right — the asymmetry is
  ADR-0001 anticipating work rather than a genuine dependency.
- ADR-0006 lists ADR-0003 under *Enables*; ADR-0003 records only an Ordering Note
  and states it "can be accepted before either." Also right — the gate is on
  `V-PROP-BUDGET`'s *implementation*, not on ADR-0003's acceptance.

---

## GDD Revision Flags

Five GDD assumptions conflict with a written ADR or with verified engine
behaviour. None blocks acceptance; all should be resolved via
`/propagate-design-change` once the governing ADR is Accepted, per
`systems-index.md`'s standing instruction not to edit a GDD ahead of its ADR.

| GDD | Assumption | Reality | Action |
|---|---|---|---|
| `suit-oxygen.md` §5, R3 | "Oxygen reaches zero mid-gravity-transition → **Death is immediate**." R3: "On `oxygen_remaining <= 0` the player dies" | ADR-0005 D5.2 defers the kill by **one physics frame** by design. ADR-0005's own Negative consequences: "There is a single frame in which `remaining <= 0` and the player is still alive and controllable" | **Revise.** A test author reading "immediate" writes a same-frame assertion that fails against the intended design |
| `suit-oxygen.md` §4, §7 | `drain_rate` is an "**accessibility hook only** … lowering it grants more real time without touching level design" | ADR-0006 D6.5 forbids writing to a tuning resource at runtime, `.duplicate()` included. D6.6 resolves it by separating the authored default from a player-facing setting that is user data, and assigns the composition to ADR-0008 | **Revise.** ADR-0006's own Risks table names a settings menu writing `drain_rate` as the most likely D6.5 violation, "because `suit-oxygen.md` §7 invites it in prose" |
| `gravity.md` §3, §7 | No mention of `default_gravity_direction` / `default_gravity_multiplier` | ADR-0001 part 6 makes them mandatory per-level exports. `V-GRAV-EXPORT` fails every level lacking them; all 8 currently do | **Revise.** Already listed pending in `systems-index.md` |
| `watering-system.md` / `suit-oxygen.md` | Neither owns `level_complete` | Specified only in `architecture.md` and ADR-0005. Without it, `watering-system.md` AC13 and `suit-oxygen.md` AC8 directly contradict each other | **Assign an owner.** Already flagged in `systems-index.md` under *New requirement with no GDD home* |
| `physics-props.md` §3 R3 | "Props obey the global gravity vector … they consume the same vector the player does" | ADR-0001 D3/part 4: props receive gravity from the **default 2D physics space**, not from the `gravity_changed` signal. §6 already hedges correctly ("not by subscribing to zones individually"); §3 does not | **Clarify** (minor). The registry hedges this correctly; `architecture.md` does not — see Phase 6 |

---

## Engine Compatibility

**6 / 6 ADRs carry an Engine Compatibility section.** No blind spots.

| Check | Result |
|---|---|
| Version consistency | ✅ All six declare Godot 4.7. No ADR written against an older version |
| Deprecated API references | ✅ None. The two entries in `deprecated-apis.md` are Bullet physics (3D, inert here) and Control offset behaviours (ADR-0010's scope, unwritten) |
| Post-cutoff APIs | ✅ All six declare "None", and all six are correct. `process_physics_priority` is 4.1 (verified against `scene/main/node.h` — absent in 4.0-stable, present in 4.1-stable). `CollisionShape2D.one_way_collision_direction` (4.7) is named by ADR-0001 and deliberately declined |
| Post-cutoff API conflicts | ✅ None. No two ADRs make contradictory assumptions about the same API |
| Jolt Physics | ✅ Explicitly scoped out by ADR-0001 and ADR-0004. `project.godot` sets `3d/physics_engine="Jolt Physics"`; this is a 2D game and the setting is inert |

### Knowledge Risk is declared inconsistently

ADR-0006 rates its domain **HIGH**, on the ground that no `modules/core.md`
reference exists. ADR-0002, ADR-0003 and ADR-0005 rest on the same uncovered
Core / GDScript / SceneTree surface and each rate **LOW**.

Post-verification, LOW is defensible for all four — each was independently
checked by a specialist gate. But the underlying gap is real and standing:
**`docs/engine-reference/godot/modules/` contains only `physics-2d.md` and
`ui-control.md`, while four of six ADRs depend on Core semantics.** The
2026-08-14 review identified this pattern precisely — "Every
`Verification Required: None` claim was overstated … Most held. One did not" —
and the one that did not was A2-01, a blocking finding.

Recommend `/setup-engine refresh` to add a Core module reference before ADR-0007
and ADR-0008, both of which are Core-tier.

### Open engine claims

| ID | Claim | State |
|---|---|---|
| ADR-0006 **T4** | `@export_range` constrains the inspector but does not clamp a hand-edited `.tres` | **Documentation only — not executed.** The specialist began building a project against the pinned `4.7.1-stable` binary and was interrupted. ADR-0006 Migration step 5 owns closing it. Nothing in the decision depends on it; T4 only justifies why D6.4 is authoring-time-only |
| ADR-0001 **Verification Required #2** | A default-space write made in `_physics_process` reaches every `RigidBody2D` in that same step | **Open, narrowed.** Items 1 and 3 were discharged 2026-08-14. This is what `gravity.md` AC12 and `physics-props.md` AC4 rest on, so it should be the first thing Changeset B proves |

### Engine specialist consultation — not run

Phase 5 calls for spawning the primary engine specialist. Not run this session,
for two reasons, recorded so the omission is deliberate rather than silent:

1. The operating rules for this session bar spawning subagents unless requested.
2. All six ADRs already carry a specialist gate result: ADR-0001, ADR-0002 and
   ADR-0005 from the 2026-08-14 review (fifteen amendments applied across three
   files); ADR-0003 (F1–F11), ADR-0004 (L1–L6, F1–F8) and ADR-0006 (T1–T4,
   F1–F6) from their authoring sessions.

**The gap that remains**: ADR-0003, ADR-0004 and ADR-0006 were reviewed by the
specialist *during authoring*, in the same session that wrote them. ADR-0001,
ADR-0002 and ADR-0005 got an *independent* second opinion in a separate session,
and that independence is what caught A2-01. A fresh pass over the three
self-reviewed ADRs is worth running before they are Accepted.

---

## Architecture Document Coverage

Every system in `systems-index.md` appears in `architecture.md`'s layer map, and
the data-flow and API-boundary sections cover all four. The defects run the other
way: **`architecture.md` has not been amended for ADR-0004 or ADR-0006, and still
carries the ADR-0002 blocking finding that the 2026-08-14 review fixed in the ADR
only.**

| Line | Currently says | Should say | Severity |
|---|---|---|---|
| 682 | `# collision_layer = PROP(4) ; collision_mask = WORLD(1) \| PROP(4)` | `collision_layer = 8` (PROP), `collision_mask = 9` (WORLD \| PROP) per ADR-0004 D4.1/D4.3 | 🔴 An implementer copying this authors **the retired bit 3** and value `5` for the mask. Trips D4.5 assertion 2 (`(layer\|mask) & ~ALLOCATED == 0`) and breaks `physics-props.md` R1 |
| 509–522, 534–547 | `LevelState` / `OxygenState` API blocks declare plain `var buckets_total`, `var remaining`, etc. | Getter-only computed properties over private backing fields | 🔴 This **is** A2-01, the prior review's single blocking finding. Corrected in ADR-0002, still live in the blueprint. As written, `level_state.goal_unlocked = true` compiles and succeeds, and `suit-oxygen.md` AC3 stays a rule to police |
| 181 | Bit 3 `item` is live, "masked by player only" | Retired and occupied by nothing (D4.2) | 🟠 ADR-0004 names this line as one it corrects |
| 685 | "**Callers must never:** add the `player` or `item` bits to the mask" | `item` no longer exists; the name is removed from `project.godot` | 🟠 |
| 81, 96, 169 | `CollisionLayerRegistry` | `CollisionLayers` (D4.4 — "it registers nothing at runtime, it is a constant table") | 🟠 |
| 196 | `OxygenDrain` engine APIs: `Node`, `_process` | `_physics_process`. `_process` for rule-bearing timing is the registered forbidden pattern `gameplay_timing_in_idle_process` | 🟠 |
| 212, 364 | `PhysicsProps` consumes `GravityAuthority.gravity_changed` | Consumes default-space gravity (ADR-0001 D3). The registry hedges correctly — "`PhysicsProps  # indirect, via default-space gravity`" — the blueprint does not | 🟠 |
| 95 | Foundation table lists "Tuning resources" generically | Should name the `Tuning` const holder, which is the reach mechanism (ADR-0006 D6.3) | 🟡 |
| 505 | Props "woken on the same frame the vector changes" | Woken on **every frame while easing**, not only on the zone-fire frame (ADR-0001 part 4b — "a prop can settle part-way through the ease") | 🟡 |
| 263 | "Exact enum spelling: confirm at implementation time" | Resolved 2026-08-14 (R1) | 🟡 |
| 10, 702 | "ADRs Referenced: none exist — 12 required"; "0 of 52 requirements covered. 52 gaps." | 6 written, 22 covered by a written ADR, 0 by an accepted one | 🟡 |

This is the third consecutive session in which `architecture.md` has been found
to carry ordering or accuracy defects. Its tables and sequencing blocks should be
treated as suspect until an ADR has re-derived them.

### Orphaned architecture — present in the blueprint or in code, no GDD

| Item | Note |
|---|---|
| Spike hazards | **The sharp one.** `suit-oxygen.md` R3/AC2 requires oxygen death to be *indistinguishable* from spike death, and ADR-0005 D5.4 routes `inc_hazard_dmg` through the guarded chokepoint. An undocumented mechanic is load-bearing for a Core acceptance criterion |
| Wall jump | `player_wall_jump_component.gd`. Traversal mechanic, no GDD, no TR, no ADR (QQ-05) |
| Moving platforms | `moving_platform.gd`. Also carries defect 3 from ADR-0004 — an inert `collision_mask = 2` on an `AnimatableBody2D` |
| Level flow / progression | `main.gd`, `goal.gd`, 8 levels, `change_scene_to_packed` chain |
| Start menu | `start_menu.tscn`. No pause menu exists, which is what leaves `TR-oxygen-006` unowned |
| `level_complete` | Specified in `architecture.md` and ADR-0005; no GDD owner |
| `default_gravity_*` | `architecture.md` D6 states it directly: "No GDD covers this requirement — it is a direct consequence of D1" |

---

## Verdict: CONCERNS

**Not PASS.** Eight cross-ADR conflicts, two material: C1 leaves the level
migration epic with an exit criterion it cannot meet, and C2 has ADR-0002's
changeset instructing a mechanism ADR-0003 registers as forbidden. Three of the
eight are drift in `docs/registry/architecture.yaml`, which is the blocking
conflict gate every future ADR is checked against. `architecture.md` states
collision values that would author the retired bit, and still carries the A2-01
blocking defect that was corrected in ADR-0002 on 2026-08-14.

**Not FAIL, and the deviation is deliberate.** The rubric treats uncovered Core
layer requirements as FAIL, and 28 requirements are uncovered. But
`architecture.md`'s own plan is Foundation ADRs before *any* implementation, and
Core and Feature ADRs before *the relevant system* is built. The Foundation tier
is complete in writing, every gap has a named future ADR, and the sequencing is
the plan executing rather than a defect. Recording the deviation so the call is
visible rather than buried.

### Blocking issue

**No ADR is `Accepted`.** Six written, zero accepted. This is not among the
findings above because it is not a defect in any document — it is a decision that
has been pending since session 5 and deferred three times.

- ADR-0005 requires ADR-0002 Accepted before it can be implemented.
- ADR-0003 requires ADR-0001 and ADR-0002 Accepted.
- ADR-0003 blocks the level migration epic and the test evidence for
  `watering-system.md` AC7 and `suit-oxygen.md` AC7, both Logic-typed and
  therefore BLOCKING gates.
- ADR-0007 through ADR-0012 and every downstream story are gated behind it.

Nothing in the project can move until it is made.

### Required ADRs, most foundational first

1. **ADR-0007 — Player component contract and physics step order.** 5 gravity +
   2 watering requirements. Contains `TR-watering-014` (AC1), which
   `architecture.md` P3 names the automated guard on the geometric contract that
   lets level design prove a gap crossable, and which `watering-system.md` says
   to write first.
2. **ADR-0008 — Oxygen drain and the shared death path.** 5 requirements.
   Inherits the `drain_rate` accessibility composition from ADR-0006 D6.6, and
   should claim the orphaned `TR-oxygen-006`.
3. **ADR-0009 — Watering interaction model.** 7 requirements, the largest single
   block. Owns the C3 resolution — restating D5.5's clock discipline against
   `PlayerWateringComponent`.

### Recommended remediation, in order

| # | Action | Cost |
|---|---|---|
| 1 | Decide `Proposed` → `Accepted` on the six Foundation ADRs | The only blocker |
| 2 | Fix C4 and C5 — registry drift on `frame_ordering_contract` and `restart_level_chokepoint_guard` | Two entries; the gate is wrong today |
| 3 | Fix `architecture.md:682` collision values and the 509–547 API blocks | Two edits; both are 🔴 |
| 4 | Resolve C1 — scope `V-WIRING`'s required-consumer set | One ADR-0003 amendment |
| 5 | Fix C2 — amend ADR-0002's migration step 3 and Risks row | One ADR-0002 amendment |
| 6 | Remaining `architecture.md` amendments for ADR-0004 and ADR-0006 | Batch with a `/propagate-design-change` pass |
| 7 | Persist the TR baseline as `docs/architecture/tr-registry.yaml` | Deferred by user decision this session — see below |

### Pre-gate checklist

| Artifact | State |
|---|---|
| `tests/unit/` | ✅ |
| `tests/integration/` | ✅ |
| `.github/workflows/tests.yml` | ✅ |
| `design/ux/accessibility-requirements.md` | ❌ |
| `design/ux/interaction-patterns.md` | ❌ — `design/ux/` does not exist |

`/gate-check pre-production` is not available until the UX artifacts exist. Run
`/ux-design` first. Note also that `production/stage.txt` still reads `Concept`,
which is stale — advance it through `/gate-check`, not by hand.

---

## Files written by this review

Only this report. `docs/architecture/tr-registry.yaml` and
`docs/architecture/traceability-index.md` were **offered and declined** on
2026-08-15, on the ground that 45 of the 52 ID assignments are inferred rather
than recovered, and writing the registry would make them the anchor every future
story and ADR cites. The matrix above is the working record until that decision
is revisited.
