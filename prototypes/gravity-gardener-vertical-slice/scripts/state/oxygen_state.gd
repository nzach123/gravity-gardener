# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# Plain RefCounted, constructed by LevelRoot._ready() from the level's authored
# oxygen_capacity export, never an autoload (ADR-0002) — dies with the level, which
# is what gives suit-oxygen.md R5 (restart resets to full) for free.
# Must never read OxygenAccessibility or any other autoload directly — an autoload
# dependency would break unit-testability (control-manifest Core Layer, Forbidden).
class_name OxygenState
extends RefCounted

var _capacity: float
var _remaining: float
var _tuning: OxygenTuning

var capacity: float:
	get: return _capacity

var remaining: float:
	get: return _remaining

var fraction: float:
	get: return _remaining / _capacity if _capacity > 0.0 else 0.0

## Reports an empty tank and decides nothing — OxygenDrain owns the kill policy.
var depleted: bool:
	get: return _remaining <= 0.0

## Validates capacity > 0 at construction (ADR-0002). A non-positive capacity is
## not constructible — suit-oxygen.md §5's "oxygen_capacity authored <= 0" edge
## case is caught by LevelValidation before this is ever constructed; this guard
## covers any other call site.
func _init(capacity_value: float, tuning: OxygenTuning) -> void:
	if capacity_value <= 0.0:
		push_error("OxygenState: capacity must be > 0, got %f" % capacity_value)
	_capacity = capacity_value
	_remaining = capacity_value
	_tuning = tuning

## [param delta] is already accessibility-scaled by the caller (ADR-0008 §3) — this
## function's signature and internal logic (multiplying by tuning.drain_rate) stay
## unchanged regardless of who scales delta.
func drain(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - _tuning.drain_rate * delta)
