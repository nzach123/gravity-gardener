# Story 006: V-PROP-BUDGET and V-BOUNDS

> **Epic**: Level Load Validation
> **Status**: Blocked
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

> **BLOCKED** on two prerequisites, both scheduling rather than design — every
> governing ADR is Accepted:
>
> 1. **`V-PROP-BUDGET` needs `Tuning.PROP.props_per_level_budget`**, delivered by the
>    `tuning-resources` epic (ADR-0006). This is ADR-0003's stated Ordering Note, and
>    ADR-0003 Migration Plan step 8 and ADR-0006 Migration Plan step 6 are the same
>    action seen from two sides — **do the closure once, not twice.**
> 2. **Both rules need `class_name PropBody`**, created under ADR-0011. No `PropBody`
>    exists in `src/scripts/` and no epic covers physics props yet — `index.md` files
>    it under *Not yet epic'd*, Presentation run, content deferred to Vertical-Slice
>    tier by `art-bible.md` §1.3.
>
> The `V_PROP_BUDGET` and `V_BOUNDS` constants are already in place from story 001,
> which is what the epic's Definition of Done means by "specified with its constant
> in place".

## Context

**GDD**: `design/gdd/physics-props.md`
**Requirement**: `TR-props-007` (`V-PROP-BUDGET`). `V-BOUNDS` has no TR-ID of its
own — it closes the D11.3 hole and supports `TR-props-005` (R7/AC9, out-of-bounds
freeing). Recorded as a traceability gap; do not back-fill a TR-ID during
implementation.
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: ADR-0003 (primary — specifies `V-PROP-BUDGET`, owns the rule
table) · ADR-0011 (secondary — adds `V-BOUNDS` in D11.7 and unblocks
`V-PROP-BUDGET`) · ADR-0006 (secondary — owns `PropTuning`)

**ADR Decision Summary**: `V-PROP-BUDGET` flags a level whose `PropBody` count
exceeds `Tuning.PROP.props_per_level_budget` — `physics-props.md` §5 classifies an
over-budget count as an authoring error caught at load. `V-BOUNDS` requires
`level_bounds` to resolve to a live `Area2D` **and** every `PropBody` to start inside
its extent. `V-BOUNDS` exists to close a named hole in D11.3: a prop authored
*outside* the bounds rect never enters the area, so it never exits it, so it is never
freed. Runtime is too late for that; load is the right gate for an authoring error.

**Engine**: Godot 4.7.1 | **Risk**: MEDIUM
**Engine Notes**: Higher than the sibling stories because this is the one rule pair
that touches post-4.3 physics surface, which `VERSION.md` rates HIGH.

- **E1** still applies — `@export` values and node transforms are populated by
  `PackedScene.instantiate()` without a `SceneTree`, so both rules stay CI-testable.
- **Unverified for this story**: reading an `Area2D`'s extent from a
  `CollisionShape2D` on a node that was instantiated but never added to a tree.
  Shape resources are `@export`-adjacent sub-resources and should be populated by E1's
  mechanism, but this specific read has **not** been verified and is not covered by
  E1-E3. Verify it against the 4.7.1 binary before relying on it, and if it does not
  hold headlessly, say so as a finding rather than working around it.
- **F10** — one GDScript warning fails the whole gdUnit4 suite at discovery.

**Control Manifest Rules (this layer)**:

- Required: "Six validation rules (extended to seven by ADR-0011): `V-BUCKET-SUM`,
  `V-PLANT-MIN`, `V-OXY-CAP`, `V-GRAV-EXPORT`, `V-PROP-BUDGET`, `V-WIRING`,
  `V-BOUNDS`." — source: ADR-0003 (D3.3), ADR-0011 (D11.7)
- Required: "Consumers reach tuning ONLY through `class_name Tuning`
  (`Tuning.WATERING` / `.OXYGEN` / `.PROP`); no consumer names a `.tres` path itself."
  — source: ADR-0006 (D6.3)
- Required: "`class_name` is required on `Plant`, `Bucket`, `PropBody` — the type scan
  depends on it." — source: ADR-0003
