# Story 003: `FramePriority` — the const-only physics ordering contract

> **Epic**: Level State Ownership
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

> **Scope note — read this first.** This story is **not** named in the epic's
> Architecture Module line (`LevelState` · `OxygenState` · `GameManager` ·
> `LevelRoot`). It was added during the 2026-08-24 decomposition, deliberately and
> with the reason recorded here. `FramePriority` blocks three epics —
> `gravity-authority` (`-100`), `player-core` (`0`) and `oxygen-drain` (`+100`) —
> and belongs to none of them. ADR-0005 A5-05 forbids the placement that would have
> made it a member of one: the constants cannot live on `LevelRoot`, because
> `GravityAuthority` is an autoload present before any level scene loads and cannot
> source a constant from a per-level script. Placing it in the earliest Foundation
> epic in the build order is the only placement that blocks nobody. If Sprint 2
> planning decides otherwise, moving this file to another epic directory is a
> rename.

**GDD**: None. This is an ADR-delegated mechanism, not a GDD requirement.
**Requirement**: **No TR-ID, by design.** `tr-registry.yaml`'s SCOPE rule admits
GDD-derived requirements only. This is the same recorded exception that applies to
`V-WIRING` — see `production/epics/index.md`, risks table, closed 2026-08-24. Do
not invent a TR ID for it.

**ADR Governing Implementation**: ADR-0005: Frame ordering and the
`level_complete` guard (D5.1, F1, F3, A5-05)

**ADR Decision Summary**: The frame contract is expressed with
`process_physics_priority`, assigned **in code** from a const-only script, never
per-scene in the inspector. Eight level scenes would be eight chances to drift.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: Verified against engine source on 2026-08-14, not recalled:

- **F1 — `process_physics_priority` orders `_physics_process`;
  `process_priority` orders `_process`.** They are separate properties. Using the
  wrong one produces no compile error and no runtime error — it simply orders
  nothing. `architecture.md`'s Frame update path named `process_priority` and was
  wrong; this ADR is the correction.
- **F3 — the ordering is a single global sort, not per-parent.** All nodes in the
  default process group sort by one global priority comparator with scene-tree
  position as the tiebreak. Had it been scoped per-parent, the priority table would
  have ordered nothing, since the three nodes do not share a parent.
- `Node.process_physics_priority` was introduced in **4.1** — absent in 4.0-stable,
  present in 4.1-stable. It predates the training cutoff and is safe to use.
- **`process_thread_group` must stay at its default** on `GravityAuthority`,
  `Player` and `OxygenDrain`. Changing it silently detaches the node from this
  ordering contract with no compile error.

**Control Manifest Rules (this layer)**:
- Required: "`process_physics_priority` (never `process_priority`) is assigned in
  code from a `FramePriority` const-only script: `-100 GravityAuthority`,
  `0 Player (+components inline)`, `+100 OxygenDrain`. Never per-scene in the
  inspector." — ADR-0005 (D5.1, F1)
- Required: "`FramePriority` constants live on their own const-only script, **NOT**
  on `LevelRoot`" — `GravityAuthority` is an autoload present before any level
  scene loads. — ADR-0005 (A5-05)
- Forbidden: "Never use `process_priority` to order `_physics_process`
  callbacks." — ADR-0005 (`physics_order_via_process_priority`)
- Forbidden: "Never set `process_thread_group` away from default on
  `GravityAuthority`, `Player`, or `OxygenDrain`." — ADR-0005
  (`process_thread_group_split_in_frame_chain`)

---

## Acceptance Criteria

*From ADR-0005 D5.1 and A5-05 — this story has no GDD acceptance criteria:*

- [ ] A const-only script declares the three priorities: `-100` for
      `GravityAuthority`, `0` for `Player`, `+100` for `OxygenDrain`
- [ ] The script holds constants and nothing else — no methods, no variables, no
      signals, no `_ready`, and it is not an autoload
- [ ] The constants are reachable from an autoload that exists before any level
      scene loads, and from a level-scene node, by the same mechanism
- [ ] No `.tscn` file sets `process_physics_priority` in the inspector
- [ ] No script in `src/` uses `process_priority` to order a `_physics_process`
      callback

---

## Implementation Notes

*Derived from ADR-0005 D5.1 and A5-05:*

