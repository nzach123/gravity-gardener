# Integration tests for the level_05 KillArea2D death path.
#
# Characterization tests written ahead of the ADR-0004 collision-layer
# migration (docs/architecture/adr-0004-collision-layer-allocation.md).
# Migration step 3 fixes BUG-0001 (production/qa/bugs/BUG-0001.md): today
# KillArea2D carries no collision_layer/mask, so it defaults to layer 1
# ("world"), which never matches the player's layer 2 — body_entered can
# never fire. The fix sets collision_layer = 0, collision_mask = 2.
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")

const LEVEL_05 := "res://src/scenes/levels/level_05.tscn"
# Center of KillArea2D's CollisionShape2D in level_05.tscn: local position
# (-45, 325) on a RectangleShape2D, KillArea2D itself at the level root's
# origin, so this is level-space == global-space.
const KILL_AREA_CENTER := Vector2(-45, 325)


func before_test() -> void:
	GameManager.reset_level_state()


# ── Physics-based characterization (pins the current bug) ───────────────────
#
# This test asserts today's (broken) behavior and is EXPECTED TO FLIP once
# ADR-0004 migration step 3 lands. Update the assertion to is_true() then —
# do not delete the test, it becomes the regression guard for BUG-0001.
func test_kill_area_currently_does_not_kill_player_bug_0001() -> void:
	# Arrange
	var runner := scene_runner(LEVEL_05)
	var player: Player = runner.find_child("Player") as Player
	player.global_position = KILL_AREA_CENTER
	player.player_died = false

	# Act — let the physics broadphase run enough frames to detect overlap
	await runner.simulate_frames(10)

	# Assert — KillArea2D's default layer/mask never matches the player today
	assert_bool(player.player_died).is_false()


# ── Handler-logic pin (unaffected by the migration) ──────────────────────────
#
# The migration only changes KillArea2D's layer/mask, not this handler.
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