- Forbidden: "Never assign to any property of `Tuning.WATERING` / `.OXYGEN` / `.PROP`,
  and never call `.duplicate()` on a tuning resource."
  — source: ADR-0006 (`tuning_resource_runtime_mutation`)
- Forbidden: "Never write a `res://src/resources/tuning/` path literal outside
  `src/scripts/tuning/`." — source: ADR-0006 (`tuning_path_literal_outside_holder`)
- Forbidden: "`LevelValidation.validate()` must never return on the first breach."
  — source: ADR-0003 (`validation_first_failure_return`)

---

## Acceptance Criteria

*From ADR-0003 D3.3, ADR-0011 D11.7 and V8, and `physics-props.md` R7/R8/§5, scoped
to this story:*

- [ ] The recursive scan from story 001 gains a `PropBody` match, and a
      `count_props(level)` read consistent with `count_buckets()` — one definition of
      "a prop in this level".
- [ ] `V-PROP-BUDGET` fires when the `PropBody` count exceeds
      `Tuning.PROP.props_per_level_budget`, naming both the count and the budget.
- [ ] `V-PROP-BUDGET` reads the budget through `Tuning.PROP` only. No `.tres` path
      literal appears in `level_validation.gd`.
- [ ] `V-BOUNDS` fires when `level_bounds` is unset or does not resolve to a live
      `Area2D`.
- [ ] `V-BOUNDS` fires **once per offending prop** when a `PropBody` starts outside
      the `level_bounds` extent, naming the prop.
- [ ] Exactly at budget is **valid** — the rule is `count <= budget`, not `<`.
- [ ] A prop exactly on the bounds edge is treated consistently — pick inclusive or
      exclusive, document it in the code, and assert it in the test.
- [ ] `V-BOUNDS` and `V-WIRING` do not double-report an unset `level_bounds`. Decide
      which owns it — recommended that `V-WIRING` reports the unset export and
      `V-BOUNDS` skips its per-prop pass when the export does not resolve, since a
      per-prop extent check against nothing has no meaning. Assert the chosen
      behaviour.
- [ ] The combined report-all-failures test from story 004 (AC-6) is extended to
      seven codes.
- [ ] **ADR-0003 Migration Plan step 8 is closed here** and ADR-0006 Migration Plan
      step 6 is marked as the same action — closed once, not twice.
- [ ] `level_validation.gd` and the test file are warning-clean under the headless
      gdUnit4 run.

---

## Implementation Notes

*Derived from ADR-0003 D3.3 and ADR-0011 D11.3/D11.7:*

**`V-BOUNDS` closes a hole that is named rather than hidden.** ADR-0011 D11.3 frees a
prop when it exits `level_bounds`. A prop authored *outside* the rect never enters the
area, so `body_exited` never fires and it is never freed. That is an authoring error,
and `physics-props.md` §5 already classifies over-budget prop counts the same way — as
something caught at load, not at runtime.

**The mirror failure is out of scope and is not caught by any test.** ADR-0011 records
that `level_bounds` authored *too tight* frees props still in play. Props are
cosmetic, so the failure is visible rather than dangerous — furniture disappears where
the player can see it — and ADR-0011 assigns it to AC11's visual sign-off, not to a
test. Do not attempt a "bounds is large enough" heuristic here.

**Budget failure is advisory in character, not fatal.** Exceeding the budget produces a
finding and the level still starts, like every other rule (D3.6). The performance risk
the budget guards against — 40 bodies waking in one substep spiking the frame past
16.6 ms — is measured separately by ADR-0011 V7, and its levers are
`props_per_level_budget` and per-prop `can_sleep`, not a change to this rule.

**`props_per_level_budget` defaults to 40, range 10-80** (ADR-0011 Risks, ADR-0006).
Do not hardcode 40. Read it through `Tuning.PROP` so a designer retuning the budget
retunes the gate with it.

**On the extent read.** Prefer reading the `Area2D`'s collision shape extent over
assuming a rect. If the headless read proves unreliable (see Engine Notes), report it
as a finding against this story rather than substituting a hardcoded rect or gating
the rule behind `OS.is_debug_build()` — the manifest forbids the latter outright.

