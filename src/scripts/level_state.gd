## Level-scoped watering progress, owned by `LevelRoot` (ADR-0002).
##
## A plain `RefCounted`: never an autoload, never a singleton, never reachable
## globally. `LevelRoot._ready()` constructs one and injects it into every
## consumer; `reload_current_scene()` frees `LevelRoot`, which frees this object,
## which is why the type has no `reset()` and never will
## (`watering-system.md` AC8, forbidden pattern `level_state_reset_method`).
##
## Every externally-immutable value is a getter-only computed property over a
## private backing field. Engine note for 4.7.1: an external write to a
## getter-only property is discarded SILENTLY — it neither succeeds nor raises
## (evidence: `production/qa/evidence/getter-only-assignment-probe-2026-08-26.md`).
## The safety guarantee holds; the diagnostic ADR-0002:246-248 claims does not.
##
## `mark_complete()` is deliberately absent. `_level_complete` and its getter are
## declared here; the write-once latch and its sole caller are story 005 under
## ADR-0005 D5.3.
class_name LevelState
extends RefCounted

## Emitted once, on the false -> true transition of [member goal_unlocked] only.
## Never re-emitted, and never emitted at construction — a signal emitted inside
## `_init()` cannot be received, because nothing is connected yet. A level built
## with `buckets_total == 0` is therefore unlocked from construction WITHOUT this
## signal ever firing; consumers must read [member goal_unlocked] when they bind.
signal goal_unlocked_changed(unlocked: bool)

## Emitted on every completed pour that actually advanced the counter, carrying
## both the new consumed count and the level total.
signal bucket_consumed(consumed: int, total: int)

var _buckets_total: int = 0
var _buckets_consumed: int = 0
var _goal_unlocked: bool = false
var _level_complete: bool = false

## Buckets this level contains. Seeded once at construction from
## `LevelValidation.count_buckets()` (story 004); never written again.
var buckets_total: int:
	get: return _buckets_total

## Buckets poured onto plants so far. Written only by [method consume_bucket];
## never decreases and never exceeds [member buckets_total].
var buckets_consumed: int:
	get: return _buckets_consumed

## True exactly when `buckets_consumed >= buckets_total`, and never before
## (`watering-system.md` R6, AC6). Derived — nothing outside this class writes it.
var goal_unlocked: bool:
	get: return _goal_unlocked

## Set once by the story-005 latch. ADR-0005 owns when it is read and written;
## this story owns only that the field exists and how it is exposed.
var level_complete: bool:
	get: return _level_complete

## The one genuinely read-write field: whether the player is carrying a bucket.
## Its consumer logic lives in `PlayerWateringComponent` (ADR-0009).
var carrying_bucket: bool = false


## Constructs the level state for a level holding [param initial_buckets_total]
## buckets. Callers must pass a value `>= 0`; zero is legal — a level with no
## plants is not a contract breach here, and level-authoring judgement belongs to
## `LevelValidation` (ADR-0003).
##
## With a total of zero the goal is unlocked from construction, since `0 >= 0`.
##
## (The parameter is named `initial_buckets_total` rather than `buckets_total` so
## it does not shadow the property of that name; a shadowing warning would fail
## the whole gdUnit4 suite at discovery.)
func _init(initial_buckets_total: int) -> void:
	if initial_buckets_total < 0:
		push_error(
			"LevelState requires buckets_total >= 0, got %d. Clamping to 0."
			% initial_buckets_total
		)
		initial_buckets_total = 0
	_buckets_total = initial_buckets_total
	_goal_unlocked = _buckets_consumed >= _buckets_total


## Records one COMPLETED pour (`watering-system.md` R3, ADR-0002). Never called
## on pickup or on an early release.
##
## A call made once the counter has reached [member buckets_total] is a no-op:
## no counter change, no signal. Emits [signal bucket_consumed] on every call
## that advanced the counter, and [signal goal_unlocked_changed] once, on the
## transition.
func consume_bucket() -> void:
	if _buckets_consumed >= _buckets_total:
		return
	_buckets_consumed += 1
	bucket_consumed.emit(_buckets_consumed, _buckets_total)
	if not _goal_unlocked and _buckets_consumed >= _buckets_total:
		_goal_unlocked = true
		goal_unlocked_changed.emit(true)
