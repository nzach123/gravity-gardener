# Story 002: V-BUCKET-SUM and V-PLANT-MIN

> **Epic**: Level Load Validation
> **Status**: In Review
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: 2026-08-24

## Context

**GDD**: `design/gdd/watering-system.md`
**Requirement**: `TR-watering-008`, `TR-watering-015`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: ADR-0003 (primary) · ADR-0009 (secondary — owns
`Plant.buckets_required`; see the scope note below)

**ADR Decision Summary**: `V-BUCKET-SUM` compares two genuinely independent
quantities — the count of `Bucket` instances in the level, and the sum of every
plant's `buckets_required`. Neither is derived from the other, so their agreement
is real evidence rather than a tautology. Both directions of mismatch are reported,
since `watering-system.md` R8 tabulates both as level-breaking. `V-PLANT-MIN`
enforces the R5 floor of `buckets_required >= 1`; a zero would cap the plant
permanently and silently shrink the sum below `buckets_total`.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: Per **E1**, `@export` values are populated by
`PackedScene.instantiate()` before `_ready()` and without a `SceneTree`, so both
rules read authored data on a tree that was never added to the scene tree. Per
**F10**, gdUnit4 fails the whole suite on any GDScript warning at discovery — keep
`plant.gd` and `level_validation.gd` warning-clean.

**Control Manifest Rules (this layer)**:

- Required: "One shared `count_buckets(level)` static primitive, used both by
  `validate()`'s `V-BUCKET-SUM` and by `LevelRoot` to seed `LevelState`."
  — source: ADR-0003 (D3.5)
- Required: "`validate()` returns a `PackedStringArray` of coded findings
  (`[V-CODE] message`); codes are stable contract." — source: ADR-0003 (D3.4)
- Required: "`class_name` is required on `Plant`, `Bucket`, `PropBody`."
  — source: ADR-0003
- Forbidden: "`LevelValidation.validate()` must never return on the first breach —
  it must collect and return ALL contract violations in one pass."
  — source: ADR-0003 (`validation_first_failure_return`)
- Forbidden: "`Plant` (or any single objective) must never write level-wide state or
  decide the level is complete." — source: ADR-0002 (`plant_decides_level_outcome`).
  Relevant here because `V-BUCKET-SUM` is deliberately a **level-wide** rule owned
  by `LevelValidation`, not a per-plant self-check.
- Guardrail: gdUnit4 treats GDScript warnings as errors at test discovery — one
  warning fails the entire suite.

---

## Acceptance Criteria

*From `watering-system.md` R5, R8, AC7 and ADR-0003 D3.3, scoped to this story:*

- [x] `plant.gd` gains `@export_range(1, 4) var buckets_required: int = 1`, matching
      `watering-system.md` §7 (default 1, range 1–4, per-instance export on `Plant`,
      **not** a tuning resource — it is the per-level difficulty dial).
- [x] `V-BUCKET-SUM` fires when `count_buckets(level) != sum of every plant's
      buckets_required`, in **both** directions of mismatch.
- [x] The `V-BUCKET-SUM` finding names both quantities, in the ADR-0003 D3.4 shape:
      `[V-BUCKET-SUM] buckets_total 3 != sum(buckets_required) 4`.
- [x] `V-BUCKET-SUM` sources its bucket count from `count_buckets()` (story 001) and
      never from an independent count or an authored total.
- [x] `V-PLANT-MIN` fires once **per offending plant** when that plant's
      `buckets_required < 1`, naming the plant so an author can find it:
      `[V-PLANT-MIN] Plant "Plant2" has buckets_required 0; must be >= 1`.
- [x] A level breaching both rules returns findings for both in one call — no early
      return (ADR-0003 Validation Criterion 1, scoped to these two rules).
- [x] A clean level returns empty from `validate()`.
- [x] `plant.gd`, `level_validation.gd` and the test file are warning-clean under the
      headless gdUnit4 run.

---

## Implementation Notes

*Derived from ADR-0003 D3.3, D3.4, D3.5 and `watering-system.md` R5/R8:*

