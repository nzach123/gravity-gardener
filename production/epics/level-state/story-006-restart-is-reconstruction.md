# Story 006: Restart is reconstruction — `GameManager` keeps only `player_lives`

> **Epic**: Level State Ownership
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: M (2-3 h)
> **Manifest Version**: 2026-08-17
> **Last Updated**: (set by /dev-story when implementation begins)

## Context

**GDD**: `design/gdd/watering-system.md` §5 · §8 AC8 ·
`design/gdd/suit-oxygen.md` §3 R5 · §8 AC4, AC5
**Requirement**: `TR-watering-011`, `TR-oxygen-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002: Level State Ownership and Injectable
State Objects (part 2 and part 6)

**ADR Decision Summary**: **Restart is reconstruction, not reset.**
`restart_level()` becomes `reload_current_scene()` alone. The reload destroys
`LevelRoot`, which drops the last reference to both state objects; the new
`LevelRoot._ready()` constructs fresh ones. `reset_level_state()` is **deleted**,
and neither state object has a `reset()` method. This is the substantive win of the
whole epic: `watering-system.md` AC8 and `suit-oxygen.md` AC4/AC5 stop being things
a reset function must remember and become properties of object lifetime. The
`carrying_bucket` defect class is not fixed — it is made unrepresentable.
`GameManager` retains only `player_lives`.

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**:

- **`reload_current_scene()` frees the old scene and runs the new tree's `_ready()`
  bottom-up**, so the fresh `LevelRoot._ready()` reconstructs everything. Pre-4.4
  and unchanged through 4.7.
- **Reconstruction works only because every strong holder is freed in the same
  synchronous teardown pass as `LevelRoot`** — the A2-03 invariant story 004
  records. A holder outside that subtree keeps a stale `LevelState` alive with no
  error and no crash. `RefCounted` leaks are invisible and there is no watchdog.
- **`== null` is TRUE for a freed `Object` held in a Variant on 4.7.1, and
  `value as Node` on a freed object RAISES "Trying to cast a freed object".** A
  plain null check already catches a freed object; `as` is not a safe probe.
  Established 2026-08-24 — relevant to any test here that asserts teardown.

**Control Manifest Rules (this layer)**:
- Required: "Restart = `reload_current_scene()` alone. No `reset()` methods
  anywhere; restart correctness is object lifetime, not a hand-maintained clear
  function." — ADR-0002
- Required: "Every level must declare `default_gravity_direction` /
  `default_gravity_multiplier` exports on `LevelRoot`; `GravityAuthority.reset_to()`
  is called from `LevelRoot._ready()` (**not** `GameManager`)." — ADR-0001,
  amended by ADR-0002
- Forbidden: "Never add `reset()` to `LevelState` or `OxygenState`, or reintroduce
  `GameManager.reset_level_state()`." — ADR-0002 (`level_state_reset_method`)
- Forbidden: "Never reach level or oxygen state through an autoload, a new
  singleton, or a service locator." — ADR-0002 (`global_level_state_access`)

---

## Acceptance Criteria

*From `design/gdd/watering-system.md` and `design/gdd/suit-oxygen.md`:*

- [ ] **watering AC8** — after a level restart: carry state cleared, all buckets
      present, every plant reads `buckets_received == 0`
- [ ] **oxygen AC4** — restart resets `oxygen_remaining` to `oxygen_capacity`
- [ ] **oxygen AC5** — oxygen does not carry between levels
- [ ] `GameManager.reset_level_state()` no longer exists, and nothing calls it
- [ ] `GameManager` holds only `player_lives`; the level-scoped fields it carried
      (`plants_total` and the rest) are gone
- [ ] `restart_level()` is `reload_current_scene()` and nothing else
- [ ] No `reset()` or `clear()` method exists on `LevelState` or `OxygenState`

---

## Implementation Notes

*Derived from ADR-0002 parts 2 and 6:*

- **`main.gd:31` currently calls `GameManager.reset_level_state()`, and
  `main.gd:32-33` seeds `GameManager.plants_total` from a group scan.** Both go.
  Story 004 replaced the plant discovery with a type scan feeding
  `LevelState`; this story removes what is left on the autoload.
- **`GameManager` is out of scope by user decision beyond `player_lives`.** It
  appears in no GDD and is read nowhere else in `src/`; whether `player_lives` is
  ever specified or the autoload is deleted outright is **deferred, not decided**.
  Do not decide it here. Reduce it to `player_lives` and stop.
- **`tests/unit/gamemanager/gamemanager_test.gd` exists and will need updating.**
  Removing fields it asserts will turn it red. Update it as part of this story —
  do not delete a test to make the suite pass. If a test's whole subject is
  removed, remove that test case and say so in the completion notes.

### The ADR-0001 correction — its own approval, never bundled

The epic's Definition of Done requires it, and ADR-0002 states the reason:
`GameManager.reset_level_state()` ceases to exist under this decision, and the
`GravityAuthority.reset_to()` call moves to `LevelRoot._ready()`. Two documents
still name the old caller:

1. `docs/architecture/adr-0001-*.md` — **part 6 prose**
2. `docs/registry/architecture.yaml` — entry `state_ownership.level_default_gravity`,
   which says level gravity is restored "via `GravityAuthority.reset_to()` from
   `GameManager.reset_level_state()`"

**Behaviour does not change** — `restart_level()` already reloads the scene, which
re-runs `LevelRoot._ready()`. This is a caller-name correction, nothing more.

Three process constraints on it:

- **Ask for the ADR edit as its own approval.** Never bundle an ADR edit with a
  code change in one approval request.
- **This is a correction in place, not a supersession.** The registry's convention,
  settled 2026-08-15, is that correcting text which never matched its source is not
  a supersession — supersession would falsely imply the entry once said the right
  thing. Follow `docs/architecture/tr-registry.yaml`'s `corrected:` key convention.
- **Do not widen it.** ADR-0002 names exactly two locations. If a third turns up,
  report it rather than fixing it silently.

---

## Out of Scope

*Handled by neighbouring stories and epics — do not implement here:*

- **Stories 001-005**: the types, the injection, the latch.
- **`restart_level()`'s `_transition_pending` chokepoint guard (ADR-0005 D5.4)** —
  the `level-outcomes` epic. This story makes `restart_level()` a bare
  `reload_current_scene()`; that epic wraps it in the guard. **The two are
  compatible and must land in that order.**
- **The death paths that call `restart_level()`** — `spike_hazard`'s
  `inc_hazard_dmg`, `_on_kill_area_2d_body_entered`, and `OxygenDrain`. They keep
  calling it; this story does not change any of them.
- **Deciding the fate of `player_lives` or of `GameManager` itself** — deferred by
  user decision.
- **The level transition (`change_level`)** — `level-outcomes`.

---

## QA Test Cases

*Story type: **Integration** — automated test specs.*

- **AC-1 — a restart produces fresh state, not cleared state**
  - Given: a level whose `LevelState` has consumed buckets and `carrying_bucket`
    true, and whose `OxygenState` is partly drained
  - When: the scene is reloaded
  - Then: the new `LevelState` reads zero consumed and `carrying_bucket` false, and
    the new `OxygenState` reads `remaining == capacity`
  - Edge cases: assert the new objects are **different instances**, not the same
    objects with reset fields. That distinction is the entire decision.

- **AC-2 — the old state objects are released**
  - Given: a reference to the pre-restart `LevelState`
  - When: the reload completes
  - Then: the old object is gone
  - Edge cases: use a plain null check. `as` on a freed object raises on 4.7.1.

- **AC-3 — no reset path exists anywhere**
  - Given: `src/**/*.gd`
  - When: searched for `reset_level_state`, and for `reset(`/`clear(` on the two
    state types
  - Then: no match
  - Edge cases: structural, and worth keeping: `level_state_reset_method` is a
    registered forbidden pattern precisely because re-adding one looks like a
    reasonable convenience when a future bug appears.

- **AC-4 — `GameManager` holds only `player_lives`**
  - Given: the `GameManager` script
  - When: its members are inspected
  - Then: `player_lives` is present and no level-scoped field is
  - Edge cases: `tests/unit/gamemanager/gamemanager_test.gd` must be updated in the
    same story, not left red and not deleted wholesale.

- **AC-5 — oxygen does not carry between levels**
  - Given: a level drained to half oxygen
  - When: a *different* level scene is loaded
  - Then: the new level's `OxygenState` reads `remaining == capacity` for that
    level's own authored capacity
  - Edge cases: assert against the **new** level's capacity, not the old one.
    A test that uses one capacity for both levels passes even if the value carried.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/level_state/restart_reconstruction_test.gd` — must exist and pass
- `tests/unit/gamemanager/gamemanager_test.gd` — updated and passing

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 DONE. Removing `reset_level_state()` before `LevelRoot`
  constructs the replacement state leaves the level with no state at all.
- Unlocks: `level-outcomes`, which wraps the now-bare `restart_level()` in the
  D5.4 chokepoint guard.
