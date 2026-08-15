# Architecture Review — Engine Specialist Consultation

> **Date**: 2026-08-14
> **Mode**: `/architecture-review` — engine specialist consultation only
> **Engine**: Godot 4.7 (pinned 2026-08-13, `docs/engine-reference/godot/VERSION.md`)
> **ADRs reviewed**: ADR-0001, ADR-0002, ADR-0005 — all `Proposed` at review time
> **Reviewers**: three independent `godot-specialist` agents, one per ADR

This report covers the engine specialist consultation that was **skipped during
authoring** of all three ADRs (recorded in `production/session-state/active.md`
under "Reviews skipped"). Each ADR was authored with inline validation against the
in-repo engine references; this review is the independent second opinion those
sessions deferred.

It is **not** a full `/architecture-review`. Traceability (Phase 2–3), cross-ADR
conflict detection (Phase 4), GDD revision flags (Phase 5b) and architecture-doc
coverage (Phase 6) were not run. The TR matrix remains unpersisted.

---

## Scope and method

Each reviewer was given: the target ADR, the in-repo engine reference snapshots,
the GDDs the ADR claims to satisfy, and the `src/` code the ADR describes. Each was
instructed to verify against live documentation rather than training data, on the
grounds that the pinned engine is roughly a year past the model cutoff.

Verification transport varied by session — one used WebFetch, one used `curl`
against `docs.godotengine.org`, one additionally traced engine source on GitHub
across tags `4.0-stable` through `4.3-stable`.

**Stated verification gap.** No literal `4.7` tag was fetchable from the public
repository. Source tracing therefore establishes behaviour across 4.0–4.3, and
`docs/engine-reference/godot/modules/physics-2d.md` (verified 2026-08-13) certifies
node processing and 2D physics unchanged 4.4 → 4.7. That combination is the
strongest available evidence, and is weaker than direct 4.7 confirmation. It is
recorded here plainly rather than presented as 4.7-exact verification.

**A pattern across all three ADRs.** Every `Verification Required: None` claim was
overstated. The in-repo engine snapshots cover only `physics-2d` and `ui-control`;
Core, GDScript, object lifetime and SceneTree semantics are not covered by any
in-repo reference. Those facts were asserted without independent checking. Most
held. One did not — see ADR-0002 A2-01.

---

## Consolidated verdict

| ADR | Title | Verdict | Blocking | Concerns | Notes |
|---|---|---|---|---|---|
| ADR-0001 | Gravity ownership and global broadcast | CONFIRM WITH ADDITIONS | 0 | 3 | 5 |
| ADR-0002 | Level state ownership | CONFIRM WITH ADDITIONS | **1** | 2 | 7 |
| ADR-0005 | Frame ordering and the `level_complete` guard | CONFIRM WITH ADDITIONS | 0 | 5 | 6 |

No reviewer challenged the core reasoning of any ADR. All three decisions are
implementable as designed. One finding — ADR-0002 A2-01 — must be corrected before
implementation, because the code as specified does not deliver the guarantee the
prose promises.

---

## Resolved questions — do not re-derive

These four were open, load-bearing, and are now settled. They are recorded here so
no later ADR or implementation session spends effort on them again.

**R1 — `World2D.space` is deliberately dual-registered as both a space and an
area.** The ADR-0001 reviewer initially judged
`PhysicsServer2D.area_set_param(space, …)` to be broken, on sound grounds:
`area_set_param` types its first argument as an area RID, and
`PhysicsServer2D.SpaceParameter` contains no gravity entries at all — only
contact, solver and sleep-threshold parameters. The live documentation
special-cases the default space's RID for exactly this purpose, stating it is
"used by `PhysicsServer2D` for 2D physics, treating it as both a space and an
area." The snippet in ADR-0001 part 4 is the officially documented pattern for
changing 2D default gravity at runtime — it is the code sample under
`ProjectSettings.physics/2d/default_gravity`.

