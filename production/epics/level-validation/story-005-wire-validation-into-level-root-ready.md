# Story 005: Wire validate() into LevelRoot._ready() at step (a)

> **Epic**: Level Load Validation
> **Status**: Blocked
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (2-3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

> **BLOCKED**: the `level-state` epic must land first. `LevelState` and
> `OxygenState` do not exist, and this story's whole subject is the *ordering*
> between `validate()` and their construction. There is nothing to order until they
> are there. This is a scheduling block, not a design gap — every governing ADR is
> Accepted.

## Context

**GDD**: `design/gdd/watering-system.md` · `design/gdd/suit-oxygen.md`
**Requirement**: `TR-watering-015`, `TR-oxygen-008` — the runtime half. Stories 002
and 003 make the breaches *returnable*; this story makes them *logged*, which is what
both AC7 criteria literally say ("Level load logs an error when ...").
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**Governing ADRs**: ADR-0003 (primary, D3.1/D3.5/D3.6) · ADR-0002 (secondary — owns
the `LevelRoot._ready()` sequence this inserts into)

**ADR Decision Summary**: `architecture.md` published a `LevelRoot._ready()` order
that constructed state first and validated second. **That ordering is defective and
ADR-0003 D3.1 corrects it.** `OxygenState._init` rejects `capacity <= 0`, so on a
mis-authored level the construction fails before validation ever runs — the one input
the rule was written for is the one input on which it never executes. Validation
moves to step (a), ahead of construction. `LevelRoot` then `push_error`s each
returned finding and **continues starting the level** (D3.6).

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**:

- **E3** (verified 2026-08-14, **do not re-search**) — `push_error()` reaches disk in
  an exported release build. It is never compiled out, unlike `assert()`, and always
  writes to stderr. `debug/file_logging/enable_file_logging` defaults to `false`, but
  the desktop override `...enable_file_logging.pc` defaults to **`true`**, routing
  error output to `user://logs/godot.log`. This project's `project.godot` overrides
  neither and the target is PC, so the default is live in the shipped build.
- **F10** — one GDScript warning fails the whole gdUnit4 suite at discovery.

**Control Manifest Rules (this layer)**:

- Required: "`LevelValidation.validate()` runs BEFORE `LevelState`/`OxygenState` are
  constructed, reading only raw authored `@export` scene data." — source: ADR-0003 (D3.1)
- Required: "`validate()` never pushes an error itself. It is a pure function; the
  caller (`LevelRoot`) iterates the result and `push_error()`s each finding."
  — source: ADR-0003
- Required: "One shared `count_buckets(level)` static primitive, used both by
  `validate()`'s `V-BUCKET-SUM` and by `LevelRoot` to seed `LevelState`."
  — source: ADR-0003 (D3.5)
- Required: "Use `push_error()`, never `assert()`, for bind/initialize guards —
  `assert()` compiles out entirely in release exports." — source: ADR-0001, ADR-0002
- Required: "No `OS.is_debug_build()` guard on validation — it runs in every build,
  including release." — source: ADR-0003 (D3.6)
- Required: "`LevelState` and `OxygenState` are plain `RefCounted` objects constructed
  by `LevelRoot._ready()`, never autoloads or singletons." — source: ADR-0002
- Forbidden: "Never reach level or oxygen state through an autoload, a new singleton,
  or a service locator." — source: ADR-0002 (`global_level_state_access`)

---

## Acceptance Criteria

*From ADR-0003 D3.1, D3.5, D3.6 and Validation Criteria 2 and 3, scoped to this story:*

- [ ] `LevelRoot._ready()` calls `LevelValidation.validate(self)` as step **(a)**,
      before `LevelState` or `OxygenState` is constructed.
- [ ] `LevelRoot` iterates the returned array and calls `push_error()` on **each**
      finding — not on the first, and not on a joined summary string.
- [ ] The level **still starts** after findings are reported. Validation never halts
      or aborts `_ready()` (D3.6).
- [ ] `LevelState` is seeded from `LevelValidation.count_buckets(self)` at step (b),
      never from an independent count or an authored total (D3.5).
- [ ] The full corrected sequence holds, in this order: (a) validate, (b) construct
      state, (c) bind consumers, (d) connect `Plant.pour_completed`, (e)
      `GravityAuthority.reset_to()`, (f) wire zones and register props.
- [ ] No `OS.is_debug_build()` guard appears at the call site (Validation Criterion 3
      covers both `level_validation.gd` and the `LevelRoot` call site).
- [ ] `assert()` is not used to report any finding.
- [ ] **`architecture.md` is amended** to swap steps (a) and (b) in the §Frame update
      path init block, with a note that validation reads raw scene data — ADR-0003
      Migration Plan step 1. The published order is defective as written; leaving it
      is how the next reader implements the bug again.
- [ ] `main.gd` and the test file are warning-clean under the headless gdUnit4 run.

---

## Implementation Notes

*Derived from ADR-0003 D3.1, D3.5, D3.6:*

**The ordering is the deliverable.** Getting `validate()` called is trivial; getting
it called *before* construction is the point, and it is the thing a future refactor
will silently undo. Add an inline comment at the call site citing ADR-0003 D3.1 and
the `OxygenState._init` reason, in the same spirit as ADR-0005's deferral comment.

**Report every finding, and keep going.** `watering-system.md` R8 names the silent
unwinnable level as the more dangerous failure mode, and that property does not
become less dangerous once shipped. So there is no build-conditional branch and no
early exit.

**Be precise about what release-build reporting buys — do not overclaim it.** Per E3,
a finding in a release build is written to `user://logs/godot.log` and is
**retrievable after the fact** by the author, by QA, or from a file a player attaches
to a bug report. It is **not** surfaced to the player in-game, and this story does not
make it so. The value is diagnostic, not corrective.

**`count_buckets()` is shared for a reason.** If `LevelRoot` seeded `buckets_total`
from its own count, `V-BUCKET-SUM` could pass while certifying a number the game does
not actually use. One definition of "a bucket", used by both.

**`main.gd` is not yet `LevelRoot`.** It is a bare `extends Node2D` with no
`class_name`, no `oxygen_capacity` and no `default_gravity_*`. The `level-state` and
`gravity-authority` epics reshape it. Take this story after `level-state` lands and
build on what it leaves, rather than reshaping `main.gd` here.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Stories 001-004**: `LevelValidation` itself and its five live rules.
- **Story 006**: `V-PROP-BUDGET` and `V-BOUNDS`.
- **The `level-state` epic (ADR-0002)**: creating `LevelState` / `OxygenState`, the
  `bind()` contract, the per-consumer not-bound guards, the `LevelRoot` exports.
- **The `gravity-authority` epic (ADR-0001)**: `GravityAuthority.reset_to()` at step
  (e). This story only fixes the position of step (a) relative to (b).
- **The level migration epic**: the suite-wide CI test over 8 level scenes (D3.7),
  and making the shipped levels return empty.
- **The camera-first-broadcast gap** flagged in ADR-0011 (session-18 finding 3, steps
  (e) and (f)) — a known open item inside this same init order, explicitly **not**
  fixed by this story or by ADR-0011. Do not opportunistically fix it here; it needs
  its own decision.

---

## QA Test Cases

*Derived from ADR-0003 Validation Criteria 2 and 3. The developer implements against
these — do not invent new test cases during implementation.*

**Test file**: `tests/integration/level/level_root_validation_order_test.gd`

- **AC-1**: validation runs before construction, proven by the input that would abort
  it (ADR-0003 Validation Criterion 2)
  - Given: a level scene authored with `oxygen_capacity = 0`
  - When: it is loaded and `LevelRoot._ready()` completes
  - Then: a `V-OXY-CAP` finding was produced **and** `_ready()` reached step (b) —
    assert on an observable set at or after step (b), not on the absence of a crash
  - Edge cases: this is the whole D3.1 reordering under test. If `_ready()` aborts
    during `OxygenState` construction, the reorder was relocated rather than fixed

- **AC-2**: the level still starts when findings exist
  - Given: a level breaching two rules at once
  - When: it is loaded
  - Then: `_ready()` runs to completion and the level is playable — state constructed,
    consumers bound
  - Edge cases: a level breaching every live rule must still start

- **AC-3**: every finding is reported, not just the first
  - Given: a level breaching three rules
  - When: `_ready()` runs
  - Then: three separate errors are reported — one per finding
  - Edge cases: assert the count. Verifying this may need a spy on the reporting step
    rather than intercepting the engine's error stream, which is exactly the coupling
    D3.4 exists to avoid. If a spy is not cleanly achievable, downgrade this specific
    case to a documented manual check against `user://logs/godot.log` and record it in
    `production/qa/evidence/` — do not weaken AC-1 or AC-2 to compensate

- **AC-4**: `buckets_total` comes from the shared primitive
  - Given: a level with 4 buckets
  - When: `_ready()` completes
  - Then: `LevelState.buckets_total == 4`, equal to
    `LevelValidation.count_buckets(level)` called independently on the same tree
  - Edge cases: removing a bucket and reloading changes both values together

- **AC-5**: grep guards
  - Setup: from the repository root
  - Verify: `grep -n "is_debug_build" src/scripts/main.gd src/scripts/level_validation.gd`
  - Pass condition: no output (ADR-0003 Validation Criterion 3)

- **AC-6**: `architecture.md` matches the implemented order
  - Setup: open `docs/architecture/architecture.md` §Frame update path
  - Verify: the init block lists validation before state construction, with a note
    that validation reads raw scene data
  - Pass condition: the document and the code agree — no reader can implement the
    defective order from the published text

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/level/level_root_validation_order_test.gd`
— must exist and pass. If AC-3 cannot be automated cleanly, its manual check is
recorded in `production/qa/evidence/level-root-validation-order-evidence.md`; the
other five criteria stay automated.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: **Stories 001-004** must be DONE, **and the `level-state` epic must
  have landed `LevelRoot`, `LevelState` and `OxygenState`.** This is what makes the
  story Blocked today.
- Unlocks: The level migration epic (QQ-03) — its per-level gate is this call site
  plus the deferred suite-wide CI test.
