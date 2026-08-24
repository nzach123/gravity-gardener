# Story 002: Fix BUG-0001 — dead kill-plane masks on levels 05 and 06

> **Epic**: Collision Layer Registry
> **Status**: In Review
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: S (1-2 hours, plus a playtest of both levels)
> **Manifest Version**: 2026-08-17
> **Last Updated**: 2026-08-23

## Context

**GDD**: `design/gdd/hazards.md`
**Requirement**: R9 — "Every hazard's collision mask must include the player's
layer." Governed by ADR-0004. hazards.md R9 names this exact defect:
"⚠ BUG-0001: the kill areas in level_05 and level_06 mask world(1) while the
player is on layer 2, so 1 & 2 == 0 and they never fire."
**No TR-ID**: `hazards.md` postdates the TR registry's last sweep — no
`TR-hazards-*` entries exist yet in `docs/architecture/tr-registry.yaml`.
(The story previously cited `TR-props-002`/`physics-props.md`, but that
requirement governs prop-cosmetic isolation from the player — an unrelated
rule. Corrected during `/story-readiness`.)

**ADR Governing Implementation**: ADR-0004: Collision layer allocation
**ADR Decision Summary**: `KillArea2D` in levels 05 and 06 declares neither
`collision_layer` nor `collision_mask`, so both default to `1` (`world`). The
player is on layer `2`. `Area2D.body_entered` gates only on the area's mask
against the body's layer (L1), and `1 & 2 == 0`, so the signal can never fire.
The fix is the standard detector idiom: `collision_layer = 0`,
`collision_mask = 2` (PLAYER).

**Engine**: Godot 4.7.1 | **Risk**: LOW
**Engine Notes**: Same verified-unchanged 2D physics basis as story 001. L1
(`Area2D.body_entered` gates on the area's mask against the body's layer, and
nothing else — `godot_area_pair_2d.cpp:36`) is the specific engine fact this
fix depends on, verified against engine source at the 2026-08-14 specialist
gate.
**Performance**: No performance impact expected — the mask change only
enables an existing `Area2D` overlap check already running each physics
step; no new bodies, shapes, or per-frame work are added.

**Control Manifest Rules (this layer)**:
- Required: "All detector `Area2D`s (`Bucket`, `Plant`, `Goal`, `GravityZone`,
  `SpikeHazard`, `KillArea2D`) carry `collision_layer = 0`,
  `collision_mask = 2` (PLAYER) — detectors need no layer of their own." —
  source: ADR-0004
- Required: "Verify both mask directions for every isolation guarantee.
  Body-vs-body pairing is an OR, not an AND — a one-sided mask mistake still
  produces contact." — source: ADR-0004 (L3)

---

## Acceptance Criteria

*From `docs/qa/bugs/BUG-0001.md` and ADR-0004 Validation Criterion 4, scoped to
this story:*

- [x] `level_05.tscn`'s `KillArea2D` node has `collision_layer = 0` and
      `collision_mask = 2` explicitly set.
- [x] `level_06.tscn`'s `KillArea2D` node has `collision_layer = 0` and
      `collision_mask = 2` explicitly set.
- [x] A player falling out of bounds in level 05 triggers
      `_on_kill_area_2d_body_entered`, and the level restarts.
- [x] A player falling out of bounds in level 06 triggers the same handler,
      and the level restarts.
- [ ] Both levels are manually played through the out-of-bounds fall at least
      once each — this is a **live behaviour change** (the kill plane has
      never fired before), not a configuration-only fix. Record the playtest
      as evidence.

---

## Implementation Notes

*Derived from ADR-0004 Migration Plan step 3 and BUG-0001:*

- This is purely a `.tscn` node-property change in two files —
  `src/scenes/levels/level_05.tscn:386` and
  `src/scenes/levels/level_06.tscn:392`. No script changes.
- Set `collision_layer = 0` and `collision_mask = 2` on each `KillArea2D`
  node, matching the same detector idiom already used correctly by `Bucket`,
  `Plant`, `Goal`, `GravityZone`, and `SpikeHazard` in this codebase.