Scope limit: this dual behaviour is documented for the default space's own RID and
for gravity/damping parameters. It does not license treating a space RID as a
general-purpose area — `area_set_collision_mask(space, …)` and similar are not
sanctioned.

- `AREA_PARAM_GRAVITY = 1`, `AREA_PARAM_GRAVITY_VECTOR = 2` — spellings confirmed
- Source: <https://docs.godotengine.org/en/stable/classes/class_physicsserver2d.html>,
  <https://docs.godotengine.org/en/stable/classes/class_world2d.html>

**R2 — Signal connections to a `RefCounted` are weak references.** They do not
increment the refcount. `LevelRoot` connecting `Plant.pour_completed` to
`level_state.consume_bucket()` therefore does not keep `LevelState` alive past a
scene reload. ADR-0002's "restart is reconstruction" guarantee holds — but for a
reason the ADR does not state; see A2-03.

- Source: <https://docs.godotengine.org/en/stable/classes/class_object.html>,
  godotengine/godot#71389

**R3 — `process_physics_priority` ordering is a single global sort.**
Physics-processing nodes are held in one flat vector per process group, sorted by a
global priority comparator with a scene-tree-position tiebreak. Autoloads (direct
children of the SceneTree root) and ordinary scene descendants share the single
`default_process_group`. There is no per-parent partitioning and no separate
autoload branch. `GravityAuthority` at `-100` genuinely precedes `Player` at `0`
and `OxygenDrain` at `+100`, engine-wide.

This was the sharpest open risk to ADR-0005 — had ordering been per-parent, the
priority table would have ordered nothing, reproducing the exact class of defect
(F1) that ADR-0005 was written to correct.

- Source: `scene/main/scene_tree.cpp` — `_process_group()`,
  `_add_node_to_process_group()`, `default_process_group`
- Property introduced in **4.1** (absent in 4.0-stable, present in 4.1-stable,
  `scene/main/node.h`), which is what makes ADR-0005's
  "Post-Cutoff APIs Used: None" correct

**R4 — `body_entered` is delivered at the head of the next physics substep, before
the entire `_physics_process` batch.** ADR-0005's F2 corollary hedged between two
readings and argued the choice did not matter. It is resolvable, and the answer is
a third and stronger reading. `Main::iteration()` runs, per substep:

```
PhysicsServer2D::sync()
PhysicsServer2D::flush_queries()      ← body_entered fires here
SceneTree::physics_process()          ← all _physics_process, priority-ordered
PhysicsServer2D::end_sync()
PhysicsServer2D::step()               ← overlaps computed here
```

`flush_queries()` fires signals from pairs computed by the *previous* substep's
`step()`. So an overlap caused by frame N's `move_and_slide()` is computed by
frame N's `step()` — which runs after every node's `_physics_process`, including
`OxygenDrain` at `+100` — and the resulting `body_entered` is flushed at the very
start of frame N+1, before *any* node's `_physics_process` that frame.

ADR-0005's D5.2 diagram is correct, and the design rests on firmer ground than the
ADR itself demonstrates.

- Source: `main/main.cpp` `Main::iteration()`, loop body (4.3-stable)

---

## Could not be verified

Stated as unknown rather than assumed. Two of the three underpin findings below.

1. **Inter-area `body_entered` delivery order.** When two different `Area2D` nodes
   have pending `body_entered` deliveries in the same `flush_queries()` call — for
   example `Goal` and a spike hazard — no documentation or reachable source
   establishes whether that order is deterministic, or by what rule. This is the
   basis of A5-02, which is written as an unguarded gap, not a proven bug.
2. **`change_scene_to_packed()` flush point relative to
   `call_deferred("reload_current_scene")`.** Both resolve by end of frame; which
   `MessageQueue` flush each uses was not traced. A5-02's recommended fix resolves
   the question regardless of the answer.
