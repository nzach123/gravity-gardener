# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# Child of LevelRoot, process_physics_priority = +100 (ADR-0005 D5.1). Runs:
# freeze-if-complete -> armed-restart -> drain() -> arm-on-depletion (ADR-0008 §1).
# Owns the kill *policy* — OxygenState.depleted only reports an empty tank.
class_name OxygenDrain
extends Node

signal oxygen_depleted

var oxygen_state: OxygenState
var level_state: LevelState

var _is_bound: bool = false
var _armed: bool = false  # set when remaining hit 0 last frame; kill fires at the TOP of the next callback


func bind(oxygen_state_ref: OxygenState, level_state_ref: LevelState) -> void:
	oxygen_state = oxygen_state_ref
	level_state = level_state_ref
	_is_bound = true


func _ready() -> void:
	process_physics_priority = FramePriority.OXYGEN_DRAIN


func _physics_process(delta: float) -> void:
	if not _is_bound:
		push_error("OxygenDrain: _physics_process running before bind()")
		return

	# freeze-if-complete: level_complete freezes drain entirely, so the HUD holds
	# its final reading through the transition, and airlock entry wins over a
	# same-frame depletion (suit-oxygen.md §5).
	if level_state.level_complete:
		return

	# armed-restart: evaluate a kill armed on a PRIOR frame, at the top of THIS
	# callback — never the same callback that observed remaining <= 0 (ADR-0005 D5.2).
	if _armed:
		oxygen_depleted.emit()
		return

	# drain(): pre-scale delta by the accessibility multiplier before calling
	# OxygenState.drain() — its signature and internal logic stay unchanged (ADR-0008 §3).
	var scaled_delta: float = delta * OxygenAccessibility.drain_rate_multiplier
	oxygen_state.drain(scaled_delta)

	# arm-on-depletion
	if oxygen_state.depleted:
		_armed = true
