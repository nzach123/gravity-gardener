# ADR-0013: Screen-relative input basis

## Status

**Accepted** — 2026-08-18

Escalated from `godot-specialist` to `technical-director` per
`.claude/docs/coordination-rules.md` Rule 3, as the resolution of the open conflict
between ADR-0007 D7.4 and `design/gdd/gravity.md` R11. Recorded as open item 1 in
`production/gate-checks/gate-check-2026-08-17-pre-production-c.md`.

## Date

2026-08-18

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.7.1 |
| **Domain** | Core (static typing, autoload access), 2D rendering adjacent (`Camera2D`, `Viewport`) |
| **Knowledge Risk** | **LOW.** `Vector2.rotated()` and `signf()` are stable 4.0 APIs and are already used in `src/`. `Camera2D.ignore_rotation` is used today at `main.gd:13`, so it is confirmed present. `Viewport.get_camera_2d()` is not covered by any file in `docs/engine-reference/godot/modules/`, and was verified against the official class documentation instead. See Verification Required. |
| **References Consulted** | `docs/engine-reference/godot/modules/core.md`, `docs/engine-reference/godot/modules/physics-2d.md`, plus ADR-0001, ADR-0005 and ADR-0007 |
| **Post-Cutoff APIs Used** | None. Every API named here predates the 4.3 training boundary. |
| **Verification Required** | **None outstanding.** `Viewport.get_camera_2d()` was verified on 2026-08-18 against the official `Viewport` class documentation: in 2D a camera is not required to be current, and when none is, the method returns `null`. It was added for 4.0 in `godotengine/godot#38317`. D13.3's null fallback is therefore sound. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted — `GravityAuthority` owns `gravity`/`up_dir`/`right_dir` and is their sole writer). ADR-0007 (Accepted — establishes the eight-step physics order and the one-shared-function rule this ADR keeps). Both stay Accepted and neither is reopened. |
| **Supersedes** | The **method contract** of ADR-0007 D7.4 only. `GravityAuthority.apply_camera_relative_axis(input_axis, right_dir, camera_rotation_enabled)` is replaced by `apply_screen_relative_axis(input_axis, right_dir, camera_rotation)`. Recorded in `docs/registry/architecture.yaml` by the supersession mechanism the registry already uses for `level_default_gravity` (ADR-0002 superseding an ADR-0001 entry, `architecture.yaml:52-66`). **ADR-0007's Status stays Accepted and its text is not edited.** D7.4's stance — exactly one axis-inversion function, two callers — is preserved intact. |
| **Enables** | The camera follow/rotate split (`TR-gravity-010`, `accessibility-requirements.md` A7 and T8, `hud.md` Q10 and Finding 1). This ADR closes the input-basis leg permanently and takes ownership of the remaining two legs. |
| **Blocks** | Nothing currently in flight. |

## Context

### Problem Statement

Two approved documents give opposite answers for the same gravity vector.

ADR-0007 D7.4 gates the screen-relative axis correction on a boolean,
`camera_rotation_enabled`. `gravity.md` R11 (amended 2026-08-17) states the
correction "holds unconditionally" and "does not depend on whether the level rotates
the camera", and its §4 formula carries no camera term. `gravity.md` §5 flags the
disagreement against itself, and `control-manifest.md:309` carries a ⚠ reading
"D7.4 needs a ruling".

The geometry decides it. `right_dir = up_dir.rotated(90°) = gravity_dir.rotated(-90°)`,
and the camera's world-space local-x axis at its full `target_rotation` is the same
vector. So when the camera has rotated to match gravity, `right_dir` **is** camera-local
right, and the raw axis is already screen-relative. When the camera has not rotated,
world axes are screen axes, and the correction is required.

Worked at gravity-up (`right_dir = (-1, 0)`):

| Viewport | D7.4 raw axis | R11 unconditional `screen_sign` |
|---|---|---|
| Rotated to match gravity | `move_right` → screen right ✅ | `move_right` → screen **left** ❌ |
| Not rotated | `move_right` → screen **left** ❌ | `move_right` → screen right ✅ |

Neither document is wholly right. Three further facts shape the decision.

