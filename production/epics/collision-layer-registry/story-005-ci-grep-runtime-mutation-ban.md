# Story 005: CI grep enforcing the D4.6 runtime-mutation ban

> **Epic**: Collision Layer Registry
> **Status**: In Review
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1 hour)
> **Manifest Version**: 2026-08-17
> **Last Updated**: 2026-08-23

## Context

**GDD**: `design/gdd/physics-props.md`
**Requirement**: `TR-props-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004: Collision layer allocation
**ADR Decision Summary**: D4.6 forbids any gameplay script from calling
`set_collision_layer_value()`, `set_collision_mask_value()`, or assigning
`collision_layer` / `collision_mask` at runtime — layers are authored data
only, enforced everywhere except inside `collision_layers.gd` itself. ADR-0004
identifies this as the **weakest link in the whole decision**: it is enforced
by review and grep today, not by structure, and recommends a CI grep step to
make it structural. The epic leaves the decision — add the step, or record why
not — to this story.

**Decision made by this story: add the CI grep step.** The project already
has a working CI pipeline (`.github/workflows/tests.yml`, GdUnit4-action on
every push/PR to `main`), so adding one grep step is low cost and directly
closes the gap ADR-0004 calls its weakest link.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: No engine API involved — this is a text-search CI step over
the repository's `.gd` files, not a runtime or engine-specific check.

**Control Manifest Rules (this layer)**:
- Forbidden: "Never assign `collision_layer`/`collision_mask` at runtime, or
  call `set_collision_layer_value()`/`set_collision_mask_value()`, on any
  gameplay node. Layers are authored data only." — source: ADR-0004
  (`runtime_collision_mask_mutation`)

---

## Acceptance Criteria

*From ADR-0004 Validation Criterion 5 and the Risks table's "Runtime mutation
silently voids the guarantee (F8)" row:*

- [x] `.github/workflows/tests.yml` gains a CI step that greps the repository
      for `set_collision_layer_value`, `set_collision_mask_value`, and any
      assignment to `collision_layer` or `collision_mask` (e.g.
      `collision_layer =`, `collision_mask =`), scoped to `src/**/*.gd`.
- [x] The grep step **excludes** `src/scripts/collision_layers.gd` itself —
      that file is the one place these tokens are allowed to appear (as
      constant declarations, not runtime calls).
- [x] The grep step fails the CI job (non-zero exit) if any match is found
      outside the excluded file.
- [x] The step runs before or alongside the existing GdUnit4 test step, so a
      violation is caught in the same CI run as everything else.
- [x] Verified once on a scratch branch: deliberately add a
      `set_collision_mask_value()` call to any gameplay script (e.g.
      `player.gd`), confirm the new CI step fails, then revert the change.
      Record this as evidence rather than leaving it to be discovered later.
      **[METHOD CLARIFIED 2026-08-25]** A scratch branch alone does not fire
      this workflow — it triggers on push to `development`/`main` or on a PR
      targeting them, and this repository has no `main`. Verified on scratch
      branch `ci-1-live-fire` via PR #1 against `development`:
      `set_collision_mask_value(5, true)` in `player.gd` caught by the
      ADR-0004 D4.6 step in run #3 (red), reverted, run #4 green. Evidence:
      `production/qa/evidence/ci-1-live-fire-2026-08-25.md`.

---

## Implementation Notes

*Derived from ADR-0004 D4.6 and Validation Criterion 5:*

- The rule is already written as a greppable pattern in the ADR itself: "No
  file outside `collision_layers.gd` contains `set_collision_layer_value`,
  `set_collision_mask_value`, or an assignment to `collision_layer` /
  `collision_mask`." Implement the CI step as close to that literal wording as
  possible.
- A simple approach: a `grep -rn` (or `rg`) invocation over `src/` for the
  three patterns, piped to exclude `collision_layers.gd`, with the step
  failing if grep finds anything. Keep it to a single shell step — this does
  not need a dedicated tool or script file.
- Be careful with the `collision_layer =` / `collision_mask =` patterns: they
  must not false-positive on `.tscn` files, which legitimately set these as
  scene properties (that's authored data, exactly what D4.6 permits). Scope
  the grep to `.gd` files only.
- This step is advisory-turned-structural: before this story, the ban was
  "enforced by review and grep" per the ADR's own honest assessment. After
  this story, it is enforced by CI, which is what the epic's Definition of
  Done means by "The CI-grep decision is recorded either way."
- Do not use this grep to also catch `.tscn` authored assignments — those are
  correct and expected (stories 001–003 make plenty of them). The ban is
  runtime/code mutation only.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: the gdUnit4 test suite — a different enforcement mechanism
  (scene-state assertions) for a different guarantee (authored-state
  isolation, not runtime mutation).
- Any change to `collision_layers.gd` itself — story 001's job. This story
  only adds a CI step that references that file's path as an exclusion.

---

## QA Test Cases

*Generated by `/qa-plan sprint` on 2026-08-18. Story type: **Logic**.*

**This story owns no gdUnit4 test.** The CI step in
`.github/workflows/tests.yml` is itself the enforcement artifact — there is no
meaningful way to unit-test a workflow step from inside the suite it gates.
Evidence is the scratch-branch verification below. `/story-done` should expect no
`tests/unit/` path for this story.

### Positive cases — the step must PASS

| # | Case | Expected |
|---|---|---|
| T5.1 | Current `src/**/*.gd` as committed | Step exits `0`. No violations exist today |
| T5.2 | `src/scripts/collision_layers.gd` contains the banned tokens as constant declarations | Step exits `0` — the file is excluded. This is the one place the tokens are allowed |
| T5.3 | `.tscn` files assigning `collision_layer` / `collision_mask` | Step exits `0`. Authored scene data is exactly what D4.6 permits, and stories 001–003 create plenty of it |

**T5.3 is the most likely way to get this wrong.** A grep scoped too broadly
fails CI on the very changes this epic is making. Scope to `.gd` only.

### Negative cases — the step must FAIL

| # | Case | Expected |
|---|---|---|
| T5.4 | `set_collision_layer_value()` added to any gameplay script | Non-zero exit, CI job fails |
| T5.5 | `set_collision_mask_value()` added to any gameplay script | Non-zero exit |
| T5.6 | `collision_layer = ...` assignment added to a gameplay script | Non-zero exit |
| T5.7 | `collision_mask = ...` assignment added to a gameplay script | Non-zero exit |
| T5.8 | A violation added to a **new** `.gd` file not present today | Non-zero exit — confirms the pattern is path-glob based, not a fixed file list |

### Edge cases

- **Whitespace variants.** `collision_mask=2`, `collision_mask  =  2` and
  `collision_mask\t= 2` must all match. A pattern requiring exactly one space is
  trivially bypassed, on purpose or by a formatter.
- **Comments and strings.** `# never set collision_mask = 2 at runtime` will
  match a naive grep. Decide deliberately: either accept comment false-positives
  (simplest, and arguably correct — the token should not appear), or exclude
  comment lines. Record which was chosen, because the next author will hit it.
