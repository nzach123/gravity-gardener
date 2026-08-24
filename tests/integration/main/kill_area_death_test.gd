# Integration tests for the KillArea2D death path in levels 05 and 06.
#
# Written ahead of the ADR-0004 collision-layer migration
# (docs/architecture/adr-0004-collision-layer-allocation.md) as
# characterization tests. Migration step 3 fixed BUG-0001
# (production/qa/bugs/BUG-0001.md): KillArea2D carried no
# collision_layer/mask, so both defaulted to 1 ("world"), which never
# matched the player's layer 2 — body_entered could not fire. The fix sets
# collision_layer = 0, collision_mask = 2 on both levels.
#
# The first physics test below was the characterization pin. It has flipped
# and is now the regression guard for BUG-0001. Do not delete it.
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

const LEVEL_05 := "res://src/scenes/levels/level_05.tscn"
const LEVEL_06 := "res://src/scenes/levels/level_06.tscn"

# Center of KillArea2D's CollisionShape2D in level_05.tscn: local position
# (-45, 325) on a RectangleShape2D, KillArea2D itself at the level root's
# origin, so this is level-space == global-space.
const KILL_AREA_CENTER_05 := Vector2(-45, 325)
# level_06 places KillArea2D at (1241, 0), so the same shape offset lands at
# (1241 - 45, 0 + 325).
const KILL_AREA_CENTER_06 := Vector2(1196, 325)

# The player's authored layer, read from the registry rather than restated,
# so a future re-allocation moves these assertions with it (ADR-0004 D4.5).
const PLAYER_LAYER := CollisionLayers.PLAYER


func before_test() -> void:
	GameManager.reset_level_state()


# ── Authored-state assertions (headless, no SceneTree) ──────────────────────
#
# PackedScene.instantiate() populates properties without running _ready()
# (ADR-0004 L5), so these read the authored data directly.
func _kill_area_of(level_path: String) -> Area2D:
	var scene: PackedScene = load(level_path) as PackedScene
	var level: Node = auto_free(scene.instantiate())
	return level.get_node("KillArea2D") as Area2D


func test_level_05_kill_area_occupies_no_layer() -> void:
	assert_int(_kill_area_of(LEVEL_05).collision_layer).is_equal(0)


func test_level_05_kill_area_masks_the_player() -> void:
	# Bit test, not equality — the mask may legitimately gain other bits
	# later (ADR-0011 defers the prop question) without voiding this rule.
	assert_int(_kill_area_of(LEVEL_05).collision_mask & PLAYER_LAYER).is_not_equal(0)


func test_level_06_kill_area_occupies_no_layer() -> void:
	assert_int(_kill_area_of(LEVEL_06).collision_layer).is_equal(0)


func test_level_06_kill_area_masks_the_player() -> void:
	assert_int(_kill_area_of(LEVEL_06).collision_mask & PLAYER_LAYER).is_not_equal(0)


# This is the assertion that would have caught BUG-0001. It compares each
# kill area's mask against the player's ACTUAL authored layer, rather than
# against a literal, so it fails if either side drifts.
func test_every_kill_area_mask_intersects_the_authored_player_layer() -> void:
	for level_path: String in [LEVEL_05, LEVEL_06]:
		var scene: PackedScene = load(level_path) as PackedScene
		var level: Node = auto_free(scene.instantiate())
		var kill_area: Area2D = level.get_node("KillArea2D") as Area2D
		var player: Node2D = level.get_node("Player") as Node2D
		var player_layer: int = (player as CollisionObject2D).collision_layer
		assert_int(kill_area.collision_mask & player_layer) \
			.override_failure_message(
				"%s: KillArea2D mask %d does not intersect the player's layer %d — "
				% [level_path, kill_area.collision_mask, player_layer]
				+ "body_entered cannot fire (BUG-0001)."
			) \
			.is_not_equal(0)


# ── Physics-based regression guards ─────────────────────────────────────────
#
# This test was the BUG-0001 characterization pin and asserted is_false().
# It flipped when the fix landed and is now the regression guard.
func test_kill_area_kills_player_bug_0001_fixed() -> void:
	# Arrange
	var runner := scene_runner(LEVEL_05)
	var player: Player = runner.find_child("Player") as Player
	player.global_position = KILL_AREA_CENTER_05
	player.player_died = false

	# Act — let the physics broadphase run enough frames to detect overlap
	await runner.simulate_frames(10)

	# Assert
	assert_bool(player.player_died).is_true()


# level_06 had no coverage before this story.
func test_kill_area_kills_player_in_level_06() -> void:
	# Arrange
	var runner := scene_runner(LEVEL_06)
	var player: Player = runner.find_child("Player") as Player
	player.global_position = KILL_AREA_CENTER_06
	player.player_died = false

	# Act
	await runner.simulate_frames(10)

	# Assert
	assert_bool(player.player_died).is_true()


# ── Handler-logic pin (unaffected by the migration) ──────────────────────────
#
# The migration only changed KillArea2D's layer/mask, not this handler.
# This test bypasses physics entirely and pins that once body_entered DOES
# fire, the death + restart wiring is correct.
#
# Expected harmless log line: restart_level() calls
# get_tree().call_deferred("reload_current_scene"), and the scene runner's
# tree has no registered current_scene, so Godot logs
# "ERROR: Parameter "current_scene" is null." This fires after the
# assertions below have already run and does not fail the test.
func test_kill_area_handler_kills_player_and_resets_state() -> void:
	# Arrange
	var runner := scene_runner(LEVEL_05)
	var player: Player = runner.find_child("Player") as Player
	GameManager.plants_watered = 2
	GameManager.goal_unlocked = true

	# Act — call the connected handler directly, as the physics engine would
	runner.invoke("_on_kill_area_2d_body_entered", player)

	# Assert
	assert_bool(player.player_died).is_true()
	assert_int(GameManager.plants_watered).is_equal(0)
	assert_bool(GameManager.goal_unlocked).is_false()