1. **D7.4 reads a flag that describes nothing.** Only `camera_moving` mutates
   `camera_2d.rotation` (`main.gd:37-41`), and it gates camera-follow as well
   (`main.gd:44`). `camera_rotation_enabled` (`main.gd:9`) is forwarded once to
   `player.camera_rotation_enabled` at `main.gd:15` and touches no camera. The two
   flags are co-set to `true` in `level_01.tscn:28-29` and `level_07.tscn:32-33` by
   authoring habit. Levels 02–06 and 08 set neither. The shipped game is therefore
   correct today by coincidence, not by construction.
2. **R11's evidence covers one camera configuration.** R11 cites the vertical-slice
   tester's rejection of mirrored controls. `prototypes/gravity-gardener-vertical-slice/`
   has no camera-rotation wiring at all, and `player.gd:94-98` there applies
   `Input.get_axis()` directly against `right_dir`. The tester played a static camera.
   Their verdict is correct and is not overturned here — it is the unrotated row of
   the table above.
3. **A boolean cannot describe a camera mid-tween.** The camera rotates on a fixed
   600 ms `TRANS_SINE` tween (`main.gd:41`). Gravity direction eases at
   `clamp(32 · Δt, 0, 1)`, which converges in roughly 100 ms and satisfies
   `gravity.md` AC5. For about 500 ms after every flip in `level_01` and `level_07`,
   `right_dir` has settled while the camera has not. Neither existing formula is
   correct in that window.

### Constraints

- ADR-0007 D7.4's stance — exactly one axis-inversion function, two callers, so
  `TR-gravity-013` holds by construction — must survive. It is the reason
  `TR-gravity-013` is `covered`.
- `gravity.md` R11's **rule** is approved, `verified-by: nzach123`, and sourced to a
  human playtest. Its rule text must not change.
- The registry's `private_gravity_copy` forbidden pattern bans caching a gravity value.
  Any camera value read here is read live and stored in no surviving field.
- The frame-ordering contract (`-100` / `0` / `+100`, ADR-0005) is closed. This ADR
  works inside the `0` slot.
- `docs/registry/architecture.yaml` is append-only for changed stances.
- The project's standing precedent for changes to shipped level data is
  ADR-0011 D11.6: specify the fix, do not apply it until a playtest runs.

### Requirements

- One formula must give the correct screen-relative mapping at every gravity angle,
  under a rotated camera, an unrotated camera, and a camera partway between.
- The formula must reduce exactly to `gravity.md` R11's §4 formula when the camera
  is unrotated, so the GDD and the code agree by construction rather than by review.
- The axis-inversion formula must continue to exist in exactly one place.
- `camera_rotation_enabled` must stop existing as an independent lever, because no
  setting of it and `camera_moving` together can satisfy `accessibility-requirements.md` T8.

## Decision

### D13.1 — "Screen-relative" means the camera's frame, not the world's

`gravity.md` R11 is upheld as written: a movement key always moves the player the
same direction on screen, at every gravity angle, unconditionally. This ADR changes
nothing about that rule.

What this ADR fixes is the *reference frame* the word "screen" names. The screen is
whatever the camera currently shows. When the camera is rotated, screen axes are not
world axes, and a formula written in world axes does not produce a screen-relative
result. R11's §4 formula is the correct expression of R11 for an unrotated camera and
is a special case, not the general law.

### D13.2 — One formula, parameterised by the camera's actual rotation

`GravityAuthority` gains a stateless static method. It replaces
`apply_camera_relative_axis` from ADR-0007 D7.4.

```gdscript
# static: no self access — pure function of its parameters, not autoload state.
# Colocated here because right_dir is the only gravity-derived input and
# GravityAuthority already owns it.
static func apply_screen_relative_axis(
    input_axis: float, right_dir: Vector2, camera_rotation: float
) -> float:
    var rd_screen: Vector2 = right_dir.rotated(-camera_rotation)
    if not is_zero_approx(rd_screen.x):
        return input_axis * signf(rd_screen.x)
    return input_axis * -signf(rd_screen.y)
```

`PlayerMovementComponent.apply()` and `PlayerVisualComponent.update()` both call it.
ADR-0007 D7.4's one-function guarantee is preserved unchanged.

