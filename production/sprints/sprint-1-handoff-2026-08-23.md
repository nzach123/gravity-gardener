# Sprint 1 Handoff — 2026-08-23

> **Branch**: `vertical-slice`
> **Head at handoff**: `a9051fa`
> **Sprint**: 1 (2026-08-18 to 2026-08-31)
> **Stage**: Pre-Production
> **Review mode**: `lean`

## Read this first

This file is a snapshot. The **decisions** in it stay true; the **numbers and
statuses** will not. Before acting on any count, status, or file claim below,
re-derive it from the source:

| Claim | Source of truth |
|---|---|
| Task status | `production/sprint-status.yaml` |
| Story detail | `production/epics/<epic>/story-NNN-*.md` |
| Bug status | `production/qa/bugs/BUG-NNNN.md` |
| Test results | Run the suite (command below) |
| What changed | `git log`, `git diff` |

The live working state is `production/session-state/active.md`, which is
gitignored and therefore **not** in this commit. If you are starting from a
clean checkout, this file is what you have.

---

## Where the sprint actually stands

**5 of 16 tasks complete (31%)**, against roughly 60% of the sprint elapsed.
Burndown: **behind**.

| Status | Tasks |
|---|---|
| Done | TUN-0, LV-0, GA-0, **CLR-1**, **CLR-4** |
| In review | **CLR-3** — code complete, blocked only on a manual editor check |
| Ready | CLR-2, CLR-5, ARCH-1, TUN-1 |
| Backlog | TUN-2, LV-1, LV-2, GA-1, LS-0, QA-1 |

Test suite: **75/75 passing**, 0 errors, 0 failures, 0 orphans, exit 0.
(It was 54/54 at the start of this session.)

---

## What landed this session

Three commits:

| Commit | Contents |
|---|---|
| `8ba0d93` | Model orchestration policy + model tier ID refresh (carried over, doc-only) |
| `a25bd92` | CLR-1 closed, CLR-4 delivered, CLR-3 implemented |
| `a9051fa` | Missing `.uid` for the new test file |

### CLR-1 — CollisionLayers registry *(Complete)*

`src/scripts/collision_layers.gd` verified byte-identical to ADR-0004's
*Key Interfaces* block (`adr-0004-collision-layer-allocation.md:302-331`) apart
from the code fence. `project.godot` `[layer_names]` confirmed: `layer_1="world"`,
`layer_2="player"`, `layer_4="prop"`, no `layer_3`. Warning-clean discovery
confirmed by a full-suite run.

### CLR-4 — Collision layer invariant test suite *(Complete)*

`tests/unit/physics/collision_layers_test.gd` — 21 cases across the five
assertion groups ADR-0004 D4.5 requires.

Three design decisions a future editor of this file needs to know:

- **Bodies are classified by the bits they carry**, not by class name or a
  hardcoded scene list. Group 1's prop-side pairs therefore start covering
  ADR-0011's `PropBody` the moment one is authored, with no change to this file.
  As ADR-0004 predicted, those loops iterate zero times today.
- **The five interactables are named explicitly** (`INTERACTABLE_SCENES`), not
  derived. Classifying a detector by `collision_layer == 0` and then asserting
  it equals 0 would be circular. Group 2's scan stays a directory walk per T4.6.
- **T4.4 is tautological** while `DETECTOR_LAYER` is 0 — nothing can mask a body
  that occupies no layer. It exists for pair-table completeness; the load-bearing
  assertion is `DETECTOR_LAYER` inside
  `test_interactables_are_detectors_that_never_mask_prop`.

**All four blocking negative checks** (ADR-0004 Validation Criterion 1) were run
by hand and reverted. Each turned the suite red:

| Mutation | Test that caught it |
|---|---|
| Platform on PROP layer masking `player` | `test_prop_never_masks_player` |
| `player.tscn` mask → 9 (`WORLD\|PROP`) | `test_player_never_masks_prop` |
| Platform claims retired bit 3 (value 4) | `test_no_scene_uses_an_unallocated_bit` |
| Platform claims unallocated bit 5 (value 16) | `test_no_scene_uses_an_unallocated_bit` |
| `level_03` inline TileSet → layer 2 | `test_every_tileset_physics_layer_is_world` |

