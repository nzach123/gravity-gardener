# Story 005: Level default gravity exports and reset_to on level load

> **Epic**: Gravity Authority
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (3 hours)
> **Manifest Version**: 2026-08-17
> **Last Updated**: *(set by /dev-story)*

## Context

**GDD**: `design/gdd/gravity.md`
**Requirement**: `TR-gravity-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Gravity Ownership and Global Broadcast
**Governing ADRs**: ADR-0001 (primary, decision part 6) · ADR-0002 (secondary — it
moved the call site from `GameManager.reset_level_state()` to `LevelRoot._ready()`) ·
ADR-0003 (secondary — the `V-GRAV-EXPORT` validation rule that catches a level shipping
without these exports)
**ADR Decision Summary**: An autoload survives `reload_current_scene()`, so without an
explicit reset the player restarts a level carrying whatever gravity they died under.
Each level root exports `default_gravity_direction` and `default_gravity_multiplier`,
and `LevelRoot._ready()` calls `GravityAuthority.reset_to()` with them. One mechanism
covers first load and restart alike, because restart *is* a scene reload.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: `SceneTree.reload_current_scene()`, autoload lifetime and `@export`
are all pre-4.4 API, unchanged through 4.7. The load-bearing engine fact here is
ordering: Godot calls `_ready()` **bottom-up**, so `Player` (a child) initializes the
authority before `LevelRoot` (the parent) resets it. That ordering is what makes this
story's call safe, and it is a documented engine guarantee rather than an assumption.

**Performance**: One method call at level load. No per-frame cost.

**Control Manifest Rules (this layer)**:
- Required: "Every level must declare `default_gravity_direction` /
  `default_gravity_multiplier` exports on `LevelRoot`; `GravityAuthority.reset_to()` is
  called from `LevelRoot._ready()` (not `GameManager`)." — source: ADR-0001, amended by
  ADR-0002
- Required: "Restart = `reload_current_scene()` alone. No `reset()` methods anywhere;
  restart correctness is object lifetime, not a hand-maintained clear function." —
  source: ADR-0002
- Required: "`LevelValidation.validate()` runs BEFORE `LevelState`/`OxygenState` are
  constructed, reading only raw authored `@export` scene data." — source: ADR-0003 (D3.1)
- Forbidden: "Never add `reset()` to `LevelState` or `OxygenState`, or reintroduce
  `GameManager.reset_level_state()`." — source: ADR-0002 (`level_state_reset_method`)
- Forbidden: "Never call `set_gravity()`/`reset_to()` before
  `GravityAuthority.initialize()`." — source: ADR-0001 (`broadcast_before_initialize`)

---

## Acceptance Criteria

*From GDD `design/gdd/gravity.md` R2 and ADR-0001 decision part 6, scoped to this story:*

- [ ] `LevelRoot` exports `default_gravity_direction: Vector2` and
      `default_gravity_multiplier: float`.
- [ ] `LevelRoot._ready()` calls `GravityAuthority.reset_to(default_gravity_direction,
      default_gravity_multiplier)` at init step 3c — after `LevelValidation.validate()`
      (3a) and the state seeding (3b), and before zone and prop wiring (3d).
- [ ] All 8 existing level scenes declare both exports with authored values matching
      the gravity each level currently starts in.
- [ ] Restarting a level via `reload_current_scene()` restores that level's declared
      default gravity, regardless of what gravity was active at the moment of death.
- [ ] First load and restart go through the same code path — there is no separate
      first-load branch.
- [ ] No `reset()` method is added to any object, and
      `GameManager.reset_level_state()` is not reintroduced.
- [ ] `reset_to()` is called after `Player._ready()` has run `initialize()`, so the
      authority's refusal guard never fires on a correctly wired level.

---

## Implementation Notes

*Derived from ADR-0001 decision part 6 (as amended by ADR-0002) and the init-order
table in ADR-0001 part 7:*

- The authoritative init order, from ADR-0001 part 7, is:
  1. Autoloads (`GameManager`, `GravityAuthority`) — uninitialized, guarded
  2. Level children, bottom-up: `Player._ready()` derives the baseline and calls
     `GravityAuthority.initialize()`; then plants, buckets, props, zones; then `HUD`
  3. `LevelRoot._ready()` (parent, last):
     a. `LevelValidation.validate(level)` — `push_error` on contract breach
     b. seed `LevelState` / `OxygenState` from exports
     c. `GravityAuthority.reset_to(default_gravity_*)` — the first broadcast
     d. wire zones to `GravityAuthority`; register props with `GravityAuthority`
  Step 3c is this story. Do not move it earlier — validate must run first, on raw
  authored data.
- This is a **regression closure, not a feature**. Nothing in any GDD asks for it. It
  exists purely because moving gravity to an autoload took away a property the old
  design had for free: gravity used to die with the player node on scene reload. ADR-0001
  records this in its Negative Consequences, and the story should be reviewed in that
  light — the bar is "restart behaves as it did before the move", not "restart gains
  something".
- `reset_to()` is distinct from `set_gravity()` on purpose: it establishes a starting
  state rather than responding to a zone. If the implementation from story 001 made them
  the same function with a flag, that is fine, but the *name* `reset_to` must survive —
  ADR-0001's Key Interfaces block and the control manifest both name it.
- Authoring the 8 levels is mechanical but not blind. Read each level's existing
  starting orientation from whatever zone or implicit default it relies on today, and
  author the export to match. A level whose export disagrees with its current start is a
  behaviour change disguised as data entry.
- **`V-GRAV-EXPORT` is the safety net, and it is not this story's to build.** ADR-0003
  adds a validation rule that fails loudly when a level ships without these exports;
  that rule belongs to the level-validation epic (`story-003-oxygen-capacity-and-gravity-export-rules.md`).
  This story authors the exports; that story catches the ninth level someone adds later.
  Coordinate ordering with that epic, but do not implement the rule here.
- `LevelRoot` itself is built by the level-state epic under ADR-0002. If it does not yet
  exist when this story is picked up, that epic's `LevelRoot` story is a hard
  prerequisite — this story adds two exports and one call to it, and cannot invent it.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `reset_to()`'s implementation and its initialize guard.
- Story 004: zone and camera wiring (init step 3d).
- Stories 006, 007: prop registration (also step 3d).
- **The `V-GRAV-EXPORT` validation rule** — level-validation epic, story 003.
- **`LevelRoot` itself, `LevelState` and `OxygenState`** — level-state epic, ADR-0002.
  This story extends `LevelRoot`; it does not create it.
- Any change to what `reload_current_scene()` does. Restart stays a plain scene reload.

---

## QA Test Cases

*Story type: **Integration** — spans `LevelRoot`, the authority, and the scene reload
path. The reload case needs a real `SceneTree`; the export-coverage case is a file scan.*

- **AC-1 / AC-2 — the exports exist and are called at step 3c**
  - Given: a level scene instantiated in a headless tree
  - When: `LevelRoot._ready()` completes
  - Then: `GravityAuthority.gravity` matches the level's `default_gravity_direction` at
    `default_gravity_multiplier`
  - Edge cases: assert the *call order* by spying on `validate()` and `reset_to()` —
    `validate()` must have been called first. ADR-0003 D3.1 requires validation to read
    raw authored data before any state is constructed; a `reset_to()` that runs first
    would not break this test's end state but would break that contract silently.

- **AC-3 — all 8 levels declare both exports**
  - Given: every level scene under `src/scenes/` (or wherever levels live)
  - When: the test instantiates each and reads the two properties
  - Then: both exist on every level, `default_gravity_direction` is non-zero, and
    `default_gravity_multiplier` is > 0
  - Edge cases: assert non-zero and positive, not merely present. A level authored with
    the `Vector2()` default would be rejected by the authority's guard at load, which
    presents as "gravity does not initialize on level 6" rather than "level 6 is
    mis-authored". Iterate the level list dynamically — a hardcoded list of 8 silently
    skips the ninth level.

- **AC-4 / AC-5 — restart restores the declared default**
  - Given: a level loaded with `default_gravity_direction = Vector2.DOWN`, then a zone
    entry setting gravity to `Vector2.UP` at `0.5`
  - When: `get_tree().reload_current_scene()` runs and the reloaded tree settles
  - Then: `GravityAuthority.gravity` is back to `Vector2.DOWN` at multiplier `1.0`
  - Edge cases: this is the exact regression ADR-0001 part 6 exists to close, so test it
    from the *changed* state, never from the default state. A reload test that starts at
    the level's default passes whether or not `reset_to()` is called at all. Also reload
    a second time to confirm the path is idempotent rather than first-load-only.

- **AC-6 — no reset method is reintroduced**
  - Given: the project source
  - When: the test greps `src/` for `func reset_level_state`, `func reset(` on
    `LevelState` / `OxygenState`, and `GameManager.reset_level_state`
  - Then: none appear
  - Edge cases: `main.gd` currently calls `GameManager.reset_level_state()` (see
    `main.gd`, the plant-count block). Confirm that call site is gone, not merely that
    the function is. ADR-0002 deletes the function; a surviving caller is a parse error,
    but a surviving *reimplementation* under a new name is not, so grep for the
    behaviour, not only the name.

- **AC-7 — the initialize guard never fires on a correctly wired level**
  - Given: a full level load with a `Player` present
  - When: `_ready()` runs bottom-up to completion
  - Then: no `push_error` from `GravityAuthority`'s initialize guard was raised, and the
    first `gravity_changed` emission carries the level's default
  - Edge cases: test the failure direction too — load a level scene with the `Player`
    removed. `reset_to()` must then be refused with a `push_error` and gravity must stay
    uninitialized, rather than broadcasting at a 1.0 ratio. That is GDD section 5's
    load-bearing init-order hazard, deliberately retained (ADR-0001 Alternative 4), and
    it needs a test that proves the guard is real.

### Manual verification

- [ ] Die-and-restart at a flipped orientation.
  - Setup: run `level_01`, enter a gravity zone that flips gravity, then die on a hazard.
  - Verify: the restarted level begins in the level's authored default orientation, not
    the orientation you died in. Repeat on a level whose default is not straight down.
  - Pass condition: starting orientation matches the level's authored export every time.
  - Record to `production/qa/evidence/level-default-gravity-evidence.md`.

**Estimated test count**: ~24 assertions.

---

### QA-plan addendum — 2026-08-25

*Added by `/qa-plan sprint` (`production/qa/qa-plan-sprint-2.md`). The cases
above are unchanged and remain authoritative; this block records only what the
sprint QA plan adds on top of them.*

- **Manual**: this story closes the gravity migration, so the sprint's one human
  playtest session runs after it lands. Smoke check 13 is its regression
  surface. Evidence
  `production/qa/evidence/playtest-sprint-2-gravity-regression.md`, sign-off
  qa-lead. **An agent-driven session does not settle it** — the bar is
  "indistinguishable from before", which needs a before-memory.
- **Scope guard.** Adding `default_gravity_direction` and
  `default_gravity_multiplier` to the eight level scenes does **not** migrate
  them to the multi-bucket / computed-`O_level` model. QQ-03 stays open and
  unowned. Do not record it as closed by this story.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/gravity/level_default_gravity_test.gd` — must exist and pass
- `production/qa/evidence/level-default-gravity-evidence.md` — die-and-restart check

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (`reset_to()` and the initialize guard), Story 004 (zone wiring
  moved to `LevelRoot`), and **`LevelRoot` from the level-state epic (ADR-0002)** —
  cross-epic; this story extends `LevelRoot` and cannot create it
- Unlocks: None within this epic. Enables the level-validation epic's `V-GRAV-EXPORT`
  rule to have something real to validate
