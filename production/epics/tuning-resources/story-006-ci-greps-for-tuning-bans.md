# Story 006: CI greps for V6, V7 and V8

> **Epic**: Tuning Resources
> **Status**: In Review
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1-1.5 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: 2026-08-24

## Context

**GDD**: `design/gdd/watering-system.md` §7 · `design/gdd/suit-oxygen.md` §7 ·
`design/gdd/physics-props.md` §7
**Requirement**: `TR-watering-013`, `TR-oxygen-011`, `TR-props-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006: Tuning resource strategy
**ADR Decision Summary**: D6.5 makes tuning resources read-only at runtime, and the
ADR is honest that this is enforced "by review and grep, **not** by structure" —
GDScript has no read-only resource. Validation Criteria V6, V7 and V8 are recorded as
**recommended, not asserted**, and are explicitly "left to the epic". This story is
that epic work. It makes D6.3, D6.5 and D6.7 structural.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: No engine API is involved. This is a CI shell step, the same
mechanism the `collision-layer-registry` epic's story 005 added for ADR-0004's D4.6
ban. Match that step's shape and placement.

**Control Manifest Rules (this layer)**:
- Forbidden: "Never assign to any property of `Tuning.WATERING` / `.OXYGEN` /
  `.PROP`, and never call `.duplicate()` on a tuning resource." — source: ADR-0006
  (`tuning_resource_runtime_mutation`)
- Forbidden: "Never write a `res://src/resources/tuning/` path literal outside
  `src/scripts/tuning/`. The path is written down exactly once, in `tuning.gd`." —
  source: ADR-0006 (`tuning_path_literal_outside_holder`)
- Forbidden: "Never create a `GravityTuning` resource, or relocate the jump constants
  off `Player`. Changing this requires superseding ADR-0001's
  `jump_constants_location`, not extending ADR-0006." — source: ADR-0006
  (`gravity_tuning_resource`)

---

## Acceptance Criteria

*From ADR-0006 Validation Criteria V6, V7 and V8:*

- [x] **V6 — path literal ban.** `.github/workflows/tests.yml` gains a step that
      greps for the literal `res://src/resources/tuning/` across the repository and
      fails the job if any match appears **outside `src/scripts/tuning/`**.
- [x] **V7 — runtime mutation ban.** The same or an adjacent step greps `src/**/*.gd`
      for an assignment to a property of `Tuning.WATERING`, `Tuning.OXYGEN` or
      `Tuning.PROP` (the shape `Tuning.PROP.<anything> =`), and for `.duplicate()`
      called on any of the three. It fails the job on a match.
- [x] **V8 — no `GravityTuning`.** A step greps the repository for `GravityTuning`
      and `gravity_tuning` (covering both `gravity_tuning.gd` and
      `gravity_tuning.tres`) and fails the job on any match.
- [x] Every step fails the CI job with a non-zero exit on a match, and prints the
      offending file and line, so the failure is self-explaining.
- [x] Each failure message names its ADR clause (D6.3, D6.5, D6.7), so a developer
      who trips it can find the reasoning without asking.
- [x] The steps run in the same CI job as the existing gdUnit4 step, so a violation
      is caught in the same run as everything else.
- [x] The steps pass on the repository as committed after Stories 002-005 land.
- [ ] Verified once on a scratch branch, one violation per check, then reverted:
      - A `res://src/resources/tuning/prop_tuning.tres` literal added to a gameplay
        script → V6 step fails
      - `Tuning.PROP.prop_gravity_scale = 1.5` added to a gameplay script → V7 step
        fails
      - `Tuning.PROP.duplicate()` added to a gameplay script → V7 step fails
      - A `src/scripts/tuning/gravity_tuning.gd` file created → V8 step fails

---

## Implementation Notes

*Derived from ADR-0006 D6.5, D6.7 and Validation Criteria V6-V8:*

- **Follow the precedent set by `collision-layer-registry` story 005.** Same file
  (`.github/workflows/tests.yml`), same shape: a `grep -rn` or `rg` invocation, one
  shell step, failing on a match. This does not need a dedicated tool or script file.
- **Scope V6 and V7 to `.gd` files under `src/`.** `.tscn` and `.tres` files may
  legitimately reference a resource path — that is authored data, which is exactly
  what D6.3 permits. A grep that catches authored data would be wrong and would be
  turned off, which is worse than not having it.
- **V6's exclusion is a directory, not a single file.** `src/scripts/tuning/` is the
  allowed location, and `tuning.gd` is the only file in it that should carry a path
  today. Exclude the directory, so the check does not need editing if the group
  grows.
- **`tests/` may legitimately name a tuning path.** Story 005's suite might reference
  one. Scope V6 to `src/` rather than the whole repo, or exclude `tests/`
  explicitly — and say which you chose in a comment on the step.
- **V7 is the weak link and the ADR says so.** A grep cannot catch every mutation
  shape: an alias (`var t := Tuning.PROP` then `t.margin = 0.5`), a `set()` call by
  string name, or a tool script that writes and saves. Catch the common literal
  shapes, and **state the limitation in a comment on the step** rather than implying
  the ban is now airtight. An overstated guard is worse than an honest partial one.