The first attempt at the bit-3 check was invalid and was redone: setting
`spike_hazard.collision_layer = 4` tripped the interactable check (test #12)
before group 2 (test #14) ever ran, so it proved the wrong assertion. Re-running
it on the moving platform — which no earlier group classifies — exercised group 2
directly.

### CLR-3 — Remove dead collision configuration *(In Review)*

Deleted: the vestigial `PlayerArea2D` and its child from `player.tscn`, the
now-dangling `col_shape` binding from `player.gd`, and the inert
`collision_mask = 2` from the moving platform's `AnimatableBody2D`.

Both pre-deletion safety checks were re-verified rather than assumed:
`col_shape` had no readers anywhere in `src/` or `tests/`, and no `.tscn`,
`.gd` or `.tres` referenced the `PlayerArea2D` node path.

---

## The one open item on this work

**CLR-3 cannot close until someone opens the editor.** Four checks, none of
which can be done headlessly:

- [ ] `src/scenes/player/player.tscn` opens with **zero** script errors and zero console warnings
- [ ] `src/scenes/moving_platform.tscn` opens clean
- [ ] The moving platform still animates along its configured path, unchanged
- [ ] The player scene runs in a level: movement, jump and gravity flip behave as before

**Why the third one matters.** The deleted mask was inert per ADR-0004 L4 —
an animatable body's own mask is never evaluated for its own motion. So the
platform's behaviour *must* be identical. Any change means something else was
removed by mistake.

When those pass, set CLR-3 to `done` in `sprint-status.yaml`, tick AC-5 in
`story-003-remove-dead-collision-configuration.md`, and record the result in its
Implementation Record section.

---

## Traps this session hit — read before touching CI or tests

### 1. The `.godot` class cache goes stale, and the failure is misleading

The test runner failed to load **at all**:

```
SCRIPT ERROR: Parse Error: Could not find type "GdUnitTestCIRunner"
ERROR: Failed to load script "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"
```

Nothing ran until `--import` was run first. This presents as a *parse error in
the addon*, not as a test failure, which is a confusing way to lose an hour.
A clean CI checkout will hit it.

**Fix**: run an import pass before the test step.

```bash
godot --headless --path . --import
```

This belongs in CLR-5, which owns `.github/workflows/tests.yml`.

### 2. The suite appears to stop at the first failing test

Across five deliberate-failure runs, the executed-case count equalled the index
of the first failing test — 10, 11, 12, 14, 15 out of 21. In CI, **one failure
would mask every later one**, so a red build would under-report the damage.

Cause not investigated. It is a gdUnit4 runner setting, not a defect in the
test file. Also belongs with CLR-5.

### 3. The test command has three non-obvious gotchas

```bash
"/c/00_repos/00-Godot-installer/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" \
  --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode -a res://tests
```

- `Godot_v4.7.1-stable_win64.exe` is a **directory** containing the real binary
  of the same name. The doubled path segment is correct.
- Use `_console.exe`. The plain `.exe` detaches from the console on Windows and
  no output reaches stdout.
- `--ignoreHeadlessMode` is mandatory; without it gdUnit4 exits 103 rather than
  running.

gdUnit4 treats GDScript warnings as errors at **discovery**, so one warning
anywhere fails the entire suite at compile time, not just the offending file.

---

## Correction made to an approved story

`story-003`'s **T3.3** expected `AnimatableBody2D.collision_mask == 0` after the
authored line is deleted, reasoning that removing a property leaves the mask
empty.

That is wrong. `CollisionObject2D.collision_mask` defaults to **`1`**, not `0`.
Probed directly on 4.7.1: `AnimatableBody2D.new()` reports `layer=1 mask=1`, as
do `StaticBody2D`, `Area2D` and `CharacterBody2D`.

ADR-0004 migration step 5 never claimed `0` — it says only "delete
`moving_platform.tscn:16`, which per L4 does nothing." The deletion is still
correct, because L4 makes the residual `1` exactly as inert as the `2` it
replaced. Only the test expectation was wrong.

Corrected **in place, before implementing**, so the wrong expectation never
drove code. Had it not been caught, CLR-4's group 5 would have failed against a
correct implementation of CLR-3. The ADR was not touched.

---

## Decisions carried forward

1. **Code review is deferred, not skipped.** Lean mode skips the automated
   `LP-CODE-REVIEW` gate. `/code-review` on `collision_layers.gd` and
   `collision_layers_test.gd` was explicitly deferred to sprint close-out by
   developer decision. Run it before closing the sprint.
2. **GA-1 is under-estimated.** The gravity-authority epic broke into 7 story
   files against a 1.75-day estimate. Re-estimate or confirm the cut. GA-1 is
   the sprint plan's declared cut line, so cutting it does not break the goal.
3. **Task granularity no longer matches the story files.** TUN-2 and LV-1 are
   each one task in the yaml but now map to several story files. `/sprint-plan
   update` resolves this; a status re-sync does not.
4. **No QA plan exists.** QA-1 is Nice-to-Have in the plan, but the sprint
   Definition of Done requires `production/qa/qa-plan-sprint-1.md`. Run
   `/qa-plan sprint` before the last story is implemented.

---

## Next steps, in order

1. **Smoke-check CLR-3** in the editor (four checks above), then close it.
2. **CLR-2 — BUG-0001**, 0.25d. The mechanism is confirmed: `KillArea2D` in
   levels 05 and 06 declares no mask, so it defaults to `1` (`WORLD`) while the
   player is on layer `2`. `1 & 2 == 0`, so `body_entered` is structurally
   incapable of firing. Needs a **human playtest** of the fix — agent playtests
   do not judge out-of-bounds falls reliably.
3. **CLR-5 — CI grep**, 0.15d, plus the two CI problems in *Traps* above.
4. **TUN-1 — the `@export_range` spike**, 0.5d. This is the real schedule risk.
   It heads the longest chain in the sprint (TUN-1 → TUN-2 → LV-1, 3.25
   sequential Must-Have days) and the CLR work is **not** on the critical path.
5. **`/sprint-plan update`** — resolves carried decisions 2 and 3.
6. **`/qa-plan sprint`** — resolves carried decision 4.

---

## Things that are not obvious from the repo

- `prototypes/gravity-gardener-vertical-slice/` holds working
  `gravity_authority.gd`, `tuning/` and `level_validation.gd`. That is throwaway
  vertical-slice code. It does **not** count as sprint delivery, but it is a
  useful reference implementation for TUN-2, LV-1 and GA-1.
- Review mode is `lean` (`production/review-mode.txt`). Non-phase-gate director
  reviews are skipped.
- `production/session-state/` and `production/session-logs/` are gitignored, so
  nothing in them survives a clean checkout.
