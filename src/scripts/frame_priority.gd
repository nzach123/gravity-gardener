## The physics-frame ordering contract, as three named constants (ADR-0005 D5.1).
##
## Assigned in code, in each node's own `_ready()`:
##
##     process_physics_priority = FramePriority.GRAVITY
##
## Never per-scene in the inspector. Eight level scenes each carrying an editable
## copy of the ordering is eight chances for silent drift, and the resulting bug
## — a death check that runs before movement in one level only — is close to
## undiagnosable.
##
## The numbers encode an ORDERING, not a tuning value. Only their relative order
## is load-bearing; the constants are named for the roles they order.
##
## F1 — `process_physics_priority` orders `_physics_process`; `process_priority`
## orders `_process`. They are separate properties. Assigning the wrong one
## produces no compile error and no runtime error — it simply orders nothing,
## SILENTLY. `architecture.md`'s Frame update path named `process_priority` and
## was wrong; ADR-0005 is the correction.
##
## F3 — the ordering is a SINGLE GLOBAL SORT across the default process group,
## not a per-parent sort. Every node in that group is ordered by one global
## priority comparator, with scene-tree position as the tiebreak. This is
## counter-intuitive, and it is the only reason this contract works at all:
## `GravityAuthority` (an autoload), `Player` and `OxygenDrain` do NOT share a
## parent. A reader who assumes per-parent scoping will conclude the contract is
## broken. It is not.
##
## Corollary of F3: `process_thread_group` must stay at its default on all three
## nodes. Changing it silently detaches the node from this ordering, again with
## no error.
##
## A5-05 — these constants are NOT on `LevelRoot`. `GravityAuthority` is an
## autoload that exists before any level scene loads, so it cannot source a
## constant from a per-level scene script. A `class_name` resolves when this
## SCRIPT loads, which is independent of the `SceneTree` entirely — that is what
## lets an autoload and a level-scene node reach the same source by the same
## mechanism. Same reasoning as `Tuning` (ADR-0006 D6.3).
##
## `FramePriority` is NOT an autoload and must never become one. `class_name`
## already gives it universal reach; registering it would hand it exactly the
## tree dependency A5-05 exists to avoid. It holds three constants and nothing
## else: no methods, no variables, no signals, no `_ready`.
class_name FramePriority

## `GravityAuthority` — ease direction, push space gravity, force-wake props.
## Runs FIRST: everything downstream reads the vector it settles.
const GRAVITY: int = -100

## `Player` (and its components, called inline) — pour progress, movement,
## `move_and_slide()`. Runs between the two.
const PLAYER: int = 0

## `OxygenDrain` — armed-kill evaluation, then drain. Runs LAST, so the kill it
## evaluates reflects the movement that already happened this frame.
const OXYGEN: int = +100