- **`collision_layer_value` vs `collision_layer`.** Ensure the assignment pattern
  does not double-report a line that the method-call pattern already caught.
- **Exit code, not output.** The step must fail the job on match. `grep` returns
  `1` when it finds *nothing*, which is inverted from what this step needs — get
  the inversion right or the step silently passes forever.

*That last case is the failure mode most likely to ship unnoticed: a step that
always passes looks identical to a step that works, until the day it should have
caught something.*

### Manual verification — REQUIRED, blocking

**Verification method**: scratch-branch CI run. **Who signs off**: developer.
**Evidence**: paste the failing CI run's step output into the story's completion
notes. Acceptance criterion 5 requires this recorded, not merely done.

- [ ] Add a `set_collision_mask_value()` call to `player.gd` on a scratch branch
- [ ] Push, and confirm the new CI step fails the job with a readable message
      that names the offending file and line
- [ ] Confirm the GdUnit4 test step still runs (or is correctly short-circuited) —
      the grep must not mask unrelated failures
- [ ] Revert the scratch change
- [ ] Confirm the step passes on the clean branch

**Estimated test count**: 0 automated tests; 8 specified CI cases, 1 verified by
hand on a scratch branch.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Config/Data-style smoke check: the CI step itself is the evidence. Record
  the scratch-branch verification (acceptance criteria, last item) in the
  story's completion notes rather than as a separate test file — there is no
  gdUnit4 test for a CI workflow step.