**Why this is the general law.** Two endpoints, both checked:

- `camera_rotation == 0.0` gives `rd_screen == right_dir`, and the body becomes
  `gravity.md` §4's `screen_sign` formula character for character.
- `camera_rotation == Vector2.DOWN.angle_to(gravity_dir)` (camera fully turned) gives
  `rd_screen` an angle of zero, so `rd_screen == (1, 0)`, so the result is the raw
  `input_axis` — ADR-0007 D7.4's `camera_rotation_enabled == true` branch.

It is also exact at every value between, which is what removes the 500 ms window
named in Context fact 3.

**A side effect worth recording.** `gravity.md` §5's "Mid-transition input" row claims
the walk direction "never crosses to the opposite half of the screen". Under this
formula the effective screen walk vector is `screen_sign · rd_screen`, whose
x-component is `|rd_screen.x| ≥ 0` by construction. The GDD's existing claim becomes
true rather than needing to be weakened.

### D13.3 — `camera_rotation` is read live, once per frame, by the `Player` facade

`Player._physics_process` reads it at step 1, alongside `gravity`, `up_dir` and
`right_dir`, and threads it into steps 6 and 8:

```gdscript
var cam: Camera2D = get_viewport().get_camera_2d()
var camera_rotation: float = cam.rotation if cam != null else 0.0
```

Three properties of this choice:

- **No stored field.** The value is a local, re-read every frame, clear of the
  `private_gravity_copy` ban and of ADR-0007 D7.1's freshness rule for the same reason
  gravity is.
- **The null fallback is the GDD.** With no camera, `camera_rotation` is `0.0`, and
  D13.2 degrades exactly to `gravity.md` §4. A headless test with no camera therefore
  exercises the GDD's own formula, which is what `TR-gravity-013`'s tests should assert
  against.
- **`Camera2D.ignore_rotation` is a precondition.** `main.gd:13` sets it `false`, so
  the node's rotation reaches the viewport. If a level ever set it `true`, the camera
  node could rotate while the view did not, and `cam.rotation` would stop describing the
  screen. Recorded as a risk below, not guarded in code.

### D13.4 — `camera_rotation_enabled` is deleted

The export at `main.gd:9`, the forward at `main.gd:15`, and the field at `player.gd:60`
are removed. Both call sites take `camera_rotation` instead.

