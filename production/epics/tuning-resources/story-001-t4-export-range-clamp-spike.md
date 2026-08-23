# Story 001: T4 spike — does `@export_range` clamp a hand-edited `.tres`?

> **Epic**: Tuning Resources
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: S (1-2 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/physics-props.md` (§7 ranges), `design/gdd/suit-oxygen.md` (§7),
`design/gdd/watering-system.md` (§7)
**Requirement**: `N/A` — this story verifies ADR-0006 engine fact **T4**. T4 is an
engine claim, not a GDD requirement, so it carries no TR-ID.
*(Requirement text for the knobs themselves lives in `docs/architecture/tr-registry.yaml`
under TR-watering-013 / TR-oxygen-011 / TR-props-009 — read fresh at review time.)*

**ADR Governing Implementation**: ADR-0006: Tuning resource strategy
**ADR Decision Summary**: D6.4 puts an `@export_range` on every tuning knob, using
the GDD range verbatim, and treats that range as an **authoring-time constraint
only**. That stance rests on T4: the claim that `@export_range` shapes the inspector
but does not clamp or reject a value typed by hand into a `.tres`. T4 is the one
engine claim the 2026-08-14 specialist gate could not discharge empirically.

**Engine**: Godot 4.7.1 | **Risk**: **HIGH**
**Engine Notes**:
- The HIGH rating is at the project level, not the decision level. No
  `modules/core.md` engine reference exists — `docs/engine-reference/godot/modules/`
  holds only `physics-2d.md` and `ui-control.md` — so the `Resource` / `preload` /
  `@export_range` domain has **no curated snapshot to check against**.
- **No post-cutoff API is involved.** `Resource`, `preload()`, `class_name` and
  `@export_range` all predate the ~4.3 training coverage, and
  `breaking-changes.md` / `deprecated-apis.md` list nothing touching the Resource
  system across 4.4 → 4.7.
- T1, T2 and T3 are **VERIFIED TRUE** by the 2026-08-14 gate. **T4 is not.** The
  specialist began an isolated project against the pinned 4.7.1 binary and did not
  finish it.
- Do not answer this from training data. Run it against the installed
  `Godot_v4.7.1-stable_win64` binary.

**Control Manifest Rules (this layer)**:
- Required: "Every tuning knob is `@export_range`, using the GDD-documented range
  verbatim." — source: ADR-0006 (D6.4)
- Guardrail: gdUnit4 treats GDScript warnings as errors at test discovery — one
  warning fails the entire suite. Any scratch script written for this spike must
  stay outside `tests/`, or be warning-clean.

---

## Acceptance Criteria

*From ADR-0006 Migration Plan step 5 and the epic's headline risk:*

- [ ] An isolated Godot project is built against the pinned `Godot_v4.7.1-stable`
      binary, holding one `Resource` subclass with one `@export_range(0.8, 1.2)`
      float property and one `@export_range(10, 80)` int property.
- [ ] A `.tres` file for that resource is **hand-edited outside the editor** to a
      value beyond the declared range (for example `1.9` and `500`).
- [ ] The result is observed for each of these three questions, and each answer is
      recorded as OBSERVED, not inferred:
      - Does loading the `.tres` **clamp** the value to the range bound?
      - Does loading **reject** the file, error, or fall back to the default?
      - Does the out-of-range value **survive intact** into the loaded resource?
- [ ] The observation is repeated once **headless** (`--headless`) and once with the
      **editor open**, because the two load paths are not assumed to agree.
- [ ] The result is written to
      `production/qa/evidence/t4-export-range-clamp-spike.md`, with the exact binary
      version string, the test file contents, and the observed values.
- [ ] **ADR-0006 is updated**: the T4 row's Verdict changes from partially discharged
      to the observed verdict, the *Risks* entry for T4 is closed, and the
      *Verification Required* field in the Engine Compatibility table is corrected.
- [ ] The `tuning-resources` epic's Risks table row for T4 changes from **OPEN** to
      the observed outcome.
- [ ] `production/epics/index.md`'s "Open risks carried by these epics" row for
      ADR-0006 T4 is updated from **OPEN**.

---

## Implementation Notes

*Derived from ADR-0006 D6.4, the T4 row, and the epic Risks table:*

- **This is a spike, not a feature.** The isolated project is throwaway. Do not add
  it to `src/`. Put it under `prototypes/` or a scratch directory, and do not commit
  the project itself — the evidence document is the deliverable.
- Until this story closes, **treat every `@export_range` as an inspector hint, not a
  validator.** If a knob must be clamped, clamp it in code. Stories 002 and 003 are
  written on that assumption.
- **The stakes are low, and the outcome cannot weaken the ADR.** T4 only justifies
  *why* D6.4 is authoring-time-only. If values turn out to be clamped at load, the
  ADR gets stronger, not weaker. Do not treat a "clamped" result as a defect.
- If the result is **clamped or rejected**, say so plainly in the evidence doc and
  flag it to the architect. It does not by itself change D6.4's wording, but it does
  change the failure mode described in D6.4's closing paragraph, and that paragraph
  would then be inaccurate.
- Use the real pinned binary. A `4.7.2-rc1` exists but no 4.7.2 stable has been
  released, and `VERSION.md` forbids pinning to an rc.
- Record the exact `--version` output string in the evidence doc. A future reader
  must be able to tell which build produced the result.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: creating the three real `Resource` scripts in `src/scripts/tuning/`.
- Story 003: authoring the three real `.tres` files.
- Story 005: the gdUnit4 validation suite. This spike is **not** a committed test.
- Adding any runtime clamp to `LevelValidation`. ADR-0003 D3.3 froze its rule set at
  six, and D6.4 declined to escalate this to a runtime check on purpose.

---

## QA Test Cases

*Story type: **Integration**. Evidence is a documented spike, not an automated test —
the thing under test is the engine, not this project's code.*

- **AC-1**: An out-of-range value in a hand-edited `.tres` is loaded
  - Given: a `Resource` subclass with `@export_range(0.8, 1.2) var prop_gravity_scale: float = 1.0`,
    and a `.tres` hand-edited to `prop_gravity_scale = 1.9`
  - When: the `.tres` is loaded with `load()` and the property is read
  - Then: record the observed value — `1.9` (survives), `1.2` (clamped), or `1.0`
    (rejected, fell back to default)
  - Edge cases: exactly on the upper bound (`1.2`); just above the bound
    (`1.2000001`); below the lower bound (`0.1`); a negative value (`-1.0`); a
    non-numeric string.

- **AC-2**: The same check on an integer knob
  - Given: `@export_range(10, 80) var props_per_level_budget: int = 40`, `.tres`
    hand-edited to `500`
  - When: the resource is loaded and the property is read
  - Then: record the observed value
  - Edge cases: `0`; a negative value; a float written where an int is declared.

- **AC-3**: The headless and editor load paths agree
  - Given: the same hand-edited `.tres`
  - When: it is loaded once under `--headless` and once with the editor open
  - Then: both paths report the same value
  - Edge cases: if they disagree, that disagreement **is** the finding. Record both
    numbers and flag it — it would mean the authored value and the shipped value can
    differ, which is a far larger problem than T4 itself.

### Manual verification — this story is entirely manual

- [ ] `godot --version` output recorded verbatim in the evidence doc
- [ ] Resource script contents recorded verbatim
- [ ] Hand-edited `.tres` contents recorded verbatim
- [ ] Observed value recorded for every case above, headless and editor
- [ ] ADR-0006 T4 row updated to the observed verdict

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `production/qa/evidence/t4-export-range-clamp-spike.md` — documented spike with the
  binary version, the test artefacts, and every observed value
- ADR-0006's T4 row updated in `docs/architecture/adr-0006-tuning-resource-strategy.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None. This is the first story in the epic and blocks nothing hard —
  but run it first, because it is the epic's headline risk and it is cheap.
- Unlocks: Story 002 (confirms whether any knob needs a code-side clamp)