- **Follow the shape of `src/scripts/tuning/tuning.gd`.** It is the project's
  existing const-only holder: a `class_name`, constants, no autoload registration,
  and a doc comment that says why it must never become one. That file solved the
  same reach problem — universal availability without a `SceneTree` dependency —
  and the reasoning transfers directly.
- **Assignment happens in each node's own `_ready()`**, not centrally. Each of the
  three nodes sets its own `process_physics_priority` from the constant. Landing
  those three assignments belongs to `gravity-authority`, `player-core` and
  `oxygen-drain` respectively. **This story lands the constants and the tests, not
  the three call sites** — none of the three nodes exists in its ADR-final form
  yet.
- **Name the constants for their roles, not their values.** A later reader must be
  able to see that the numbers encode an ordering, not a magic tuning value.
- The priority values are a contract between three nodes that do not share a
  parent, which is safe only because of F3. Carry that in a comment citing F3, in
  the same spirit as the ADR-0003 first-failure comment — the fact is
  counter-intuitive and a reader who assumes per-parent scoping will conclude the
  contract is broken.

---

## Out of Scope

*Handled by neighbouring epics — do not implement here:*

- **Assigning the priority on `GravityAuthority`** — `gravity-authority` epic.
- **Assigning it on `Player`** — `player-core` epic.
- **Assigning it on `OxygenDrain`** — `oxygen-drain` epic, under ADR-0008.
- **The arm-and-defer death evaluation** (D5.2) and the completion freeze (D5.6).
  Those are behaviours ordered *by* this contract, not part of it.
- **Moving `plant.gd`'s `water_progress` from `_process` to `_physics_process`**
  (D5.5) — Feature watering epic.

---

## QA Test Cases

*Story type: **Logic** — automated test specs. The last two are structural greps
rather than behavioural assertions, and that is deliberate: the failure mode this
story guards is a value drifting in an inspector, which no behavioural test sees.*

- **AC-1 — the three constants hold their specified values**
  - Given: the `FramePriority` script
  - When: each constant is read
  - Then: gravity is `-100`, player is `0`, oxygen drain is `+100`
  - Edge cases: assert the *relative order* as well as the absolute values, so the
    test states the actual requirement and not just three numbers.

- **AC-2 — the constants are reachable without a `SceneTree`**
  - Given: no scene tree, the null-tree path `LevelValidation` already uses
  - When: the constants are read
  - Then: the read succeeds
  - Edge cases: this is what A5-05 requires and what a `LevelRoot`-hosted constant
    could not deliver. The test is the proof of the placement decision.

- **AC-3 — the script is const-only**
  - Given: the script
  - When: its members are inspected
  - Then: it declares no variables, methods or signals
  - Edge cases: a `static func` helper is the likely later addition. Decide now
    whether it is permitted and assert accordingly.

- **AC-4 — no scene sets the priority in the inspector**
  - Given: the repository
  - When: `.tscn` files are searched for `process_physics_priority`
  - Then: no match
  - Edge cases: this duplicates no existing CI step. If it proves valuable, the
    natural home is a CI grep in the shape of the ADR-0004 D4.6 and ADR-0006
    V6/V7/V8 steps already in `.github/workflows/tests.yml` — **but adding that
    step is not this story's scope.** Note the finding and stop.

- **AC-5 — no script orders `_physics_process` with `process_priority`**
  - Given: `src/**/*.gd`
  - When: searched for `process_priority` assignments
  - Then: any match is on a node that genuinely orders `_process`, and is not one
    of the three chain nodes
  - Edge cases: `process_physics_priority` contains `process_priority` as a
    substring. A naive search reports every correct assignment as a violation.

---

### QA-plan addendum — 2026-08-25

*Added by `/qa-plan sprint` (`production/qa/qa-plan-sprint-2.md`). The cases
above are unchanged and remain authoritative; this block records only what the
sprint QA plan adds on top of them.*

- **Order-dependent tests are exactly the ones that pass for the wrong reason.**
  Add one case that **deliberately mis-orders** the three priorities in a local
  fixture and confirms the assertion goes red. A test that would still be green
  with all three constants set to the same value is not testing anything, and
  this story's entire subject is an ordering.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/level_state/frame_priority_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None.
- Unlocks: `gravity-authority`, `player-core` and `oxygen-drain` can each state
  their priority contract. None of the three is blocked from *starting* by this
  story, but all three need it before their ordering can be asserted.