3. **Literal 4.7 confirmation** for any source-traced claim — see the verification
   gap above.

---

## ADR-0001 — Gravity Ownership and Global Broadcast

**Verdict: CONFIRM WITH ADDITIONS.** No blocking findings. All code citations
(`main.gd:27`, `player.gd:183`, `player.gd:71`, `gravity_zone.tscn:12-13`) verified
accurate. Verification Required items #1 and #3 both resolved favourably — see R1,
and A1-02 for the wake mechanism.

Confirmed as written: space gravity does not wake a sleeping `RigidBody2D`;
`CharacterBody2D` has no automatic gravity of any kind and cannot be contaminated
by the symmetric prop path; `_exit_tree()` is the correct unregister hook, firing
synchronously on both `queue_free()` and `reload_current_scene()` and earlier than
`NOTIFICATION_PREDELETE`; scene autoload is genuinely required for `@export`
inspector editability; `_ready()` bottom-up and autoload-before-scene both hold.
Nothing in the 4.5–4.7 change set (AreaLight3D, HDR output, Control offset
transforms, Jolt) touches this decision.

### A1-01 — CONCERN — Callback for the space write is unspecified

**Location**: Decision parts 4a / 4b; Key Interfaces "Guarantees"

**Claim**: "The authority therefore rewrites both space params every physics frame
while `gravity != target_gravity`", and the same-frame guarantee is listed as
satisfying `gravity.md` AC12 and `physics-props.md` AC4.

**Reality**: `_physics_process()` is called before every physics step, so a write
there lands before the step that integrates it and the same-frame guarantee holds.
`_process()` runs once per rendered frame and is decoupled from the fixed-timestep
loop — relative to a given physics step it may run zero, one or several times. A
write there has no defined phase relationship to integration.

**Impact**: `_process` is a natural first instinct for "per-frame world-state"
code. Choosing it silently breaks AC12 in a way that looks correct at 60 FPS and
misbehaves under load or vsync mismatch. ADR-0005 later assigns this node
`process_physics_priority = -100`, which only makes sense for `_physics_process` —
but ADR-0001 owns the AC12 guarantee and never states the mechanism that makes it
true.

**Recommendation**: State the `_physics_process` requirement in part 4a
independently of ADR-0005. *(Applied 2026-08-14.)*

### A1-02 — CONCERN — Wake mechanism never named

**Location**: Decision part 4b

**Claim**: `GravityAuthority` "force-wakes every registered prop."

**Reality**: A sleeping `RigidBody2D` wakes via collision, `apply_impulse()` or
`apply_force()`; changing space gravity does not wake it — confirming the ADR's
core assumption. The correct side-effect-free call is `prop.sleeping = false`.
`apply_impulse()` / `apply_force()` also wake a body, but by adding momentum,
making them visible nudges rather than silent wakes. `can_sleep = false` is a valid
per-prop escape hatch that renders the wake loop a harmless no-op for that prop.

**Impact**: Low alone. Combined with A1-01, this is the defect
`physics-props.md` R5/AC3 calls out as the single most likely implementation bug in
the game — worth naming rather than leaving as prose.

**Recommendation**: Name `prop.sleeping = false`; rule out the force-based calls.
*(Applied 2026-08-14.)*

### A1-03 — CONCERN — `class_name` / autoload identifier collision

**Location**: Key Interfaces

**Claim**: Not addressed. Pseudocode shows `extends Node` with no `class_name`.

**Reality**: Registering an autoload named `GravityAuthority` while also declaring
`class_name GravityAuthority` creates two competing global identifiers. Local
precedent cuts both ways: `gamemanager.gd`, the one existing autoload, correctly
has no `class_name` — but 13 of the 14 other scripts in `src/scripts/` do declare
one. The habit runs toward the collision.

**Impact**: Editor-level identifier conflict at best, ambiguous symbol resolution
at worst. Surfaces confusingly during implementation rather than being caught here.

