# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# Constructs and injects LevelState/OxygenState (ADR-0002), runs LevelValidation
# BEFORE construction (ADR-0003 D3.1), calls GravityAuthority.reset_to() (ADR-0001),
# and owns the completion/restart transition guard (ADR-0005 D5.4).
class_name LevelRoot
extends Node2D

@export var default_gravity_direction: Vector2 = Vector2.DOWN
@export var default_gravity_multiplier: float = 1.0
@export var oxygen_capacity: float = 48.0

@export var player_path: NodePath
@export var goal_path: NodePath
@export var hud_path: NodePath
@export var oxygen_drain_path: NodePath

var level_state: LevelState
var oxygen_state: OxygenState

var _transition_pending: bool = false


func _ready() -> void:
	# Reads only raw authored @export scene data — runs before LevelState/OxygenState
	# exist (ADR-0003 D3.1).
	var findings: PackedStringArray = LevelValidation.validate(self)
	for finding in findings:
		push_error(finding)

	var bucket_count: int = LevelValidation.count_buckets(self)
	level_state = LevelState.new(bucket_count)
	oxygen_state = OxygenState.new(oxygen_capacity, Tuning.OXYGEN)

	GravityAuthority.reset_to(default_gravity_direction, default_gravity_multiplier)

	var player: Player = get_node(player_path)
	var goal: Goal = get_node(goal_path)
	var hud: HUD = get_node(hud_path)
	var oxygen_drain: OxygenDrain = get_node(oxygen_drain_path)

	player.watering_component.bind(level_state)
	goal.bind(level_state)
	hud.bind(level_state, oxygen_state)
	oxygen_drain.bind(oxygen_state, level_state)
	oxygen_drain.oxygen_depleted.connect(_on_oxygen_depleted)
	goal.player_reached_goal.connect(_on_player_reached_goal)

	# LevelRoot-mediated candidate registration (ADR-0009 D3) — no group membership.
	for plant in LevelValidation.find_plants(self):
		plant.player_entered_range.connect(player.watering_component.register_candidate.bind(plant))
		plant.player_exited_range.connect(player.watering_component.unregister_candidate.bind(plant))


## BOTH the completion path and the restart path check and set _transition_pending
## — the level_complete latch alone is insufficient because inter-area signal
## delivery order within one physics tick is undetermined (ADR-0005 D5.4).
func _on_player_reached_goal() -> void:
	if _transition_pending:
		return
	_transition_pending = true
	level_state.mark_complete()


func _on_oxygen_depleted() -> void:
	var player: Player = get_node(player_path)
	player.player_died = true
	restart_level()


## Never restarts from a death/reset path that does not consult level_complete
## (Forbidden: unguarded_restart_path).
func restart_level() -> void:
	if level_state.level_complete or _transition_pending:
		return
	_transition_pending = true
	get_tree().call_deferred("reload_current_scene")
