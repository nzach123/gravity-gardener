# Story 004: V-WIRING over a required-consumer table

> **Epic**: Level Load Validation
> **Status**: In Review
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: 2026-08-24

## Context

**GDD**: `design/gdd/watering-system.md` · `design/gdd/suit-oxygen.md`
**Requirement**: `ADR: delegated` — `V-WIRING` is the check ADR-0002 asked ADR-0003
for by name. **No TR-ID covers it.** Recorded here as a traceability gap rather than
invented: `tr-registry.yaml` has no entry for "required consumer exports resolve at
load". Raise it with `/architecture-review` or add a `TR-level-*` entry; do not
back-fill a TR-ID during implementation.

**Governing ADRs**: ADR-0003 (primary, D3.3) · ADR-0002 (secondary — requested the
check, owns `player` and `goal`) · ADR-0010 (secondary — owns `hud`) · ADR-0011
(secondary — owns `level_bounds`)

**ADR Decision Summary**: `V-WIRING` checks *wiring*, not *binding*. Under D3.1,
validation runs at step (a) and `bind()` at step (c), so binding has not happened yet
and cannot be observed. What `validate()` can observe is that every **required**
consumer export on `LevelRoot` is non-empty and resolves to a live node — the
condition under which step (c) will succeed. A consumer that is wired but whose
`bind()` call was never written is caught separately by ADR-0002's per-consumer
guard at first use. The two checks are complementary and neither subsumes the other.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**:

- **E2** (verified 2026-08-14, **do not re-search**) — `@export`ed node references
  resolve at instantiation, not at tree entry. The
  `node_paths=PackedStringArray("player", "goal", "bucket")` mechanism at
  `level_01.tscn:21` is collected into a `deferred_node_paths` list and resolved with
  `base->get_node_or_null(path)` *inside* `instantiate()`. `get_node_or_null()` is
  local parent/child traversal and does not require `SceneTree` membership. This is
  what makes `V-WIRING` CI-testable alongside the other rules.
- **E2 boundary condition** — resolution is skipped in favour of storing the raw
  `NodePath` when `get_scene_instance_load_placeholder()` is set outside the editor.
  No scene in this project uses instance load placeholders. If one ever does,
  `V-WIRING` degrades **silently** on that scene and needs an explicit
  unresolved-path branch.
- **F10** — one GDScript warning fails the whole gdUnit4 suite at discovery.

**Control Manifest Rules (this layer)**:

- Required: "Every injected consumer must guard 'not bound' with `push_error()` and
  refuse to operate before `bind()` is called." — source: ADR-0002. `V-WIRING` is the
  earlier, complementary half of this.
- Required: "Six validation rules (extended to seven by ADR-0011) ... Any future ADR
  that adds a `LevelRoot` consumer export or an authoring invariant adds a row to
  this table in the same changeset." — source: ADR-0003 (D3.3), ADR-0011 (D11.7)
- Required: "`validate()` returns a `PackedStringArray` of coded findings."
  — source: ADR-0003 (D3.4)
- Forbidden: "`LevelValidation.validate()` must never return on the first breach."
  — source: ADR-0003 (`validation_first_failure_return`)

---

## Acceptance Criteria

*From ADR-0003 D3.3, ADR-0010 D10.9 and V10, ADR-0011 D11.7, and ADR-0003 Validation
Criterion 1, scoped to this story:*

- [x] The required-consumer set is expressed as a **single constant table** in
      `level_validation.gd` — one entry per export name — not as one hand-written
      branch per consumer. Adding a consumer must be a one-line table edit.
- [x] The table holds four rows, each required because its owning ADR is Accepted:
      `player` (ADR-0002), `goal` (ADR-0002), `hud` (ADR-0010), `level_bounds`
      (ADR-0011). See Implementation Notes for the ADR-lag flag on the last two.
- [x] `V-WIRING` fires when a required export is empty, unset, or `null`.
- [x] `V-WIRING` fires when a required export does not resolve to a live node.
- [x] `V-WIRING` fires **once per unwired consumer**, and each finding names the
      export so an author can find it.
- [x] `V-WIRING` does **not** check `OxygenDrain` — ADR-0002 part 4 makes it a *child*
      of `LevelRoot`, not a `NodePath` export, so there is no path to resolve. Its
      binding failure mode is covered by ADR-0002's per-consumer guard.
- [x] The table carries an inline comment stating D3.3's admission rule — a consumer
      becomes required when its owning ADR is Accepted — so the next author adds a row
      rather than asking.
- [x] **The combined report-all-failures test** (ADR-0003 Validation Criterion 1): a
      synthetic level breaching every rule implemented so far returns one finding per
      code, not one and not a partial set. Scope this to the five rules live after
      stories 002-004; stories 006's two rules join it when they land.