**Recommendation**: Explicitly forbid `class_name` on `gravity_authority.gd`.
*(Applied 2026-08-14.)*

### A1-04 — NOTE — Inverted symptom description

**Location**: Context, "A second, quieter problem"; Decision part 5

**Claim**: Leaving the override in place "would present as props behaving correctly
only while inside a zone's bounds."

**Reality**: `gravity_space_override = 3` is `SPACE_OVERRIDE_REPLACE` — "replaces
any gravity/damping, even the defaults, ignoring any lower priority areas."
`GravityAuthority` writes only the default space's RID, never each zone's own area
RID. A `RigidBody2D` inside an un-cleared zone is therefore pinned to that zone's
static, never-updated `-980.0` regardless of any later flip; a prop outside all
zones correctly follows the broadcast. The symptom is the inverse of the sentence.

**Impact**: None on the decision — part 5 deletes the override, which is right
either way. Documentation accuracy only, but it would mislead a future reader
debugging this exact symptom by that description.

**Recommendation**: Reword. *(Applied 2026-08-14.)*

---

## ADR-0002 — Level State Ownership and Injectable State Objects

**Verdict: CONFIRM WITH ADDITIONS.** One blocking finding. The architecture —
injection over autoload, `RefCounted` state objects, restart-as-reconstruction,
bind guards mirroring ADR-0001 — is sound and idiomatic.