**On the `buckets_required` export — read this before writing it.** The export
belongs to ADR-0009 / `TR-watering-005` and would normally land with the Feature
watering epic, which has not been created. It is added here because two BLOCKING
acceptance criteria (`watering-system.md` AC7, `suit-oxygen.md` AC7) cannot be
tested without it, and because a rule that reads a property no class declares is a
parse error, not a deferred feature. **Add the export and nothing else** — no
`buckets_received` field, no intake cap, no growth visuals, no refusal logic. Those
are R5's behaviour half and stay with ADR-0009. When the watering epic is created,
it inherits an export that already exists rather than re-adding one.

`V-BUCKET-SUM` compares two independently sourced quantities and that independence
is the whole point — ADR-0002 is explicit that "agreement is the check". Do not
"optimise" the rule by deriving one side from the other; that converts real evidence
into a tautology that passes on every level.

Both directions of mismatch are breaches. `watering-system.md` R8 tabulates too many
buckets and too few buckets as separate level-breaking failures, so a one-sided
`>` or `<` comparison is wrong.

`V-PLANT-MIN` reports **per plant**, not once for the level. An author fixing three
zero-capacity plants should see three findings in one run, which is the same
report-all-failures reasoning that governs `validate()` as a whole.

The `@export_range(1, 4)` bound does **not** clamp a hand-edited `.tres` or `.tscn`
value — that limitation is recorded as an open item against the `tuning-resources`
epic (ADR-0006 T4). `V-PLANT-MIN` is the load-time floor that actually holds. It
deliberately checks only the lower bound; R8's sum check is what catches an
over-large value in practice.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: the scaffold, the recursive scan, `count_buckets()`, the code
  constants. This story consumes them.
- **Story 003**: `V-OXY-CAP` and `V-GRAV-EXPORT`.
- **Story 004**: `V-WIRING`, and the combined all-rules-fire-at-once test.
- **Story 005**: the `LevelRoot._ready()` call site and the `push_error` loop —
  this story delivers the returned findings, not the logged errors.
- **The Feature watering epic (ADR-0009)**: `buckets_received`, the intake cap, pour
  refusal, growth visuals. Only the `buckets_required` export lands here.
- **The level migration epic**: converting the 8 shipped levels to the multi-bucket
  economy. Every level currently fails this rule and that is expected until then.

---

## QA Test Cases

*Derived from `watering-system.md` AC7 and ADR-0003 Validation Criteria 1 and 4. The
developer implements against these — do not invent new test cases during
implementation.*

**Test file**: `tests/unit/level/level_validation_watering_rules_test.gd`

- **AC-1**: `V-BUCKET-SUM` fires when there are too few buckets
  - Given: a synthetic level with 3 `Bucket` nodes and 2 plants at
    `buckets_required = 2` each (sum 4)
  - When: `validate(level)` is called
  - Then: the result contains exactly one finding whose text starts with
    `[V-BUCKET-SUM]`, and that finding contains both `3` and `4`
  - Edge cases: 0 buckets with 1 plant requiring 1; a level with plants but no
    buckets at all

- **AC-2**: `V-BUCKET-SUM` fires when there are too many buckets (the mirror
  direction — R8 tabulates both)
  - Given: a synthetic level with 5 `Bucket` nodes and 2 plants at
    `buckets_required = 2` each (sum 4)
  - When: `validate(level)` is called
  - Then: exactly one `[V-BUCKET-SUM]` finding is returned
  - Edge cases: buckets present with **zero** plants — sum is 0, so this must fire

- **AC-3**: `V-BUCKET-SUM` stays silent when the quantities agree
  - Given: a synthetic level with 4 buckets and plants summing to 4
  - When: `validate(level)` is called
  - Then: no finding starts with `[V-BUCKET-SUM]`
  - Edge cases: zero buckets and zero plants — an empty level agrees trivially and
    must not fire this rule

- **AC-4**: removing a plant makes the rule fire — discovery is live, not cached
  (ADR-0003 Validation Criterion 4)
  - Given: a clean synthetic level that returns empty from `validate()`
  - When: one plant is removed from the tree and `validate()` is called again
  - Then: the second call returns a `[V-BUCKET-SUM]` finding
  - Edge cases: free the removed node in the test teardown, not before the assertion