- [x] `level_validation.gd` and the test file are warning-clean under the headless
      gdUnit4 run.

---

## Implementation Notes

*Derived from ADR-0003 D3.3, ADR-0010 D10.9, ADR-0011 D11.7:*

**On the ADR lag — read this before implementing, and do not treat it as a
contradiction.** ADR-0003 D3.3's printed table still lists `hud` as *"No — admitted
when ADR-0010 is Accepted"* and has no `level_bounds` row at all. Both ADRs are now
**Accepted**, and D3.3's own stated admission rule is *"a consumer is required when
the ADR that introduces it is Accepted"*. ADR-0010 D10.9 says so explicitly ("no new
validation code is needed; the rule already exists and this ADR only moves a row"),
and ADR-0011 D11.7 says `level_bounds` "joins the `V-WIRING` required-consumer table
as Required, effective when this ADR is Accepted". ADR-0011's Related Decisions
section already records that ADR-0003 owes the row.

So the four-row table is what the accepted decisions require; ADR-0003's printed
table is stale prose that has not caught up. **Implement four rows.** Do not reopen
or amend ADR-0003 as part of this story — flag the doc lag at `/story-done` so a
doc-only amendment is scheduled separately.

**Why the scoping rule matters rather than being bookkeeping.** An unqualified "every
required consumer" reading would make ADR-0003's own close condition unreachable —
Migration Plan step 6 and Validation Criterion 5 both require every level to return
empty from `validate()`, and for a long time no step in that plan authored a HUD. The
admission rule is what keeps the gate honest instead of quietly weakened during
implementation, which is how a validation rule becomes decoration.

**What this costs the level migration epic, stated so it is not a surprise.** All 8
levels must now author and wire both a HUD (ADR-0010 §Consequences) and a
`LevelBounds` `Area2D` (ADR-0011 Migration step 4). ADR-0010 names these two as the
epic's largest cost. That cost is real and lands there, not here.

**None of the four exports exists on `main.gd` today** — it declares `player`, `goal`,
`bucket`, `next_level` and two camera flags. `player` and `goal` are live; `hud` and
`level_bounds` arrive with their own epics. Read every export through `level.get()`
and treat an absent property the same as an empty one — both mean the level is not
wired. This keeps the rule table-driven and lets rows be added before the export
exists.

**Resolution, not binding.** Check that the value is a live `Node` — non-`null` and
not a freed instance (`is_instance_valid()`). Do not call any method on it, do not
check its type beyond what the table declares, and do not attempt to observe whether
`bind()` has run. That is ADR-0002's guard, at a later moment, by a different
mechanism.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Stories 001-003**: the scaffold and the first four rules. This story consumes
  them and adds the combined test over all of them.
- **Story 005**: the `LevelRoot._ready()` call site and the `push_error` loop.
- **Story 006**: `V-PROP-BUDGET` and `V-BOUNDS`. Note that `V-BOUNDS` is a *separate
  rule* from `V-WIRING`'s `level_bounds` row: this story checks the export resolves;
  story 006 checks every prop starts inside its extent.
- **ADR-0003 D3.3's table amendment**: a doc-only change, flagged at `/story-done`,
  not made here.
- **The `level-state`, HUD and physics-props epics**: authoring the `hud` and
  `level_bounds` exports on `LevelRoot`. This story validates them, it does not add
  them.

---

## QA Test Cases

*Derived from ADR-0010 V10, ADR-0011 V8 (the wiring half) and ADR-0003 Validation
Criterion 1. The developer implements against these — do not invent new test cases
during implementation.*

**Test file**: `tests/unit/level/level_validation_wiring_test.gd`

- **AC-1**: `V-WIRING` fires on an empty required export
  - Given: a synthetic level root wiring `goal`, `hud` and `level_bounds` but leaving
    `player` unset
  - When: `validate(level)` is called
  - Then: exactly one `[V-WIRING]` finding is returned, and it names `player`
  - Edge cases: repeat for each of the four rows — a table-driven test over the four
    export names is preferable to four near-identical cases

- **AC-2**: `V-WIRING` fires once per unwired consumer
  - Given: a synthetic level root with all four required exports unset
  - When: `validate(level)` is called
  - Then: four `[V-WIRING]` findings are returned, one naming each export
  - Edge cases: this is the no-early-return guard for this rule specifically

- **AC-3**: `V-WIRING` fires on an export that no longer resolves
  - Given: a synthetic level root whose `goal` was wired and then freed
  - When: `validate(level)` is called
  - Then: a `[V-WIRING]` finding naming `goal` is returned
  - Edge cases: must not raise on the freed instance — `is_instance_valid()` is the
    guard