- **This changes live behaviour, not just configuration.** Levels 05 and 06
  have only ever been played with the kill plane dead — a fall that currently
  strands the player will now restart the level. This is the intended
  design (per `physics-props.md` and the GDD's kill-plane contract), but it
  must be playtested before this story can close, not just unit-tested.
- `tests/integration/main/kill_area_death_test.gd` already exists as a
  **characterization test** written ahead of this fix. Its first test,
  `test_kill_area_currently_does_not_kill_player_bug_0001`, currently asserts
  `player.player_died` is **false** — pinning today's bug. Once this story's
  fix lands, flip that assertion to `is_true()` and rename the test to
  `test_kill_area_kills_player_bug_0001_fixed` (or similar) so the test name
  no longer claims the bug is live. Do not delete it — the comment in the file
  explicitly says it becomes the regression guard.
- That file currently covers only `level_05.tscn`. Add an equivalent
  physics-based test for `level_06.tscn` — level_06 has no coverage today.
- The file's second test, `test_kill_area_handler_kills_player_and_resets_state`,
  bypasses physics and pins the handler logic (`main.gd`'s
  `_on_kill_area_2d_body_entered`). That handler is unaffected by this story
  and needs no changes — leave it as-is.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: creating `collision_layers.gd` (this story uses the literal
  values `0` / `2` directly in the scene files, consistent with — but not
  dependent on — story 001's constants).
- Story 003: the vestigial `PlayerArea2D` and dead `moving_platform.tscn`
  mask — unrelated defects, do not fix them here.
- Whether `KillArea2D` should also mask `prop` (mask `10`) — explicitly
  deferred to ADR-0011 (physics props implementation). Do not add this now.

---

## QA Test Cases

*Generated by `/qa-plan sprint` on 2026-08-18. Story type: **Integration**.*

**Test file**: `tests/integration/main/kill_area_death_test.gd` — extend the
existing characterization test, do not create a new file.

### Authored-state cases (headless, no `SceneTree`)

Instantiate each level via `PackedScene.instantiate()` (L5 — properties are
populated without `_ready()`), assert, then free.

| # | Case | Expected |
|---|---|---|
| T2.1 | `level_05.tscn` → `KillArea2D.collision_layer` | `== 0` |
| T2.2 | `level_05.tscn` → `KillArea2D.collision_mask` | `& CollisionLayers.PLAYER != 0` — bit test, not `== 2` (D4.5/F6) |
| T2.3 | `level_06.tscn` → `KillArea2D.collision_layer` | `== 0` |
| T2.4 | `level_06.tscn` → `KillArea2D.collision_mask` | `& CollisionLayers.PLAYER != 0` |
| T2.5 | Both levels, mask vs. player layer | `mask & player_layer != 0` — asserts the *defect class*, not the literal fix. This is the assertion that would have caught BUG-0001 |

### Behavioural cases (physics-based)

| # | Case | Expected |
|---|---|---|
| T2.6 | Level 05: player falls out of bounds | `_on_kill_area_2d_body_entered` fires; `player.player_died` is `true` |
| T2.7 | Level 06: player falls out of bounds | Same. **No coverage exists for level 06 today — this case is new** |
| T2.8 | Existing `test_kill_area_handler_kills_player_and_resets_state` | Unchanged and still passing. The handler is not touched by this story |

### Characterization-test migration (required, not optional)

`test_kill_area_currently_does_not_kill_player_bug_0001` currently asserts
`player.player_died` is **false**, pinning the live bug. Once the fix lands:

- [ ] Flip the assertion to `is_true()`
- [ ] Rename to `test_kill_area_kills_player_bug_0001_fixed`
- [ ] **Do not delete it** — the in-file comment designates it the regression guard

A test whose name still claims the bug is live is worse than no test, because
it will be read as a known-failure exemption later.

### Edge cases

| Case | Expected | Source |
|---|---|---|
| Kill-area contact on the frame `level_complete` latches | No death — the flag wins | `hazards.md` §5, `level-flow.md` R7 |
| Kill-area contact and oxygen depletion on the same frame | Exactly one restart, not two | `hazards.md` §5, `level-flow.md` R9 |
| Player dies while carrying a bucket | Carry state cleared by full reset | `hazards.md` §5, `level-flow.md` R8 |

⚠ **The three edge cases above are specified but not implementable this sprint.**
`level_complete` and the death chokepoint are owned by ADR-0005 (`level-state`
epic, Sprint 2) and `level-flow.md` (`level-outcomes`, unscheduled). Record them
here so they are not lost; do not block this story on them.

### Manual verification — REQUIRED, blocking

**Verification method**: playtest. **Who signs off**: nzach123.
**Evidence to**: `production/qa/evidence/` (see below).

This is a **live behaviour change**, not a configuration fix. Levels 05 and 06
have only ever been played with the kill plane dead; a fall that currently
strands the player will now restart the level. ADR-0004 Validation Criterion 4
requires human verification.

- [ ] Level 05: fall out of bounds. The level restarts, and the restart is clean —
      no stranding, no double-restart, no stuck camera
- [ ] Level 06: same
- [ ] Neither level has an in-bounds location where the kill plane fires
      unexpectedly (R2 — a kill area inside playable space is forbidden and is
      not automatically detectable)

*This playtest is a binary did-it-restart check, not a pacing or feel judgement,
so it is one of the few that does not strictly require a human. The story and the
ADR both call for one anyway — the third item above is a spatial-authoring check
that genuinely needs eyes on the level.*

**Estimated test count**: ~8 assertions across 4 test functions (2 new, 1 migrated,
1 unchanged), plus 1 playtest session.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/[system]/[story-slug]_test.[ext]` OR documented playtest

This story requires **both**: the updated/extended
`tests/integration/main/kill_area_death_test.gd` (automated regression guard
for BUG-0001, covering level_05 and level_06), **and** a documented playtest
of both levels' out-of-bounds fall, since the fix is a live behaviour change
that the ADR explicitly calls out as needing human verification, not just a
passing test.

**Status**: [x] Automated regression guard landed and passing. [ ] Playtest outstanding (AC-5).

---

## Dependencies

- Depends on: Story 001 (registry establishes the canonical bit values this
  fix uses — not a hard code dependency, but land after it for a coherent
  history)
- Unlocks: None

---

## Implementation Record

*Written 2026-08-23.*

### What changed

| File | Change |
|---|---|
| `src/scenes/levels/level_05.tscn` | `KillArea2D` gains `collision_layer = 0`, `collision_mask = 2` |
| `src/scenes/levels/level_06.tscn` | Same |
| `tests/integration/main/kill_area_death_test.gd` | Characterization test migrated; level_06 coverage added; authored-state cases T2.1-T2.5 added |

No script changes, as the story specified.

### Test results

Full suite: **81/81 passing**, 0 errors, 0 failures, 0 orphans, exit 0.
The suite was 75/75 before this story, so all 6 new cases are accounted for.

The characterization test was migrated as required, not deleted:
`test_kill_area_currently_does_not_kill_player_bug_0001` flipped to
`is_true()` and was renamed `test_kill_area_kills_player_bug_0001_fixed`.
`test_kill_area_handler_kills_player_and_resets_state` was left untouched.

### The new guards were confirmed to be load-bearing

A passing test proves nothing until it has been seen to fail. `level_05`'s
`collision_mask` was reverted to `1` (the bug) and the suite re-run:

- `test_level_05_kill_area_masks_the_player` — **FAILED**, exit 100
- `test_kill_area_kills_player_bug_0001_fixed` — **FAILED**, exit 100, run in
  an isolated scratch suite because the runner stops at the first failure and
  never reached it in the full file

The mask was restored and the scratch suite deleted. Both guards therefore
depend on the fix rather than passing vacuously.

Note for whoever automates this: `-a "res://path/to/test.gd:test_name"` is
**not** a supported selector. It exits `0` having executed nothing, which
reads exactly like a pass. Isolate a single test with a scratch suite instead.

### Open — blocks Complete

**AC-5, the playtest, is not done.** This is a live behaviour change: a fall
that used to strand the player now restarts the level. Three checks are owed,
and the third cannot be automated at all:

- [ ] Level 05: fall out of bounds. The level restarts cleanly — no stranding,
      no double restart, no stuck camera
- [ ] Level 06: same
- [ ] Neither level has an in-bounds spot where the kill plane fires
      unexpectedly (R2 — a kill area inside playable space is forbidden and is
      not automatically detectable)

Evidence goes to `production/qa/evidence/`. Sign-off: nzach123.
`BUG-0001` stays `Open` until then.