This is not tidying. With rotation and follow both gated on `camera_moving`
(`main.gd:37`, `main.gd:44`), and the input basis gated on `camera_rotation_enabled`,
no combination of the two flags satisfies `accessibility-requirements.md` T8
("disable the 0.6 s viewport rotation **without** disabling camera-follow and
**without** leaving the input basis inverted"):

| `camera_moving` | `camera_rotation_enabled` | Rotates | Follows | Controls | T8 |
|---|---|---|---|---|---|
| true | false | yes | yes | double-corrected, inverted | fails twice |
| false | true | no | no | raw axis on a static camera, inverted | fails twice |
| false | false | no | no | correct | fails on follow |
| true | true | yes | yes | correct | fails on rotation |

T8 is unreachable in data. A7 is a proof that a code change is required, not an
untidiness. D13.4 removes one of the three legs by making the input basis a function
of the camera's real state rather than of any flag.

A new forbidden pattern, `input_basis_gated_on_boolean_camera_flag`, is appended to
`docs/registry/architecture.yaml` so the shape cannot return.

### D13.5 — The camera follow/rotate split is specified. It is not applied here

The remaining two legs need `camera_moving` split in two:

- `camera_follow_enabled` — gates `camera_2d.global_position` tracking (`main.gd:44`)
- `camera_rotates_with_gravity` — gates the rotation tween (`main.gd:37`)

`level_01.tscn` and `level_07.tscn` set both to `true` to preserve today's behaviour.
Levels 02–06 and 08 set `camera_follow_enabled = false`, matching today. T8 then
becomes reachable: `camera_follow_enabled = true` with
`camera_rotates_with_gravity = false`, and D13.2 keeps the controls correct because it
reads the camera's actual rotation rather than a flag.

**This ADR specifies the split and does not apply it**, following the precedent
ADR-0011 D11.6 set for BUG-0001. Applying it changes live camera behaviour in the
tutorial level and in `level_07`, which needs a human playtest, not an architecture
decision. Memory `agent-playtest-pacing-unreliable` records that agent-driven playtests
are not trusted for feel judgments in this project.

**Owner: `technical-director`, gated on a human playtest.** This replaces
"Unassigned" in `requirements-traceability.md` item 3.

### D13.6 — What is deliberately left open

- **The 600 ms camera tween against the ~100 ms gravity ease.** After D13.2 the input
  basis is correct throughout the mismatch, so this stops being a correctness question
  and becomes a feel question. Flagged for `game-designer`; the tween duration should
  surface as a tuning knob in `gravity.md` §7. Not decided here.
- **The instantaneous sign flip when `rd_screen.x` crosses zero.** Inherent to any
  sign-based mapping, lasts one frame, and `gravity.md` §5's "Gravity exactly horizontal"
  row already owns it. No action.
- **The camera's first-broadcast gap.** Recorded in ADR-0011's Flagged gap section.
  Adjacent but separate. Still unassigned.

### Architecture Diagram

```
GravityAuthority  (process_physics_priority = -100)
  ease → gravity, up_dir, right_dir, ascent/descent mags finalized for this frame
         │
         ▼  (same frame, guaranteed prior — frame_ordering_contract)
Player  (process_physics_priority = 0)
  ┌─────────────────────────────────────────────────────────────────┐
  │ 1. read GravityAuthority.gravity / up_dir / right_dir     (D7.1)│
  │    up_direction = up_dir                                        │
  │    read camera_rotation from the live Camera2D           (D13.3)│
  │                                                                  │
  │ 2.–5.  unchanged from ADR-0007 D7.3                             │
  │                                                                  │
  │ 6. movement_component.apply()  ── GravityAuthority.             │
  │      apply_screen_relative_axis(.., camera_rotation)     (D13.2)│
  │                                                                  │
  │ 7. move_and_slide()                                             │
  │                                                                  │
  │ 8. visual_component.update()  ── SAME static fn as step 6       │
  │      runs UNCONDITIONALLY — watering or not, per AC9      (D7.3)│
  └─────────────────────────────────────────────────────────────────┘
```

Steps 2–5 and 7 are unchanged. ADR-0007 D7.3 remains the source of truth for the order.

### Key Interfaces

```gdscript
# GravityAuthority — replaces ADR-0007 D7.4's method (D13.2)
static func apply_screen_relative_axis(
    input_axis: float, right_dir: Vector2, camera_rotation: float
) -> float

# PlayerMovementComponent (D13.2) — boolean parameter replaced by float
func apply(
    delta: float, velocity: Vector2, is_on_floor: bool,
    right_dir: Vector2, up_dir: Vector2, input_axis: float,
    camera_rotation: float
) -> Vector2

# PlayerVisualComponent (D13.2) — same replacement
func update(
    delta: float, velocity: Vector2, is_on_floor: bool,
    right_dir: Vector2, up_dir: Vector2, input_axis: float,
    gravity: Vector2, camera_rotation: float
) -> void
```

## Alternatives Considered

### Alternative 1: Defer — record the gap, change nothing normative

- **Description**: Upgrade the ⚠ at `control-manifest.md:309` to a described, owned gap
  and add an open item to `requirements-traceability.md`. Leave both documents as they are.
- **Pros**: Zero cost. Reopens nothing. Touches no approved document.
- **Cons**: Leaves a formula in a binding, `verified-by`-stamped GDD that would send the
  player screen-left in `level_01` if implemented literally. `control-manifest.md` is the
  document implementers read first, and it would keep pointing at an unresolved ruling.
  `TR-gravity-013` would stay `covered` while the ADR it traces contradicts the GDD it
  traces. The mid-transition error becomes a live defect against the tutorial level with
  no owner.
- **Rejection Reason**: The wrong text is already binding. Deferring is accept-now-amend-later
  applied to a document that other work is about to consume.

### Alternative 2: Rewire the boolean to the flag that truly rotates

- **Description**: Keep D7.4's shape. Change the branch input from
  `camera_rotation_enabled` to `camera_moving`, and delete `camera_rotation_enabled`.
- **Pros**: The smallest possible normative change. Correct in the settled state, in every
  level, today.
- **Cons**: Welds a third behaviour onto `camera_moving`, which already welds rotation to
  follow. That moves away from T8 rather than toward it and makes the decouple harder. A
  boolean still cannot describe a camera partway through a 600 ms tween, so the
  mid-transition error becomes permanently unfixable in this shape. It also leaves
  `gravity.md` §4's formula wrong.
- **Rejection Reason**: It entrenches the accessibility blocker this ADR is meant to
  start dismantling, and it preserves the boolean approximation that caused the conflict.

### Alternative 3: Apply the camera decouple in the same change

- **Description**: Everything in this ADR, plus splitting `camera_moving` and migrating
  the `level_01` and `level_07` exports now.
- **Pros**: Closes `TR-gravity-010`, `accessibility-requirements.md` A7, and makes T8
  runnable immediately.
- **Cons**: Changes live camera behaviour in two shipped levels, one of them the tutorial,
  with no playtest behind it. Drags the 600 ms-versus-100 ms tween mismatch into scope,
  which is a feel question.
- **Rejection Reason**: ADR-0011 D11.6 set this project's precedent for exactly this
  situation and declined to apply. D13.5 specifies the split so a later change is a
  migration rather than a fresh decision.

### Alternative 4: Rule that `gravity.md` R11 is wrong and revert to D7.4

- **Description**: Amend R11 to restore the camera condition. Leave ADR-0007 untouched.
- **Pros**: No ADR work at all.
- **Cons**: Overturns an approved, human-verified GDD amendment whose underlying playtest
  verdict is correct. It also keeps the wrong flag and the mid-transition error.
- **Rejection Reason**: R11's rule is right. Only its formula is a special case presented
  as a general law. Reverting the rule would discard a correct human finding to fix a
  math error.

## Consequences

### Positive

- Both parties to the conflict keep their stance. R11's rule text is unchanged. ADR-0007
  D7.4's one-function guarantee is unchanged. ADR-0007 stays Accepted.
- `gravity.md` §4 and the shipped formula become the same expression evaluated at
  `camera_rotation = 0.0`, so GDD and code agree by construction.
- The mid-transition error is dissolved rather than tracked. No follow-up ticket is needed.
- The input-basis leg of the three-way decouple closes permanently. No flag can invert the
  controls again, because no flag is consulted.
- `apply_screen_relative_axis` stays a pure function of three parameters. A table-driven
  test over four gravity directions crossed with {unrotated, fully rotated, mid-transition}
  is deterministic and fixture-free, which the coding standards require. The boolean form
  cannot express the mid-transition rows at all.
- `gravity.md` §5's "never crosses to the opposite half of the screen" claim becomes true
  by construction.

### Negative

- An approved GDD's formula box is edited. R11's rule survives untouched, and the ⚠ being
  closed was placed by the amendment's own author, but this is still a change to a
  `verified-by`-stamped document and should be recorded as one.
- Six files change in total across the full resolution. This ADR is the first of six
  separate write approvals.
- `Player._physics_process` gains a fourth per-frame read at step 1. ADR-0007's Negative
  section already accepted three such reads as a trade of brevity for freshness. This is
  the fourth.
- `apply_screen_relative_axis` takes a `float` where the old method took a `bool`. A reader
  who remembers the old signature and passes a truthiness value gets a rotation of `1.0`
  radian and a subtly wrong mapping rather than a type error. The rename from
  `apply_camera_relative_axis` is deliberate for this reason — the old name will not
  resolve.

### Risks

- **A level sets `Camera2D.ignore_rotation = true`.** The camera node would rotate while
  the view did not, so `cam.rotation` would stop describing the screen and D13.2 would
  correct against a rotation the player cannot see. `main.gd:13` sets it `false` today and
  no level overrides it. *Mitigation*: state the precondition in `control-manifest.md`
  alongside the input-basis rule. Not guarded in code — a guard would need a per-frame read
  of a value that is authored once.
- **A future author reintroduces a boolean "for clarity."** Presents as correct in every
  static-camera level and wrong only during the 600 ms sweep in `level_01` and `level_07` —
  the same hard-to-reproduce shape the original conflict had. *Mitigation*: the
  `input_basis_gated_on_boolean_camera_flag` forbidden pattern in
  `docs/registry/architecture.yaml`, plus the Context table above kept in this ADR as the
  worked counterexample.
- **`Viewport.get_camera_2d()` behaves differently than assumed in 4.7.1.** D13.3's null
  fallback rests on it returning `null` with no current camera. *Mitigation*: named as the
  single Verification Required item; `godot-specialist` confirms before Accepted.
- **A freed `Camera2D` returns a stale reference rather than `null`.** `main.gd` calls
  `change_scene_to_packed()` (`change_level()`) and `reload_current_scene()`
  (`restart_level()`), so the camera is freed while `Player` may still run one more
  physics frame. `godotengine/godot#72529` documented exactly this — a freed `Camera2D`
  stayed active and `get_camera_2d()` returned `<Freed Object>` or an unrelated node
  instead of `null`. It was fixed by `godotengine/godot#72550`, long before 4.7.1, so
  this is **not** a live hazard on the pinned engine. Recorded so a future reader does
  not rediscover it and add a defensive `is_instance_valid()` guard for a bug that no
  longer exists. *Mitigation*: none needed; re-check if the engine pin ever moves
  backward.
- **The split in D13.5 is read as delivered.** *Mitigation*: stated in D13.5's own heading,
  in the Migration Plan's "not in this plan" line, and in the registry note — the same
  three-place restatement ADR-0007 used for its `TR-watering-002` carve-out.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `gravity.md` | R11 — input basis is screen-relative, unconditionally | Upheld verbatim. D13.1 fixes which frame "screen" names; D13.2 makes the rule true under a rotated camera, which R11's own §4 formula did not |
| `gravity.md` | §4 input-basis formula | Generalised by one `rotated(-camera_rotation)` term. Reduces to the existing formula at `camera_rotation = 0.0` |
| `gravity.md` | §5 "Camera rotation disabled on a level" | The ⚠ is closed. The mapping does not change, and D13.2 is why |
| `gravity.md` | §5 "Mid-transition input" | The continuity claim becomes true under a rotated camera as well as a static one |
| `gravity.md` | §6, AC8, AC10 (`TR-gravity-013`) — visual mirrors movement exactly | Still one function, two callers. Holds by construction, unchanged from ADR-0007 D7.4 |
| `gravity.md` | `TR-gravity-010` — camera rotation follows gravity | Input-basis leg closed. Follow/rotate leg specified in D13.5, not applied. Owner moves from Unassigned to this ADR |
| `accessibility-requirements.md` | T8 — reduced motion | Not delivered. One of three blocking legs removed; D13.5 specifies the other two. T8 stays Not Started |
| `accessibility-requirements.md` | A7 — the decouple has no owning ADR | Closed. This ADR owns it |

## Performance Implications

- **CPU**: Two `Vector2.rotated()` calls and one `get_viewport().get_camera_2d()` per
  physics frame, replacing two boolean branches. `rotated()` is one sin/cos pair. This is
  negligible against the 16.6 ms budget and is not measurable at the project's scale.
- **Memory**: Net reduction of one `bool` field on `Player` and one export on `LevelRoot`.
- **Load Time**: None.
- **Network**: N/A — single-player.

## Migration Plan

1. `GravityAuthority` — add `static func apply_screen_relative_axis(...)` per D13.2, with
   the `# static: no self access` comment. If ADR-0007's migration has already landed,
   this **replaces** `apply_camera_relative_axis`; if it has not, only this method is
   written. `GravityAuthority` must exist in `src/` first (ADR-0001's migration).
2. `PlayerMovementComponent.apply()` — replace the `camera_rotation_enabled: bool`
   parameter with `camera_rotation: float`, and replace the inline branch at
   `player_movement_component.gd:26-31` with the call from D13.2.
3. `PlayerVisualComponent.update()` — the same replacement at
   `player_visual_component.gd:46-50`.
4. `Player._physics_process()` — add the two-line camera read at step 1 per D13.3, and
   thread `camera_rotation` into steps 6 and 8. All other steps unchanged.
5. `Player` — delete `camera_rotation_enabled` (`player.gd:60`).
6. `LevelRoot` (`main.gd`) — delete the `camera_rotation_enabled` export (line 9) and the
   forward (line 15).
7. `level_01.tscn:29` and `level_07.tscn:33` — remove the now-orphaned
   `camera_rotation_enabled = true` property. `camera_moving = true` is left as it is.

Steps 1–4 land together or not at all; a partial application leaves one call site on a
signature that no longer exists.

**Not in this plan, deliberately**: the `camera_moving` split of D13.5 (needs a playtest),
and the tween-duration question of D13.6 (a `game-designer` call).

**Regression watch**: `gravity.md` AC1–AC12 must still pass. `level_01` and `level_07` must
play identically to today, including through the 600 ms camera sweep.

## Validation Criteria

This decision is correct if the following hold.

| # | Test | Type | Source |
|---|---|---|---|
| **V1** | Table-driven: for gravity ∈ {down, up, left, right} × `camera_rotation` ∈ {0, fully-turned}, `apply_screen_relative_axis(1.0, right_dir, camera_rotation)` applied to `right_dir` yields a world vector whose screen projection has a positive x-component | Logic | D13.2; `gravity.md` §4 table |
| **V2** | At `camera_rotation = 0.0`, the function's output equals `gravity.md` §4's `screen_sign · input_axis` for all four gravity directions — the GDD formula is reproduced exactly | Logic | D13.2 endpoint proof |
| **V3** | At `camera_rotation = Vector2.DOWN.angle_to(gravity_dir)`, the function returns `input_axis` unchanged for all four gravity directions — ADR-0007 D7.4's raw-axis branch is reproduced exactly | Logic | D13.2 endpoint proof |
| **V4** | Mid-transition: with `right_dir` settled at gravity-up and `camera_rotation` swept from `0` to `π` in 10 steps, the screen-projected walk vector's x-component is `≥ 0` at every step — no crossing to the opposite half of the screen | Logic | `gravity.md` §5 "Mid-transition input"; specialist finding E |
| **V5** | Grep-level: `PlayerMovementComponent` and `PlayerVisualComponent` both call `GravityAuthority.apply_screen_relative_axis`, and neither contains an inline `sign(` axis branch | Logic | `TR-gravity-013`, inherited from ADR-0007 Validation Criterion 4 |
| **V6** | Grep-level: no identifier `camera_rotation_enabled` remains anywhere in `src/` | Logic | D13.4 |
| **V7** | With no current `Camera2D`, `Player._physics_process` supplies `camera_rotation = 0.0` and the mapping matches V2 — headless tests exercise the GDD formula | Logic | D13.3 |
| **V8** | Human playtest: `level_01` and `level_07` play identically to today, including during the 600 ms camera sweep after each flip | Playtest | Regression watch |

The decision is **wrong**, and should be revisited, if a level ever needs the camera node's
rotation to differ from the viewport's apparent rotation (for example by setting
`Camera2D.ignore_rotation = true` for a deliberate effect). D13.3 would then be reading a
value that no longer describes the screen, and the camera's *effective* rotation would need
to become an explicit, owned value rather than a node property read.

## Related Decisions

- `docs/architecture/adr-0001-gravity-ownership-and-global-broadcast.md` — establishes
  `GravityAuthority` and the `private_gravity_copy` ban this ADR's live-read model respects
- `docs/architecture/adr-0007-player-component-contract-and-physics-step-order.md` — D7.3's
  step order is unchanged; D7.4's method contract is superseded, its stance preserved
- `docs/architecture/adr-0011-physics-prop-body-lifetime-and-speed-cap.md` — D11.6 is the
  precedent for D13.5's specify-do-not-apply
- `design/gdd/gravity.md` — R11, §4, §5, §6
- `design/accessibility-requirements.md` — T8, A7
- `design/ux/hud.md` — Q10, Finding 1
- `docs/architecture/requirements-traceability.md` — item 3, `TR-gravity-010`
- `production/gate-checks/gate-check-2026-08-17-pre-production-c.md` — open item 1
