# V-OXY-CAP and V-GRAV-EXPORT (suit-oxygen.md §5 and AC7; ADR-0001 delegated,
# gravity.md R7). Story 003 of the level-validation epic.
#
# Both rules read @export values on the level root BEFORE any state object is
# constructed (ADR-0003 D3.1). That ordering is not a preference: OxygenState._init
# rejects capacity <= 0, so constructing state first would kill a level that
# breaches V-OXY-CAP during construction, and validation would never run on the
# one input that motivated the whole report-all-failures guarantee.
#
# THE ABSENT-EXPORT CASE IS THE INTERESTING ONE. main.gd today declares neither
# oxygen_capacity nor default_gravity_* — those exports arrive with the
# level-state and gravity-authority epics. validate() takes `level: Node`, so a
# missing property is a runtime read returning null, not a parse error. An absent
# export is a genuine authoring breach of the SAME rule: a level with no
# oxygen_capacity is exactly as unplayable as one with oxygen_capacity = 0. A rule
# that skipped the absent case would report every shipped level clean today.
extends GdUnitTestSuite

# Declares nothing. Stands in for main.gd as it is today.
class BareRoot extends Node2D:
	pass


# Every export present and valid, so a single knob can be moved per test.
class ExportRoot extends Node2D:
	var oxygen_capacity: float = 90.0
	var default_gravity_direction: Vector2 = Vector2.DOWN
	var default_gravity_multiplier: float = 1.0
	var player: Node = null
	var goal: Node = null
	var hud: Node = null
	var level_bounds: Node = null


# Declares the gravity exports but not oxygen_capacity, so the absent-oxygen case
# can be isolated from the absent-gravity case.
class NoOxygenRoot extends Node2D:
	var default_gravity_direction: Vector2 = Vector2.DOWN
	var default_gravity_multiplier: float = 1.0
	var player: Node = null
	var goal: Node = null
	var hud: Node = null
	var level_bounds: Node = null


func _wire(level: Node) -> Node:
	level.set("player", auto_free(Node2D.new()))
	level.set("goal", auto_free(Node2D.new()))
	level.set("hud", auto_free(Node2D.new()))
	level.set("level_bounds", auto_free(Node2D.new()))
	return level


func _make_valid_root() -> Node2D:
	return _wire(auto_free(ExportRoot.new())) as Node2D


func _count_code(findings: PackedStringArray, code: String) -> int:
	var total := 0
	for finding: String in findings:
		if finding.begins_with("[%s]" % code):
			total += 1
	return total


func _has_code(findings: PackedStringArray, code: String) -> bool:
	return _count_code(findings, code) > 0


# ── V-OXY-CAP ────────────────────────────────────────────────────────────────

func test_oxy_cap_passes_on_a_positive_capacity() -> void:
	var level := _make_valid_root()
	assert_bool(_has_code(LevelValidation.validate(level), LevelValidation.V_OXY_CAP)).is_false()


func test_oxy_cap_fires_on_zero_capacity() -> void:
	var level := _make_valid_root()
	level.set("oxygen_capacity", 0.0)
	assert_int(_count_code(LevelValidation.validate(level), LevelValidation.V_OXY_CAP)).is_equal(1)


func test_oxy_cap_fires_on_negative_capacity() -> void:
	var level := _make_valid_root()
	level.set("oxygen_capacity", -10.0)
	assert_int(_count_code(LevelValidation.validate(level), LevelValidation.V_OXY_CAP)).is_equal(1)


func test_oxy_cap_fires_when_the_export_is_absent() -> void:
	# The case that matters today. A rule that treated "no such property" as
	# "nothing to check" would pass every shipped level.
	var level := _wire(auto_free(NoOxygenRoot.new()))
	var findings := LevelValidation.validate(level)
	assert_int(_count_code(findings, LevelValidation.V_OXY_CAP)).is_equal(1)