**Status**: [x] CI step landed and verified locally. [x] Verified by a real CI run 2026-08-25 (CI-1) - `production/qa/evidence/ci-1-live-fire-2026-08-25.md`.

---

## Dependencies

- Depends on: Story 001 (the exclusion path `src/scripts/collision_layers.gd`
  must exist for the grep step to reference it correctly)
- Unlocks: None

---

## Implementation Record

*Written 2026-08-23.*

### What changed

`.github/workflows/tests.yml` gains one step, **Enforce the ADR-0004 runtime
collision-mutation ban**, placed before the GdUnit4 step so a violation is
caught in the same run as everything else.

### Decisions the next author needs

- **Exit-code inversion handled explicitly.** `grep` returns `1` when it finds
  *nothing*, which is the inverse of what this step needs. The matches are
  captured into a variable and the exit code is decided by an `if`. A bare
  `grep` here would have passed forever while looking correct — the edge case
  the story flagged as most likely to ship unnoticed.
- **Scoped to `--include='*.gd'` under `src/`.** `.tscn` files assign these
  properties legitimately; that authored data is exactly what D4.6 permits.
- **Comment lines are NOT excluded.** A `# never set collision_mask = 2`
  comment will fail the step. Chosen deliberately: the token should not appear
  in a gameplay script at all, and this is cheaper than stripping comments in
  a regex. Recorded here because the next author will hit it.
- **No double-reporting.** The assignment pattern is guarded by
  `[^_[:alnum:]]`, so `set_collision_layer_value(` is matched only by the
  method-call pattern, not twice.

### Verification performed (locally, not in CI)

| # | Case | Result |
|---|---|---|
| T5.1 | Clean `src/**/*.gd` as committed | no output, step passes |
| T5.2 | Exclusion of `collision_layers.gd` | load-bearing — unfiltered, that file produces 2 hits (lines 7 and 8, doc comments) |
| T5.3 | `.tscn` files assigning layer/mask | not matched; this story's own `level_05`/`level_06` edits do not trip it |
| T5.4 | `set_collision_mask_value(2, true)` in `player.gd` | caught |
| T5.5 | `set_collision_layer_value(1, false)` | caught |
| T5.6 | `collision_layer=1` (no spaces) | caught |
| T5.7 | `collision_mask = 2` | caught |
| — | `collision_mask  =  8` (multiple spaces) | caught |

All five planted violations were reported with file and line number, then
reverted. `git status` confirms `player.gd` is unmodified.

### Open — blocks Complete

**AC-5 is only partly satisfied.** It requires a *scratch-branch CI run* with
the step's failing output pasted in. What was done is a local reproduction of
the exact shell the step runs. The grep logic is proven; the step's behaviour
inside GitHub Actions is not.

This cannot be closed from here, because the workflow triggers on `main` and
this repo's main branch is `development`. **No CI run has ever fired on this
sprint's work.** Fixing the trigger was ruled out of scope by the developer,
so this AC stays open until either the trigger is widened or the branch merges.

### Related CI problems, recorded not fixed

Both were ruled out of scope for this story:

1. **Stale `.godot` class cache.** A clean checkout fails to load the runner
   with `Could not find type "GdUnitTestCIRunner"` — presenting as a parse
   error in the addon, not a test failure. The fix is a `godot --headless
   --path . --import` pass before the tests. It cannot simply be added here:
   the workflow uses `MikeSchulze/gdUnit4-action@v1`, which installs and runs
   Godot itself, so there is no Godot binary for a preceding step to call.
   Doing this properly needs that action's actual input list.
2. **The runner stops at the first failing test.** Reproduced again this
   session: with one deliberate failure, the file reported `2 test cases` out
   of 8. In CI a single failure would mask every later one, so a red build
   under-reports the damage. Cause not investigated; believed to be a gdUnit4
   runner setting, not a defect in any test file.