- **V8 guards a decision made twice.** ADR-0001 part 7 keeps the jump constants on
  `Player` by explicit user decision, and `gravity.md` §5's initialisation-order edge
  case stays live in the GDD as the documented price. A `GravityTuning` created under
  ADR-0006's general rule would silently overturn that and reverse a documented
  trade-off. The grep is what makes the ban visible at the moment someone tries.
- Keep the three checks separately named in the workflow, so a failure says which of
  V6, V7 or V8 tripped.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: V1-V4 and V9. Those are gdUnit4 assertions, a different mechanism for a
  different guarantee. **Do not fold these greps into the test suite**, and do not
  fold V9 into CI.
- Story 004: `tuning.gd` itself. This story only names its directory as an exclusion.
- **Closing `V-PROP-BUDGET` and removing the "BLOCKED on ADR-0006" note** from
  ADR-0003's registry entry and Ordering Note, and from
  `docs/registry/architecture.yaml`. ADR-0006 Migration Plan step 6 and ADR-0003
  Migration Plan step 8 are **the same action, to be done once**. It is owned by the
  `level-validation` epic (sprint task **LV-2**). Do not do it here.
- Any change to `docs/registry/architecture.yaml`'s forbidden-pattern entries. They
  are already recorded; this story enforces them, it does not add them.

---

## QA Test Cases

*Story type: **Logic**. **This story owns no gdUnit4 test.** The CI steps are
themselves the enforcement artifact, and there is no meaningful way to unit-test a
workflow step from inside the suite it gates. Evidence is the scratch-branch
verification below. `/story-done` should expect no `tests/unit/` path for this story.*

### Positive cases — the steps must PASS

| # | Case | Expected |
|---|---|---|
| T6.1 | Repository as committed after Stories 002-005 land | All three steps exit `0` |
| T6.2 | `src/scripts/tuning/tuning.gd` holding three `res://src/resources/tuning/` literals | V6 exits `0` — the holder directory is excluded |
| T6.3 | `.tres` and `.tscn` files referencing tuning paths as authored data | V6 exits `0` — authored data is permitted by D6.3 |
| T6.4 | `tests/unit/tuning/*` referencing a tuning path | V6 exits `0` — tests are out of the checked scope |

### Negative cases — the steps must FAIL

| # | Planted violation | Expected |
|---|---|---|
| T6.5 | `res://src/resources/tuning/prop_tuning.tres` in `src/scripts/player.gd` | V6 fails, names the file and line, cites D6.3 |
| T6.6 | `Tuning.PROP.prop_gravity_scale = 1.5` in any `src/**/*.gd` | V7 fails, cites D6.5 |
| T6.7 | `Tuning.OXYGEN.duplicate()` in any `src/**/*.gd` | V7 fails, cites D6.5 |
| T6.8 | A new `src/scripts/tuning/gravity_tuning.gd` | V8 fails, cites D6.7 and ADR-0001 part 7 |
| T6.9 | A new `src/resources/tuning/gravity_tuning.tres` | V8 fails |

### Known gaps — document, do not pretend to cover

These are **out of reach of a grep** and must be stated in a comment on the V7 step:

- An alias: `var t := Tuning.PROP` followed by `t.margin = 0.5`
- A dynamic write: `Tuning.PROP.set("margin", 0.5)`
- An editor `@tool` script that mutates and saves a `.tres`, silently editing the
  authored source of truth in version control

The ADR already records D6.5 as enforced by review and grep, not by structure. This
story narrows the gap; it does not close it. **Say so in the workflow comment**, so a
later reader does not assume more protection than exists.

### Edge cases

- **False positives on comments and doc strings.** The word `GravityTuning` appears
  in `docs/architecture/adr-0006-tuning-resource-strategy.md`, in the control
  manifest, in `docs/registry/architecture.yaml`, and in this story file. Scope V8 to
  `src/` and to file names, or the check fails on the documentation that defines it.
  **Verify this before committing** — a check that fails on day one gets disabled.
- **`rg` availability in CI.** If the runner has no `rg`, use `grep -rn`. Match
  whatever the existing collision-layer step used, so the workflow stays consistent.
- **`grep` exits `1` when it finds nothing**, which a shell step reads as failure.
  Invert the condition deliberately, and test both directions — a step that always
  passes is the most likely defect here.

### Manual verification — REQUIRED, blocking

Verify each planted violation on a scratch branch, confirm the CI failure, then
revert. Record all five results in the story's completion notes:

- [x] T6.5 — V6 fails on a path literal outside `src/scripts/tuning/`
- [x] T6.6 — V7 fails on a property assignment
- [x] T6.7 — V7 fails on `.duplicate()`
- [x] T6.8 — V8 fails on a `GravityTuning` script
- [x] T6.1 — all three steps pass on the clean tree

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- The CI steps in `.github/workflows/tests.yml` are the artifact
- Scratch-branch verification results recorded in the story's completion notes (a
  one-time manual verification, not a committed artifact)