- **AC-4**: `V-WIRING` fires when the export property is absent entirely
  - Given: a synthetic level root that declares no `hud` property at all
  - When: `validate(level)` is called
  - Then: a `[V-WIRING]` finding naming `hud` is returned
  - Edge cases: this is the case that lets a table row precede its export

- **AC-5**: `V-WIRING` stays silent on a fully wired level
  - Given: a synthetic level root with all four exports wired to live nodes
  - When: `validate(level)` is called
  - Then: no finding starts with `[V-WIRING]`
  - Edge cases: an `OxygenDrain` child present but never wired as an export must
    **not** produce a finding — it is out of this rule's scope by design

- **AC-6**: report-all-failures across every live rule (ADR-0003 Validation
  Criterion 1)
  - Given: a synthetic level breaching `V-BUCKET-SUM`, `V-PLANT-MIN`, `V-OXY-CAP`,
    `V-GRAV-EXPORT` and `V-WIRING` simultaneously
  - When: `validate(level)` is called
  - Then: the result contains at least one finding for **each** of the five codes
  - Edge cases: assert per-code presence rather than an exact total count, so the
    test survives story 006 adding two more codes and survives `V-PLANT-MIN` and
    `V-WIRING` returning several findings each

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/level/level_validation_wiring_test.gd` — must
exist and pass. AC-6 is the direct test of ADR-0003 Validation Criterion 1, the
report-all-failures guarantee.

**Status**: [x] `tests/unit/level/level_validation_wiring_test.gd` exists and passes. Verified
2026-08-25 in a full headless gdUnit4 run: 178 cases, 0 errors, 0 failures, 0 flaky,
0 skipped, 0 orphans, exit 0. This file contributes 13 cases.

---

## Dependencies

- Depends on: **Stories 001, 002 and 003** must all be DONE — AC-6 asserts every rule
  from those stories fires together.
- Unlocks: Story 005.

---

## Implementation Record — 2026-08-25

**Status: all nine acceptance criteria met.** The code landed earlier in the
sprint. This record closes the paperwork, which had not been written.

### Verification performed

| AC | How it was verified |
|---|---|
| A single constant table | `const REQUIRED_CONSUMERS: Array[String]` in `src/scripts/level_validation.gd`. One definition, one call site. |
| Four rows, each traced to an Accepted ADR | `player` and `goal` (ADR-0002), `hud` (ADR-0010 D10.9), `level_bounds` (ADR-0011 D11.7). Each row is annotated with its ADR in the table comment. Asserted by `test_required_consumer_table_holds_exactly_four_rows`. |
| Fires on empty, unset or `null` | `test_wiring_fires_once_per_unwired_consumer`, `test_wiring_fires_when_the_export_is_absent_entirely`, `test_wiring_fires_on_an_empty_node_path_export`. |
| Fires when the export does not resolve to a live node | `test_wiring_fires_when_a_consumer_points_at_a_freed_node` and `test_wiring_fires_on_a_node_path_that_points_nowhere`. |
| Fires once per unwired consumer, each named | `test_wiring_fires_for_each_of_the_four_consumers_individually`. |
| `OxygenDrain` is excluded | `test_oxygen_drain_is_not_in_the_table`. The table comment records the reason: ADR-0002 part 4 makes it a child of `LevelRoot`, not an export, so this rule has no path to resolve. Its binding failure mode is covered by the ADR-0002 per-consumer guard instead. |
| The D3.3 admission rule is stated inline | The comment above the table states it: a consumer becomes required when the ADR that introduces it is Accepted, and the row lands in the same changeset as that ADR. |
| The combined report-all-failures test | `test_a_level_breaching_every_implemented_rule_reports_every_code` — ADR-0003 Validation Criterion 1. `test_the_unimplemented_rules_never_fire` is its counterpart, confirming `V-PROP-BUDGET` and `V-BOUNDS` stay silent until story 006. |
| Warning-clean under headless gdUnit4 | Full suite green 2026-08-25: 178 cases, 0 errors, 0 failures, 0 orphans, exit 0. |

### Note on the two accepted authoring shapes

`_check_wiring` accepts both a `NodePath` export and a direct typed node
reference. ADR-0003 D3.3 describes `NodePath` exports, but `main.gd` today uses
direct typed references such as `@export var player: Player`. Accepting only one
shape would have reported every level of the other shape as unwired. Both paths
are covered: `test_wiring_passes_on_node_paths_that_resolve` and
`test_wiring_passes_when_every_consumer_resolves`.

`test_wiring_does_not_call_methods_on_the_resolved_node` guards the rule's
boundary — this checks wiring, not binding, because under D3.1 `validate()` runs
at step (a) and `bind()` at step (c).

`tests/unit/level/level_validation_wiring_test.gd` contributes 13 cases.
