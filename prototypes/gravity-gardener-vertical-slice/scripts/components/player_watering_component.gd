# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# Pour-driving lives here, never on Plant (ADR-0009 D1). update_pour() runs ONLY via
# Player._physics_process's inline call — this script must never gain its own
# _physics_process/_process override (Godot auto-schedules any override it detects,
# double-driving update_pour() and silently halving the effective pour duration).
# Must never connect to GravityAuthority.gravity_changed (ADR-0009).
class_name PlayerWateringComponent
extends Node

signal watering_started
signal watering_stopped

var is_watering: bool = false
var held_bucket: Bucket = null
var water_progress: float = 0.0

var player_body: Node2D  # set by Player._ready(); needed for nearest-candidate distance
var level_state: LevelState

var _candidates: Array[Plant] = []
var _target_plant: Plant = null
var _is_bound: bool = false


## Called by LevelRoot._ready() after LevelState is constructed — never read
## level_state before this runs (ADR-0002).
func bind(level_state_ref: LevelState) -> void:
	level_state = level_state_ref
	_is_bound = true


func is_carrying() -> bool:
	return held_bucket != null


## Called by Bucket.on_picked_up() — a two-party spatial interaction, no LevelRoot
## mediation needed (ADR-0009 D4). Refuses if already carrying (watering-system.md R1).
func pickup_bucket(bucket: Bucket) -> void:
	if not _is_bound:
		push_error("PlayerWateringComponent: pickup_bucket() called before bind()")
		return
	if held_bucket != null:
		return
	held_bucket = bucket
	level_state.set_carrying(true)
	bucket.on_picked_up()


## LevelRoot-mediated candidate registration (ADR-0009 D3): LevelRoot wires each
## Plant's player_entered_range/player_exited_range to these, bound to that plant.
func register_candidate(plant: Plant) -> void:
	if not _candidates.has(plant):
		_candidates.append(plant)
	_select_target()


func unregister_candidate(plant: Plant) -> void:
	_candidates.erase(plant)
	if _target_plant == plant:
		_reset_progress()
	_select_target()


## Capacity (is_capped()) is checked ONLY here, at target selection — never inside
## the accumulation loop in update_pour() (watering-system.md R5).
func _select_target() -> void:
	var best: Plant = null
	var best_dist_sq: float = INF
	for c in _candidates:
		if c.is_capped():
			continue
		var d: float = player_body.global_position.distance_squared_to(c.global_position)
		if d < best_dist_sq:
			best_dist_sq = d
			best = c
	_target_plant = best
	if _target_plant == null:
		_reset_progress()


## Called ONLY from Player._physics_process step 2 (ADR-0009 D2).
func update_pour(delta: float) -> void:
	if not _is_bound:
		push_error("PlayerWateringComponent: update_pour() called before bind()")
		return
	if _target_plant == null or held_bucket == null:
		if is_watering:
			_reset_progress()
		return

	if Input.is_action_pressed("interact"):
		if not is_watering:
			is_watering = true
			watering_started.emit()
		water_progress += delta
		if water_progress >= _target_plant.water_duration:
			_complete_pour()
	elif Input.is_action_just_released("interact"):
		_reset_progress()


func _complete_pour() -> void:
	var completed_plant: Plant = _target_plant
	completed_plant.receive_bucket()
	held_bucket.consume(player_body)
	held_bucket = null
	level_state.set_carrying(false)
	level_state.consume_bucket()
	_reset_progress()
	if completed_plant.is_capped():
		_candidates.erase(completed_plant)
	_select_target()


## Early release or leaving the interact area — bucket retained, progress zeroed,
## player unlocked (watering-system.md R4).
func _reset_progress() -> void:
	water_progress = 0.0
	if is_watering:
		is_watering = false
		watering_stopped.emit()