Confirmed as written: bottom-up `_ready()` and autoload-before-scene ordering,
including the ADR's correction to `architecture.md`'s init-order block;
`RefCounted` is the correct base (`Resource` would risk path-based cache sharing
if anyone later "upgrades" these for inspector visibility); same-class
enum-typed signal parameters type-check correctly, the known parser bug
(godotengine/godot#98273) applying only to cross-class enum references in signal
signatures; `RefCounted` with required `_init()` arguments is headless-constructible.

Citation check: `bucket.gd:7`, `main.gd:31,33,46,50,61` and `gamemanager.gd:12-15`
exact. `goal.gd:25,40` and `plant.gd:30,73` point at alias/comment lines rather than
the mutation lines (`goal.gd:26,41`; `plant.gd:76-79`); the "10 call sites across 5
files" total is internally consistent.

### A2-01 — BLOCKING — Read-only guarantees are not enforced by the interfaces

**Location**: Key Interfaces, both classes; Validation Criterion V2; Consequences

**Claim**: `goal_unlocked: bool  # derived, read-only`, and likewise
`buckets_consumed`, `remaining`, `fraction`. Consequences states oxygen AC3
"becomes a property of the type — there is no setter to call — rather than a rule
to police."

**Reality**: A plain `var` in GDScript is a public field with an implicit setter.
`level_state.goal_unlocked = true` compiles, runs, and succeeds silently from any
script. GDScript's actual read-only mechanism is the getter-only computed property
(`var x: int: get: return _x`, no `set:` block) over a private backing field;
assignment to one raises a runtime error.

**Impact**: As specified, all four values are ordinary public fields. Validation
Criterion V2 ("`goal_unlocked` cannot be set externally") cannot pass — a test
asserting the write errors will fail, because the write succeeds.
`suit-oxygen.md` AC3 remains a rule to police, which is precisely the failure mode
this ADR exists to eliminate. The gap is between the ADR's prose and its own code
block.

**Recommendation**: Rewrite both interfaces to getter-only properties over private
backing fields. *(Applied 2026-08-14.)*

- Source: <https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_basics.html>
  §Properties (setters and getters)

### A2-02 — CONCERN — `push_error()` does not halt execution

**Location**: Decision part 3

**Claim**: "every consumer refuses to operate before it is bound, with
`push_error()`."

**Reality**: `push_error()` "pushes an error message to Godot's built-in debugger
and to the OS terminal… does not pause project execution." It is a logging call,
not a control-flow interrupt.

**Impact**: A guard written `if not _bound: push_error("…")` with no `return` logs
the error and then continues against an unset reference — a null dereference, or
worse a silent read of default field values. The mistake is easy precisely because
`push_error()` reads like an exception to anyone coming from other languages.

**Recommendation**: Make the `return` explicit in the documented pattern. Separately
worth recording *why* `push_error()` and not `assert()`: `assert()` is compiled out
entirely in release exports, so every bind guard would vanish from the shipped
build. The ADR's choice is correct; the rationale was unstated, which invites a
future "simplification" to `assert()`. *(Both applied 2026-08-14.)*

### A2-03 — CONCERN — The reconstruction guarantee rests on an unstated invariant

**Location**: Decision part 2; Architecture Diagram "Lifetime" note

**Claim**: "`reload_current_scene()` frees `LevelRoot`, which drops the last
reference to both state objects."

**Reality**: `LevelRoot` does not hold the last reference. Per the ADR's own
injection table, `Player`, `Goal`, `HUD` and `OxygenDrain` each hold a strong
reference. Signal connections are weak (R2), so the `Plant.pour_completed` wiring
is safe — but the objects are freed only because every strong holder is destroyed
in the same synchronous `memdelete()` pass of the scene subtree, not because
`LevelRoot` is special.

**Impact**: No bug today; every consumer is a scene-local descendant of
`LevelRoot`. But the guarantee depends on an invariant the ADR never states. A
future persistent or cross-scene HUD — a common Godot pattern for overlays — would
hold a stale `LevelState` past the reload with no error, no crash, and no watchdog.
`RefCounted` leaks are invisible; the symptom would be a frozen or stale reading.

**Recommendation**: State the invariant in the Risks table. *(Applied 2026-08-14.)*

### A2-04 — NOTE — `class_name` global cache on fresh checkouts

The `class_name` → script map depends on `.godot/global_script_class_cache.cfg`,
which can be stale or missing on a fresh checkout, producing "identifier not
declared" failures for `class_name` types referenced early
(godotengine/godot#75684, #75388, #89399). Not currently an issue — this project's
headless gdUnit4 invocation already runs green — but if CI moves to a fresh-checkout
runner with no prior import pass, add an explicit `godot --headless --import` step
before test execution. No ADR change.

---

## ADR-0005 — Frame Ordering and the `level_complete` Guard

**Verdict: CONFIRM WITH ADDITIONS.** No blocking findings. Both load-bearing
engine facts hold — see R3 and R4 — and F2's acknowledged open question turned out
to be resolvable in the design's favour.

The reviewer was explicitly instructed to disregard the ADR's "Do not re-search
these" instruction and verify F1 and F2 independently. Both survived.

Confirmed as written: the four-step `OxygenDrain._physics_process` order
(freeze → armed → drain → arm) has no internal sequencing defect — both AC8 and
AC13 were traced by hand against the confirmed timing and reach the correct
outcome. Autoload `_physics_process` runs without `set_physics_process(true)`.
`LevelRoot`'s `const` values are safely readable from `Player._ready()` despite
bottom-up ordering, because `const` on a `class_name`-registered script resolves
from the global class table at script-load time, independent of instance
construction — no load-order hazard (but see A5-05).

That none of the ADR's referenced classes exist in `src/` yet is the expected
pre-implementation state, consistent with all three ADRs being `Proposed`, not a
discrepancy.

### A5-01 — CONCERN — `process_thread_group` is an unguarded escape hatch

**Location**: D5.1; Risks

**Claim**: Implicit — that `-100 < 0 < +100` always holds for the three nodes.

**Reality**: The global ordering guarantee (R3) is scoped to nodes in the default
process group. `process_thread_group` (`SUB_THREAD` / `MAIN_THREAD`) lets any node
opt itself and its subtree into a separately-scheduled group with an independent
priority sort. Nothing in the codebase sets it today.

**Impact**: A future author enabling multithreaded processing on `Player`,
`OxygenDrain` or `GravityAuthority` — plausibly while chasing a performance win —
would silently detach that node from the ordering contract. No compile error, no
obvious symptom, until a frame-perfect AC8 or AC13 case fails.

**Recommendation**: Register as a forbidden pattern beside
`physics_order_via_process_priority`. *(Applied 2026-08-14.)*

### A5-02 — CONCERN — Deferred dual-transition race across sibling areas

**Location**: D5.4; Key Interfaces; Constraints

**Claim**: The guarded chokepoint "covers `OxygenDrain`, `spike_hazard`'s
`inc_hazard_dmg`, and `_on_kill_area_2d_body_entered` uniformly."

**Reality**: `body_entered` for *different* `Area2D` nodes delivered in the same
`flush_queries()` batch is not ordered by `process_physics_priority` — that property
governs `_physics_process` dispatch, not signal-callback dispatch during query
flush. No deterministic inter-area delivery order could be established (see "Could
not be verified" #1).

**Impact**: If level geometry ever lets the player enter a goal trigger and a hazard
trigger within one physics tick — adjacent volumes, or a fast body crossing both in
one step — and the hazard handler runs first, `restart_level()` queues a reload
while `level_complete` is still false. The goal handler then runs `mark_complete()`
and `change_level()`, queueing a scene change. Both are pending for the same frame,
an unhandled state whose runtime behaviour is unverified. Narrow and not reachable
in the eight authored levels, but the underlying mechanism — implicit ordering
between signal handlers — is exactly the hazard this ADR exists to eliminate
everywhere else, and D5.4 claims uniform coverage without qualification.

**Recommendation**: An idempotent `_transition_pending` latch checked and set by
both `restart_level()` and the completion path, closing the gap regardless of
delivery order. Roughly the same two lines D5.4 already spends on the
`level_complete` guard. *(Applied 2026-08-14.)*

### A5-03 — CONCERN — Validation Criterion 4 is not implementable as written

**Location**: Validation Criteria, item 4

**Claim**: Assert at runtime that the three priorities are correctly ordered "and
that all three are non-zero-by-accident (explicitly assigned, not defaulted)."

**Reality**: `Player`'s assigned priority is `0` by design, which is also the engine
default for every node that never touches the property. A runtime read cannot
distinguish "explicitly assigned `0`" from "never assigned."

**Impact**: Implemented literally, the criterion either false-passes nodes that were
never wired, or special-cases `Player` as "trust me it's explicit" — which defeats
the check. It cannot detect its own failure mode for the one node whose correct
value coincides with the default.

**Recommendation**: Convert to a static grep-level check for a literal
`process_physics_priority = PRIORITY_*` assignment in each `_ready()`, matching the
pattern criterion 5 already uses. *(Applied 2026-08-14.)*

### A5-04 — CONCERN — The `plant.gd` migration is under-specified

**Location**: D5.5; Migration Plan step 6

**Claim**: "move the `water_progress` accumulation block from `_process` to
`_physics_process`. Animation and sprite work stay in `_process`."

**Reality**: In the current `plant.gd`, `water_progress += delta` is entangled in
one conditional structure with `Input.is_action_pressed("interact")` polling, the
`water_progress >= water_duration` completion check, the `_complete_watering()`
call, and the animation `speed_scale` / `play()` calls.

**Impact**: An implementer following the step literally could relocate only the `+=`
line while completion detection stays in `_process`, reading a value
`_physics_process` last wrote with no defined phase relationship between them —
reproducing the two-clocks defect (Context problem #3) that this ADR names as its
own motivation, while appearing to have fixed it.

**Recommendation**: Enumerate what moves: interact polling, accumulation, the
duration check, and the `_complete_watering()` / `_reset_watering()` calls. Only
`speed_scale` and `play()` stay in `_process`, reading state physics already wrote.
*(Applied 2026-08-14.)*

### A5-05 — CONCERN — Priority constants invert the dependency direction

**Location**: D5.1; Key Interfaces; Migration Plan step 5

**Claim**: The three nodes assign `process_physics_priority` in `_ready()` "from
the `LevelRoot` constants."

**Reality**: Safe at runtime — `const` resolution is script-load-time and
instance-independent. But `GravityAuthority` is an autoload, present before any
level scene loads, and `LevelRoot` is a per-level scene script, one of potentially
eight. The most Foundation-tier node in the project reaches into the most
scene-specific one to source its own constant.

**Impact**: Not a bug. It inverts the dependency direction
`architecture.md:317` ("no module calls upward") insists on, and weakens the
"autoloads must not depend on scene-specific state" discipline the rest of
ADR-0001 and ADR-0002 maintain.

**Recommendation**: Hoist to a const-only `FramePriority` script read by all three.
*(Applied 2026-08-14.)*

### A5-06 — NOTE — The `_process` frequency claim is true for this project specifically

**Location**: Performance Implications

`project.godot` sets no `physics/common/physics_ticks_per_second` override
(defaults to 60), no `application/run/max_fps` override, and no
`display/window/vsync/vsync_mode` override (defaults to Enabled, which syncs to
display refresh rate rather than capping at 60). On any display above 60 Hz,
`_process()` genuinely fires more often than `_physics_process()`. The claim holds
as this project is actually configured, not merely in the abstract — worth knowing
it is contingent on those settings rather than a general engine fact.

### A5-07 — NOTE — Line citations are 1–4 lines off

`goal.gd:34` is a commented-out line; the `body_entered` connect is `goal.gd:15`
and the handler `goal.gd:38-42`. `plant.gd:31` is the carry check; accumulation is
`plant.gd:34`. `restart_level()` begins at `main.gd:59`, its
`call_deferred("reload_current_scene")` at `main.gd:62`. `main.gd:16-18` is
accurate as cited. No substantive argument depends on these, but
"Verification Required: None outstanding" implies they were checked against live
code. *(Corrected 2026-08-14.)*

---

## Actions taken

All findings above were applied to the three ADRs on 2026-08-14, in the same
session as this review. Fifteen amendments across three files; no ADR status
changed — all three remain `Proposed`. Accepting them is a separate decision.

| ADR | Amendments |
|---|---|
| ADR-0001 | `_physics_process` requirement (A1-01) · `prop.sleeping = false` (A1-02) · `class_name` prohibition (A1-03) · inverted symptom reworded (A1-04) · Engine Compatibility items #1/#3 retired as resolved |
| ADR-0002 | Getter-only property rewrite of both interfaces (A2-01) · explicit `return` after `push_error()` plus the `assert()` rationale (A2-02) · consumer-lifetime invariant added to Risks (A2-03) · Engine Compatibility "None" replaced |
| ADR-0005 | F2 corollary replaced with resolved timing (R4) · new F3 for global process-group ordering and the 4.1 introduction date (R3) · `process_thread_group` forbidden pattern (A5-01) · `_transition_pending` latch (A5-02) · Validation Criterion 4 converted to a grep check (A5-03) · `plant.gd` split enumerated (A5-04) · constants hoisted to `FramePriority` (A5-05) · line citations corrected (A5-07) |

## Not covered by this review

- Traceability matrix (Phases 2–3) — the 52-requirement TR baseline remains
  unpersisted; `/architecture-review` still owns rebuilding it
- Cross-ADR conflict detection (Phase 4)
- GDD revision flags (Phase 5b) — no GDD was examined for conflicts with verified
  engine behaviour
- Architecture-doc coverage (Phase 6)
- ADR-0003, ADR-0004, ADR-0006 and the Core/Feature/Presentation tiers — unwritten

Run a full `/architecture-review` once the remaining Foundation ADRs exist.