**Status**: [x] CI steps landed and verified locally. [ ] Not yet verified by a
real CI run — see Implementation Record.

---

## Dependencies

- Depends on: Story 004 (hard — the V6 exclusion directory and the `Tuning.*` symbol
  must exist, or the checks guard nothing)
- Unlocks: None

---

## Implementation Record

*Written 2026-08-24.*

### What changed

`.github/workflows/tests.yml` gains three steps, named for the criterion each
one carries:

- **Enforce the ADR-0006 D6.3 tuning path-literal ban (V6)**
- **Enforce the ADR-0006 D6.5 tuning runtime-mutation ban (V7)**
- **Enforce the ADR-0006 D6.7 GravityTuning ban (V8)**

All three sit after the ADR-0004 D4.6 step and before the GdUnit4 step, in the
same job. A violation is caught in the same run as everything else. They are
kept separate, so a failure names which of V6, V7 or V8 tripped.

### Decisions the next author needs

- **Exit-code inversion handled explicitly, three times.** `grep` returns `1`
  when it finds *nothing*. Each step captures the matches into a variable and
  sets the exit code with an `if`. A bare `grep` in a CI step passes forever
  while looking correct. This is the same shape as the D4.6 step.
- **V6 excludes the `src/scripts/tuning/` DIRECTORY, not `tuning.gd`.** The
  check then needs no edit if the holder group grows.
- **V6 is scoped to `src/`, and `tests/` is therefore out of scope by
  construction rather than by an explicit exclusion.** The step comment says
  so. `.tres` and `.tscn` files are excluded by `--include='*.gd'`, because a
  path in authored data is exactly what D6.3 permits.
- **V7 is partial, and the step comment says so.** An alias
  (`var t := Tuning.PROP`), a dynamic `set("margin", 0.5)`, and a `@tool`
  script that saves a mutated `.tres` all pass this grep. The ADR already
  records D6.5 as enforced by review and grep, not by structure. A pass on
  this step is not proof that no mutation exists.
- **V7 does not fire on a comparison.** The pattern requires the `=` to follow
  the identifier and optional whitespace, with an optional compound-assign
  operator, and rejects a following `=`. So `!=`, `>=`, `<=` and `==` are not
  matched, while `=`, `+=`, `-=`, `*=`, `/=` and `%=` are.
- **V8 needs two checks, not one.** A `gravity_tuning.tres` can exist with no
  occurrence of the token in its body. The content grep misses it; the
  `find -iname` half catches it. T6.9 below is the case that proves this.
- **V8 is scoped to `src/`.** The token `GravityTuning` appears legitimately in
  `docs/architecture/`, in the control manifest, in
  `docs/registry/architecture.yaml` and in this story file. A repository-wide
  grep would fail on the documentation that states the ban.

### Verification performed (locally, not in CI)

The three `run:` bodies were extracted from the committed
`.github/workflows/tests.yml` with a YAML parse and executed directly, so the
shell under test is the workflow's own text and not a hand-copy.

| # | Case | Result |
|---|---|---|
| T6.1 | Clean tree, all three steps | all exit `0` |
| T6.2 | `tuning.gd` holding three tuning path literals | V6 exits `0`. Load-bearing: unfiltered, that file produces 3 hits |
| T6.3 | `.tres` files naming tuning paths | not matched by `--include='*.gd'` |
| T6.5 | A tuning path literal in a gameplay script | V6 fails, names file and line, cites D6.3 |
| T6.6 | `Tuning.PROP.prop_gravity_scale = 1.5` | V7 fails, cites D6.5 |
| T6.7 | `Tuning.OXYGEN.duplicate()` | V7 fails, cites D6.5 |
| T6.8 | A new `src/scripts/tuning/gravity_tuning.gd` | V8 fails. Caught by **both** halves |
| T6.9 | A new `gravity_tuning.tres`, token absent from its body | V8 fails. Caught by the **file-name half only** |
| — | Near miss: `Tuning.PROP.x != 1.0` and `Tuning.OXYGEN.drain >= 2.0` | correctly NOT matched by V7 |

Every planted file was deleted immediately after its run. `git status` confirms
`.github/workflows/tests.yml` is the only modified file.

### Open — blocks Complete

**Two items, both recorded rather than fixed.**

1. **The scratch-branch CI run did not happen.** The last acceptance criterion
   and the Manual Verification block both ask for a CI failure to be observed.
   What was done is a local execution of the workflow's own shell. The grep
   logic is proven. The behaviour of the steps inside GitHub Actions is not.
   This cannot be closed from here: the workflow triggers on `main`, this
   repository's main branch is `development`, and **no CI run has ever fired on
   this sprint's work**. Widening the trigger was ruled out of scope by the
   developer. That decision is live, not closed. This item and CLR-005's
   identical one close together or not at all.

2. **T6.4 is vacuous today.** No file under `tests/` names a tuning path, so
   the "tests are out of the checked scope" case has no live instance to
   exercise. The scoping decision still holds and is stated in the V6 step
   comment. It is untested because there is nothing to test it against, not
   because it was skipped.
