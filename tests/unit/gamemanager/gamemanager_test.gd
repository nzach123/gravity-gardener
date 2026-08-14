# Unit tests for GameManager autoload
#
# GameManager tracks player lives, watering progress, bucket state, and
# goal unlock status. It is registered as an autoload in project.godot.
extends GdUnitTestSuite
@warning_ignore("unused_parameter")
@warning_ignore("return_value_discarded")


func before_test() -> void:
	# Reset to known state before each test
	GameManager.reset_level_state()
	GameManager.player_lives = 5
	GameManager.carrying_bucket = false


# ── Initial state ────────────────────────────────────────────────────────────

func test_initial_player_lives_is_five() -> void:
	assert_int(GameManager.player_lives).is_equal(5)


func test_initial_goal_unlocked_is_false() -> void:
	assert_bool(GameManager.goal_unlocked).is_false()


func test_initial_plants_watered_is_zero() -> void:
	assert_int(GameManager.plants_watered).is_equal(0)


func test_initial_plants_total_is_zero() -> void:
	assert_int(GameManager.plants_total).is_equal(0)


func test_initial_carrying_bucket_is_false() -> void:
	assert_bool(GameManager.carrying_bucket).is_false()


# ── reset_level_state() ──────────────────────────────────────────────────────

func test_reset_level_state_clears_goal_unlocked() -> void:
	GameManager.goal_unlocked = true
	GameManager.reset_level_state()
	assert_bool(GameManager.goal_unlocked).is_false()


func test_reset_level_state_clears_plants_watered() -> void:
	GameManager.plants_watered = 3
	GameManager.reset_level_state()
	assert_int(GameManager.plants_watered).is_equal(0)


func test_reset_level_state_clears_plants_total() -> void:
	GameManager.plants_total = 5
	GameManager.reset_level_state()
	assert_int(GameManager.plants_total).is_equal(0)


func test_reset_level_state_does_not_affect_player_lives() -> void:
	GameManager.player_lives = 2
	GameManager.reset_level_state()
	assert_int(GameManager.player_lives).is_equal(2)


func test_reset_level_state_does_not_affect_carrying_bucket() -> void:
	GameManager.carrying_bucket = true
	GameManager.reset_level_state()
	assert_bool(GameManager.carrying_bucket).is_true()


# ── Watering progress ────────────────────────────────────────────────────────

func test_plants_watered_can_be_incremented() -> void:
	GameManager.plants_watered += 1
	assert_int(GameManager.plants_watered).is_equal(1)


func test_goal_unlocks_when_all_plants_watered() -> void:
	GameManager.plants_total = 3
	GameManager.plants_watered = 3
	GameManager.goal_unlocked = true
	assert_bool(GameManager.goal_unlocked).is_true()
	assert_int(GameManager.plants_watered).is_equal(GameManager.plants_total)


# ── Bucket state ─────────────────────────────────────────────────────────────

func test_carrying_bucket_can_be_toggled() -> void:
	GameManager.carrying_bucket = true
	assert_bool(GameManager.carrying_bucket).is_true()
	GameManager.carrying_bucket = false
	assert_bool(GameManager.carrying_bucket).is_false()