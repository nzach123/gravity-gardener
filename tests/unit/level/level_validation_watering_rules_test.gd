# V-BUCKET-SUM and V-PLANT-MIN (watering-system.md R8 and R5, AC7).
# Story 002 of the level-validation epic.
#
# Two properties of these rules are load-bearing and each has a test whose only
# job is to hold the line on it:
#
#   V-BUCKET-SUM compares two INDEPENDENTLY SOURCED quantities — bucket instances
#   counted in the scene, and the sum of plant exports. ADR-0002 is explicit that
#   the independence is the check. Both directions of mismatch are breaches:
#   watering-system.md R8 tabulates too many and too few buckets as separate
#   level-breaking failures, so a one-sided comparison is wrong.
#
#   V-PLANT-MIN reports PER PLANT, not once for the level. An author fixing three
#   zero-capacity plants must see three findings in one run — the same
#   report-all-failures reasoning that governs validate() as a whole.
#
# Assertions are on the bracketed CODE, never on message prose. Codes are
# contract; wording is not (ADR-0003 D3.4).
extends GdUnitTestSuite

# Declares every export the other implemented rules read, all valid, so that only
# the watering rules can fire here. Without this, a V-WIRING or V-OXY-CAP finding
# would contaminate every count below.
class WateringOnlyRoot extends Node2D:
	var oxygen_capacity: float = 90.0
	var default_gravity_direction: Vector2 = Vector2.DOWN
	var default_gravity_multiplier: float = 1.0
	var player: Node = null
	var goal: Node = null
	var hud: Node = null
	var level_bounds: Node = null


func _make_level() -> Node2D:
	var level := auto_free(WateringOnlyRoot.new()) as Node2D
	level.player = auto_free(Node2D.new())
	level.goal = auto_free(Node2D.new())
	level.hud = auto_free(Node2D.new())
	level.level_bounds = auto_free(Node2D.new())
	return level


func _add_plant(level: Node, node_name: String, required: int) -> Plant:
	var plant := Plant.new()
	plant.name = node_name
	plant.buckets_required = required
	level.add_child(plant)
	return plant


func _add_buckets(level: Node, count: int) -> void:
	for index: int in range(count):
		var bucket := Bucket.new()
		bucket.name = "Bucket%d" % index
		level.add_child(bucket)


func _codes(findings: PackedStringArray) -> Array[String]:
	var codes: Array[String] = []
	for finding: String in findings:
		var close := finding.find("]")
		codes.append(finding.substr(1, close - 1) if close > 0 else finding)
	return codes


func _count_code(findings: PackedStringArray, code: String) -> int:
	var total := 0
	for finding: String in findings:
		if finding.begins_with("[%s]" % code):
			total += 1
	return total


# ── the Plant export itself (story 002 adds it) ──────────────────────────────

func test_plant_declares_buckets_required_defaulting_to_one() -> void:
	var plant := auto_free(Plant.new()) as Plant
	assert_int(plant.buckets_required).is_equal(1)
	assert_int(typeof(plant.buckets_required)).is_equal(TYPE_INT)


# ── V-BUCKET-SUM ─────────────────────────────────────────────────────────────

func test_bucket_sum_passes_when_counts_agree() -> void:
	var level := _make_level()
	_add_plant(level, "Plant1", 2)
	_add_plant(level, "Plant2", 2)
	_add_buckets(level, 4)
	assert_array(_codes(LevelValidation.validate(level))) \
		.override_failure_message("4 buckets against a required sum of 4 must produce no finding.") \
		.is_empty()


func test_bucket_sum_fires_when_there_are_too_few_buckets() -> void:
	var level := _make_level()
	_add_plant(level, "Plant1", 2)
	_add_plant(level, "Plant2", 2)
	_add_buckets(level, 3)
	assert_array(_codes(LevelValidation.validate(level))).contains([LevelValidation.V_BUCKET_SUM])


func test_bucket_sum_fires_when_there_are_too_many_buckets() -> void:
	# The other direction. A one-sided `<` comparison would report this level
	# clean, and watering-system.md R8 calls it level-breaking.
	var level := _make_level()
	_add_plant(level, "Plant1", 2)
	_add_plant(level, "Plant2", 2)
	_add_buckets(level, 5)
	assert_array(_codes(LevelValidation.validate(level))).contains([LevelValidation.V_BUCKET_SUM])