func test_oxy_cap_absent_finding_says_missing_rather_than_reporting_a_value() -> void:
	# An author reading "oxygen_capacity is 0.0" would go looking for a zero in
	# the inspector and find no field at all. The two causes need distinct prose
	# even though they share a code.
	var level := _wire(auto_free(NoOxygenRoot.new()))
	for finding: String in LevelValidation.validate(level):
		if finding.begins_with("[%s]" % LevelValidation.V_OXY_CAP):
			assert_str(finding).contains("missing")
			return
	fail("No V-OXY-CAP finding was produced for a level with no oxygen_capacity export.")


func test_oxy_cap_does_not_fire_just_above_zero() -> void:
	# The boundary is > 0, not >= some floor. 0.1 is a terrible level and a
	# valid one; difficulty is not this rule's business.
	var level := _make_valid_root()
	level.set("oxygen_capacity", 0.1)
	assert_bool(_has_code(LevelValidation.validate(level), LevelValidation.V_OXY_CAP)).is_false()


# ── V-GRAV-EXPORT ────────────────────────────────────────────────────────────

func test_grav_export_passes_on_valid_exports() -> void:
	var level := _make_valid_root()
	assert_bool(_has_code(LevelValidation.validate(level), LevelValidation.V_GRAV_EXPORT)).is_false()


func test_grav_export_fires_on_a_zero_direction_vector() -> void:
	var level := _make_valid_root()
	level.set("default_gravity_direction", Vector2.ZERO)
	assert_int(_count_code(LevelValidation.validate(level), LevelValidation.V_GRAV_EXPORT)).is_equal(1)


func test_grav_export_fires_on_a_zero_multiplier() -> void:
	var level := _make_valid_root()
	level.set("default_gravity_multiplier", 0.0)
	assert_int(_count_code(LevelValidation.validate(level), LevelValidation.V_GRAV_EXPORT)).is_equal(1)


func test_grav_export_fires_on_a_negative_multiplier() -> void:
	var level := _make_valid_root()
	level.set("default_gravity_multiplier", -1.0)
	assert_int(_count_code(LevelValidation.validate(level), LevelValidation.V_GRAV_EXPORT)).is_equal(1)


func test_grav_export_accepts_a_non_down_direction() -> void:
	# The rule is non-zero, not "points down". A level whose default gravity is
	# sideways is the entire premise of this game.
	var level := _make_valid_root()
	level.set("default_gravity_direction", Vector2.LEFT)
	assert_bool(_has_code(LevelValidation.validate(level), LevelValidation.V_GRAV_EXPORT)).is_false()


func test_grav_export_reports_both_halves_when_both_are_wrong() -> void:
	# Two independent conditions share one code. An author with both wrong must
	# see both, or fixing the first reveals the second on the next run.
	var level := _make_valid_root()
	level.set("default_gravity_direction", Vector2.ZERO)
	level.set("default_gravity_multiplier", 0.0)
	assert_int(_count_code(LevelValidation.validate(level), LevelValidation.V_GRAV_EXPORT)).is_equal(2)


func test_grav_export_fires_twice_when_both_exports_are_absent() -> void:
	var level := _wire(auto_free(BareRoot.new()))
	assert_int(_count_code(LevelValidation.validate(level), LevelValidation.V_GRAV_EXPORT)).is_equal(2)


# ── the two rules together ───────────────────────────────────────────────────

func test_a_bare_root_breaches_both_rules_at_once() -> void:
	# This is main.gd as it stands. Three findings: one absent oxygen_capacity,
	# two absent gravity exports. Recorded so the migration cost is visible in a
	# test rather than discovered during the level migration epic.
	var level := _wire(auto_free(BareRoot.new()))
	var findings := LevelValidation.validate(level)
	assert_int(_count_code(findings, LevelValidation.V_OXY_CAP)).is_equal(1)
	assert_int(_count_code(findings, LevelValidation.V_GRAV_EXPORT)).is_equal(2)
