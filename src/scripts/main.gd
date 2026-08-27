## The level root. Owns both level-scoped state objects and injects them
## (ADR-0002 parts 1, 3 and 4).
##
## `_ready()` runs BOTTOM-UP, so every child is already ready when this runs.
## That is why consumers are pushed state through `bind()` rather than pulling it
## themselves, and why each of them refuses to operate before it is bound.
extends Node2D
class_name LevelRoot

@export var player: Player
@export var goal: Goal
@export var bucket: Bucket
@export var next_level: PackedScene

## Suit oxygen this level starts with, in seconds of drain at rate 1.0
## (`suit-oxygen.md` §5). Read by `LevelValidation` under V-OXY-CAP, and passed
## to `OxygenState` at construction. The drain rate and band thresholds are NOT
## exports — they come from `Tuning.OXYGEN` (ADR-0006 D6.3).
@export var oxygen_capacity: float = 60.0

## The HUD consumer row from ADR-0002 part 3. Declared because
## `LevelValidation.REQUIRED_CONSUMERS` already expects the shape, and left
## UNASSIGNED on purpose: the HUD itself is the Presentation epic under ADR-0010.
## Nothing binds to it yet — see the commented seam in `_ready()`.
@export var hud: Node

@onready var camera_2d: Camera2D = $Camera2D

@export var camera_moving: bool = false
@export var camera_rotation_enabled: bool = false

var camera_tween: Tween

# Both state objects are held privately and never exposed globally. When this
# node is freed the last strong reference goes with it, which is what makes
# restart reconstruction rather than reset (ADR-0002 part 2).
var _level_state: LevelState = null
var _oxygen_state: OxygenState = null


func _ready() -> void:
	# ── step (a): construct the state objects, before any binding ────────────
	var buckets_total: int = LevelValidation.count_buckets(self)
	_level_state = LevelState.new(buckets_total)
	_oxygen_state = OxygenState.new(oxygen_capacity, Tuning.OXYGEN)

	# ── step (b): LEVEL VALIDATION SEAM — intentionally unwired here ─────────
	# LV-005 wires `LevelValidation.validate(self)` in at THIS point and logs the
	# findings (ADR-0003 D3.4). It is not called by this story.
	#
	# The ordering LV-005 will assert (ADR-0003 D3.1): validate() runs BEFORE the
	# state objects above are constructed, reading only raw authored @export
	# scene data. `OxygenState._init()` rejects capacity <= 0, so constructing
	# state first would make a level that breaches V-OXY-CAP fail during
	# construction and validation would never run on the input that motivated it.
	# When LV-005 lands, the call goes ABOVE step (a), not here.

	# ── step (c): bind state into the consumers that exist ───────────────────
	if player:
		player.bind(_level_state)
	if goal:
		goal.bind(_level_state)

	# HUD SEAM (ADR-0010, Presentation epic). The HUD receives BOTH state
	# objects: `hud.bind(_level_state, _oxygen_state)`. No stub node is created
	# for it — a stub that binds successfully would make the real consumer's
	# missing bind() invisible.
	#
	# A2-03 invariant, and the Presentation epic is the one most likely to break
	# it: every bound consumer must be a DESCENDANT of LevelRoot. Reconstruction
	# on restart works only because every strong holder is freed in the same
	# synchronous teardown pass as LevelRoot. A persistent or cross-scene HUD
	# would hold a stale LevelState with no error and no crash — RefCounted leaks
	# are invisible and there is no watchdog.

	# OXYGEN DRAIN SEAM (ADR-0008, Core oxygen-drain epic). `OxygenDrain` is a
	# CHILD of LevelRoot, not of Player and not an export, so it is reached by
	# the child scan rather than by a wired reference:
	# `oxygen_drain.bind(_oxygen_state)`. It owns the kill decision; OxygenState
	# only reports that the tank is empty.

	# ── step (d): connect each plant's completed pour to the level state ─────
	# Recursive TYPE scan, never get_nodes_in_group(): a forgotten group
	# assignment is invisible and the level reports clean (ADR-0003 D3.2).
	var plants: Array[Plant] = _collect_plants(self)
	for plant: Plant in plants:
		plant.pour_completed.connect(_level_state.consume_bucket)

	camera_2d.ignore_rotation = false
	if player:
		player.camera_rotation_enabled = camera_rotation_enabled
	if goal and player:
		goal.player_reached_goal.connect(player.win_level)
		goal.player_reached_goal.connect(change_level)

	# Collects all hazards in Group hazards
	var hazards = get_tree().get_nodes_in_group("hazards")
	for hazard in hazards:
		hazard.inc_hazard_dmg.connect(restart_level)

	var gravityzone = get_tree().get_nodes_in_group("gravityzone")
	for zone in gravityzone:
		# Zones declare; the authority owns (ADR-0001 part 2). A zone never
		# reaches the player — `zone_targets_player_directly` is forbidden.
		zone.gravity_changed.connect(GravityAuthority.set_gravity)
	# Connected ONCE, deliberately outside the loop above: the camera follows
	# the authority's single broadcast, not each zone's own signal. Inside the
	# loop this would connect N times and one zone entry would start N tweens.
	GravityAuthority.gravity_changed.connect(_rotate_camera_to_gravity)

	# Initialize plant count for watering mechanic. Story 006 owns the
	# GameManager deletion; until then the assignment stays, and it must stay
	# AFTER reset_level_state(), which zeroes `plants_total`. Only the discovery
	# changed — the count now comes from the step (d) type scan.
	GameManager.reset_level_state()
	GameManager.plants_total = plants.size()


## Depth-first `get_children()` type scan for every [Plant] beneath
## [param root]. Mirrors `LevelValidation._collect()` — group membership is
## invisible bookkeeping and `Node.find_children()` defaults `owned` to true,
## which silently drops unowned descendants (ADR-0003 D3.2, F3).
func _collect_plants(root: Node) -> Array[Plant]:
	var found: Array[Plant] = []
	for child: Node in root.get_children():
		if child is Plant:
			found.append(child as Plant)
		found.append_array(_collect_plants(child))
	return found


func _rotate_camera_to_gravity(direction: Vector2, _multiplier: float) -> void:
	if camera_moving:
		var target_rotation = Vector2.DOWN.angle_to(direction)
		camera_tween = create_tween()
		camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		camera_tween.tween_property(camera_2d, "rotation", target_rotation, .6)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if camera_moving:
		camera_2d.global_position = player.global_position
	if GameManager.carrying_bucket:
		bucket.global_position = player.get_node("HandMarker").global_position
		bucket.scale = Vector2(0.5,0.5)
		bucket.rotation = player.rotation
	if GameManager.carrying_bucket == false and GameManager.goal_unlocked == true:
		bucket.hide()



func change_level() -> void:
	get_tree().change_scene_to_packed(next_level)


func restart_level() -> void:
	print("level restart called")
	GameManager.reset_level_state()
	get_tree().call_deferred("reload_current_scene")

func set_camera() -> void:
	camera_2d.global_position = player.global_position

func follow_camera()->void:
	camera_2d.global_position = player.global_position


func _on_kill_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		body.player_died = true
		restart_level()