func test_bucket_sum_counts_buckets_at_any_depth() -> void:
	# The two quantities must be gathered over the whole subtree, or a level that
	# parents its buckets under a container reports a false mismatch.
	var level := _make_level()
	_add_plant(level, "Plant1", 2)
	var container := Node2D.new()
	level.add_child(container)
	_add_buckets(container, 2)
	assert_array(_codes(LevelValidation.validate(level))).is_empty()


func test_bucket_sum_fires_once_not_per_plant() -> void:
	# The economy is a level-level quantity. Three findings for one imbalance
	# would bury the actual mismatch.
	var level := _make_level()
	_add_plant(level, "Plant1", 2)
	_add_plant(level, "Plant2", 2)
	_add_plant(level, "Plant3", 2)
	_add_buckets(level, 1)
	var findings := LevelValidation.validate(level)
	assert_int(_count_code(findings, LevelValidation.V_BUCKET_SUM)).is_equal(1)


func test_bucket_sum_fires_on_a_level_with_plants_and_no_buckets() -> void:
	var level := _make_level()
	_add_plant(level, "Plant1", 1)
	assert_array(_codes(LevelValidation.validate(level))).contains([LevelValidation.V_BUCKET_SUM])


func test_bucket_sum_passes_on_a_level_with_neither_plants_nor_buckets() -> void:
	# 0 == 0. An empty level breaches nothing here — whether an empty level is
	# desirable is a design question, not this rule.
	var level := _make_level()
	assert_array(_codes(LevelValidation.validate(level))).is_empty()


# ── V-PLANT-MIN ──────────────────────────────────────────────────────────────

func test_plant_min_fires_once_per_offending_plant() -> void:
	# Three zero-capacity plants, three findings, in one run.
	var level := _make_level()
	_add_plant(level, "Plant1", 0)
	_add_plant(level, "Plant2", -1)
	_add_plant(level, "Plant3", 0)
	var findings := LevelValidation.validate(level)
	assert_int(_count_code(findings, LevelValidation.V_PLANT_MIN)).is_equal(3)


func test_plant_min_names_the_offending_plant() -> void:
	# The message is not contract, but an author needs to find the plant. Assert
	# only that the name appears, not the surrounding wording.
	var level := _make_level()
	_add_plant(level, "ThirstyPlant", 0)
	var findings := LevelValidation.validate(level)
	var plant_min_findings: Array[String] = []
	for finding: String in findings:
		if finding.begins_with("[%s]" % LevelValidation.V_PLANT_MIN):
			plant_min_findings.append(finding)
	assert_int(plant_min_findings.size()).is_equal(1)
	assert_str(plant_min_findings[0]).contains("ThirstyPlant")


func test_plant_min_does_not_fire_at_the_lower_bound() -> void:
	# 1 is valid. An off-by-one here would make every default plant a breach.
	var level := _make_level()
	_add_plant(level, "Plant1", 1)
	_add_buckets(level, 1)
	assert_array(_codes(LevelValidation.validate(level))).is_empty()


func test_plant_min_fires_on_a_negative_value() -> void:
	var level := _make_level()
	_add_plant(level, "Plant1", -3)
	var findings := LevelValidation.validate(level)
	assert_int(_count_code(findings, LevelValidation.V_PLANT_MIN)).is_equal(1)


func test_plant_min_checks_plants_at_any_depth() -> void:
	var level := _make_level()
	var container := Node2D.new()
	level.add_child(container)
	_add_plant(container, "DeepPlant", 0)
	var findings := LevelValidation.validate(level)
	assert_int(_count_code(findings, LevelValidation.V_PLANT_MIN)).is_equal(1)


func test_both_watering_rules_fire_together() -> void:
	# One plant at 0 against one bucket breaches both rules at once, and both
	# must be reported — validate() never returns on the first breach.
	var level := _make_level()
	_add_plant(level, "Plant1", 0)
	_add_buckets(level, 1)
	var codes := _codes(LevelValidation.validate(level))
	assert_array(codes).contains([LevelValidation.V_PLANT_MIN, LevelValidation.V_BUCKET_SUM])