---

## Out of Scope

*Handled by neighbouring stories or other epics — do not implement here:*

- **Stories 001-005**: the scaffold, the five live rules, the `LevelRoot` call site.
- **The `tuning-resources` epic (ADR-0006)**: creating `PropTuning`, the `Tuning`
  holder, and the `.tres` files. This story consumes them.
- **The physics-props epic (ADR-0011)**: creating `PropBody`, the `LevelBounds`
  `Area2D`, the `body_exited` free path, the speed cap, the gravity registry. This
  story validates authored prop data and nothing else.
- **The level migration epic**: adding `LevelBounds` to all 8 level scenes and wiring
  `LevelRoot.level_bounds` (ADR-0011 Migration step 4).
- **The runtime out-of-bounds free path**: ADR-0011 V5's integration test. This story
  is the load-time gate only.
- **A "bounds too tight" check**: assigned to AC11 visual sign-off by ADR-0011.

---

## QA Test Cases

*Derived from ADR-0011 V8 and ADR-0003 Validation Criterion 1. The developer
implements against these — do not invent new test cases during implementation.*

**Test file**: `tests/unit/level/level_validation_prop_rules_test.gd`

- **AC-1**: `V-PROP-BUDGET` fires above budget
  - Given: a synthetic level holding `Tuning.PROP.props_per_level_budget + 1`
    `PropBody` nodes
  - When: `validate(level)` is called
  - Then: one `[V-PROP-BUDGET]` finding is returned, naming both the count and the
    budget
  - Edge cases: **exactly at budget must not fire** — this is the boundary and the
    exact number is the point; zero props must not fire

- **AC-2**: `V-PROP-BUDGET` reads the live budget, not a hardcoded number
  - Setup: from the repository root
  - Verify: `grep -n "res://src/resources/tuning" src/scripts/level_validation.gd`
    and a scan for a literal `40`
  - Pass condition: no output for either

- **AC-3**: `V-BOUNDS` fires on an unset or unresolvable `level_bounds`
  - Given: a synthetic level with props and no `level_bounds`
  - When: `validate(level)` is called
  - Then: the behaviour chosen in the acceptance criteria holds — `V-WIRING` names the
    unset export and `V-BOUNDS` does not additionally per-prop report
  - Edge cases: `level_bounds` wired to a freed node; `level_bounds` wired to a node
    that is not an `Area2D`

- **AC-4**: `V-BOUNDS` fires once per prop starting outside the extent (ADR-0011 V8)
  - Given: a synthetic level with a `level_bounds` `Area2D` and three props — two
    inside, one well outside
  - When: `validate(level)` is called
  - Then: exactly one `[V-BOUNDS]` finding is returned, naming the outside prop
  - Edge cases: two props outside produce two findings; a prop **exactly on the edge**
    matches the documented inclusive-or-exclusive choice

- **AC-5**: `V-BOUNDS` stays silent on a clean level
  - Given: a synthetic level with a resolving `level_bounds` and every prop inside it
  - When: `validate(level)` is called
  - Then: no finding starts with `[V-BOUNDS]`
  - Edge cases: a level with bounds and zero props must not fire

- **AC-6**: all seven codes report in one pass (ADR-0003 Validation Criterion 1, in
  full for the first time)
  - Given: a synthetic level breaching every one of the seven rules
  - When: `validate(level)` is called
  - Then: the result contains at least one finding for **each** of the seven codes —
    not one, and not a partial set
  - Edge cases: extend story 004's AC-6 rather than writing a second combined test

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/level/level_validation_prop_rules_test.gd` — must
exist and pass. AC-6 is the completed form of ADR-0003 Validation Criterion 1.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: **Stories 001 and 004** must be DONE (the scan and the combined test),
  **and the `tuning-resources` epic must have landed `Tuning.PROP`**, **and
  `class_name PropBody` must exist** under ADR-0011. The last two are what make this
  story Blocked today.
- Unlocks: Closes `TR-props-007`, ADR-0003 Migration Plan step 8, ADR-0006 Migration
  Plan step 6, and this epic's Definition of Done.
