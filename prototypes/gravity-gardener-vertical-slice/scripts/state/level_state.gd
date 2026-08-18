# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# Plain RefCounted, constructed by LevelRoot._ready(), never an autoload (ADR-0002).
# Dies with the level root on restart/reload — this is what gives watering-system.md
# §5's carry-state defect fix "for free" (no reset() method exists or is needed).
class_name LevelState
extends RefCounted

var _buckets_total: int
var _buckets_consumed: int = 0
var _carrying_bucket: bool = false
var _level_complete: bool = false

var buckets_total: int:
	get: return _buckets_total

## Only mutator: consume_bucket(), called on a completed pour only (watering-system.md R6).
var buckets_consumed: int:
	get: return _buckets_consumed

var carrying_bucket: bool:
	get: return _carrying_bucket

## Derived, never set directly (watering-system.md R6).
var goal_unlocked: bool:
	get: return _buckets_consumed >= _buckets_total

## Write-once latch — written ONLY via mark_complete() from
## LevelRoot._on_player_reached_goal(). No path may set it back to false (ADR-0005 D5.3).
var level_complete: bool:
	get: return _level_complete

func _init(buckets_total_count: int) -> void:
	_buckets_total = buckets_total_count

## Called only on a *completed* pour — never on pickup or early release (ADR-0002).
func consume_bucket() -> void:
	_buckets_consumed += 1

func set_carrying(value: bool) -> void:
	_carrying_bucket = value

func mark_complete() -> void:
	_level_complete = true