- **AC-5**: `V-PLANT-MIN` fires once per offending plant, naming it
  - Given: a synthetic level with three plants at `buckets_required` of `0`, `-1`
    and `2`
  - When: `validate(level)` is called
  - Then: exactly two `[V-PLANT-MIN]` findings are returned, and each contains the
    name of its own plant node
  - Edge cases: `buckets_required = 1` is valid and must not fire; a negative value
    must fire

- **AC-6**: both rules report in one pass
  - Given: a synthetic level that breaches `V-BUCKET-SUM` **and** contains one plant
    at `buckets_required = 0`
  - When: `validate(level)` is called
  - Then: the result contains at least one `[V-BUCKET-SUM]` and at least one
    `[V-PLANT-MIN]` — not one or the other
  - Edge cases: this is the no-early-return guard; the test must fail if someone
    adds a `return` after the first breach

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/level/level_validation_watering_rules_test.gd` —
must exist and pass. This test file is the automated evidence for
`watering-system.md` AC7, which is typed **Logic** and is therefore a BLOCKING gate
under `.claude/docs/coding-standards.md`.

**Status**: [x] `tests/unit/level/level_validation_watering_rules_test.gd` exists and passes. Verified
2026-08-25 in a full headless gdUnit4 run: 178 cases, 0 errors, 0 failures, 0 flaky,
0 skipped, 0 orphans, exit 0. This file contributes 14 cases.

---

## Dependencies

- Depends on: **Story 001** must be DONE — this story consumes `count_buckets()`,
  the recursive scan and the `V_BUCKET_SUM` / `V_PLANT_MIN` constants.
- Unlocks: Story 005 (the `LevelRoot` call site needs at least one live rule to be
  worth wiring). Also unblocks the Feature watering epic's `buckets_required`
  dependency.

---

## Implementation Record — 2026-08-25

**Status: all eight acceptance criteria met.** The code landed earlier in the
sprint. This record closes the paperwork, which had not been written.

### Verification performed

| AC | How it was verified |
|---|---|
| `plant.gd` export | `src/scripts/plant.gd:18` — `@export_range(1, 4) var buckets_required: int = 1`. Asserted by `test_plant_declares_buckets_required_defaulting_to_one`. |
| `V-BUCKET-SUM` fires on disagreement | Both directions covered: `test_bucket_sum_fires_when_there_are_too_few_buckets` and `test_bucket_sum_fires_when_there_are_too_many_buckets`. watering-system.md R8 tabulates both as level-breaking, so a one-sided comparison would have been wrong. |
| The finding names both quantities | The D3.4 shape `buckets_total %d != sum(buckets_required) %d` is emitted. Asserted by the two tests above. |
| Independent sourcing | The bucket side comes from `count_buckets()` (story 001) and the plant side from summing each plant's export. The two are never derived from each other. An inline comment states why: deriving one from the other turns the check into a tautology that passes on every level. |
| `V-PLANT-MIN` fires once per offending plant | `test_plant_min_fires_once_per_offending_plant` and `test_plant_min_names_the_offending_plant`. The lower bound and negative cases are covered by `test_plant_min_does_not_fire_at_the_lower_bound` and `test_plant_min_fires_on_a_negative_value`. |
| Both rules report in one call, no early return | `test_both_watering_rules_fire_together`. |
| A clean level returns empty | `test_bucket_sum_passes_when_counts_agree`, plus `test_bucket_sum_passes_on_a_level_with_neither_plants_nor_buckets` for the empty-level edge. |
| Warning-clean under headless gdUnit4 | Full suite green 2026-08-25: 178 cases, 0 errors, 0 failures, 0 orphans, exit 0. |

`tests/unit/level/level_validation_watering_rules_test.gd` contributes 14 cases.
Depth coverage is explicit: `test_bucket_sum_counts_buckets_at_any_depth` and
`test_plant_min_checks_plants_at_any_depth`.
