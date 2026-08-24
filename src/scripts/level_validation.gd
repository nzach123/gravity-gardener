## Pure, static load-time contract checks over a level subtree.
## Reads authored scene data only — never LevelState, OxygenState, or bind() output.
## Discovery is hand-rolled get_children() recursion by design.
## Do NOT substitute Node.find_children() — its `owned` defaults to true (D3.2, F3).
##
## validate() runs BEFORE state construction (ADR-0003 D3.1), because
## OxygenState._init rejects capacity <= 0: constructing state first would make a
## level that breaches V-OXY-CAP die during construction, and validation would
## never run on the one input that motivated it.
##
## It returns ALL breaches, never only the first. It pushes no errors and mutates
## nothing, so calling it twice is identical to calling it once. Logging the
## findings is the caller's job (ADR-0003 D3.4).
class_name LevelValidation
extends RefCounted

# Stable finding codes. Codes are contract; message prose is not. Tests assert on
# the bracketed code so wording can be improved without breaking a test.
const V_BUCKET_SUM  := "V-BUCKET-SUM"
const V_PLANT_MIN   := "V-PLANT-MIN"
const V_OXY_CAP     := "V-OXY-CAP"
const V_GRAV_EXPORT := "V-GRAV-EXPORT"
const V_PROP_BUDGET := "V-PROP-BUDGET"
const V_WIRING      := "V-WIRING"
const V_BOUNDS      := "V-BOUNDS"

# The V-WIRING required-consumer table (ADR-0003 D3.3).
#
# ADMISSION RULE: a consumer becomes required when the ADR that introduces it is
# Accepted. Add a row here in the same changeset as the ADR — do not ask.
#
#   player       ADR-0002 (Accepted)
#   goal         ADR-0002 (Accepted)
#   hud          ADR-0010 (Accepted — D10.9 moves this row, no new rule)
#   level_bounds ADR-0011 (Accepted — D11.7 admits this row)
#
# OxygenDrain is deliberately absent: ADR-0002 part 4 makes it a CHILD of
# LevelRoot, not an export, so there is no path for this rule to resolve. Its
# binding failure mode is covered by the ADR-0002 per-consumer guard instead.
const REQUIRED_CONSUMERS: Array[String] = [
	"player",
	"goal",
	"hud",
	"level_bounds",
]


## Returns every contract breach found, each prefixed with its stable code.
## An empty result means the level satisfies every implemented rule.
static func validate(level: Node) -> PackedStringArray:
	var findings := PackedStringArray()
	if level == null:
		return findings

	_check_watering_economy(level, findings)
	_check_root_exports(level, findings)
	_check_wiring(level, findings)
	# V-PROP-BUDGET (ADR-0006 / sprint LV-2) and V-BOUNDS (ADR-0011) are
	# specified with their constants in place above, and implemented in story
	# 006. No branch here yet — PropBody and LevelBounds do not exist.
	return findings


## The single definition of "a bucket in this level". Used by validate() for
## V-BUCKET-SUM and by LevelRoot to seed LevelState(buckets_total).
##
## One shared primitive is the point (ADR-0003 D3.5). With two independent
## counts, V-BUCKET-SUM could pass while LevelRoot seeded buckets_total from a
## subtly different number — a validation pass certifying a value the game does
## not actually use.
static func count_buckets(level: Node) -> int:
	return _collect(level, Bucket).size()


# ── rules ────────────────────────────────────────────────────────────────────

# V-BUCKET-SUM and V-PLANT-MIN (watering-system.md R8 and R5).
static func _check_watering_economy(level: Node, findings: PackedStringArray) -> void:
	var plants := _collect(level, Plant)

	# V-PLANT-MIN reports PER PLANT, not once for the level. An author fixing
	# three zero-capacity plants should see three findings in one run.
	for plant: Node in plants:
		var required := int(plant.get("buckets_required"))
		if required < 1:
			findings.append("[%s] Plant \"%s\" has buckets_required %d; must be >= 1" % [
				V_PLANT_MIN, plant.name, required,
			])

	# V-BUCKET-SUM compares two INDEPENDENTLY SOURCED quantities, and that
	# independence is the whole check (ADR-0002: "agreement is the check").
	# Never derive one side from the other — that turns evidence into a
	# tautology that passes on every level.
	var buckets_total := count_buckets(level)
	var required_total := 0
	for plant: Node in plants:
		required_total += int(plant.get("buckets_required"))

	# Both directions are breaches. watering-system.md R8 tabulates too many and
	# too few buckets as separate level-breaking failures, so a one-sided
	# comparison is wrong.
	if buckets_total != required_total:
		findings.append("[%s] buckets_total %d != sum(buckets_required) %d" % [
			V_BUCKET_SUM, buckets_total, required_total,
		])


# V-OXY-CAP and V-GRAV-EXPORT (suit-oxygen.md §5; ADR-0001 delegated, gravity.md R7).
#
# Every export is read through Node.get(), which returns null for a property the
# level does not declare. An ABSENT export is a genuine breach of the same rule,
# not a separate condition to skip: a level with no oxygen_capacity is exactly as
# unplayable as one with oxygen_capacity = 0.
static func _check_root_exports(level: Node, findings: PackedStringArray) -> void:
	var capacity: Variant = level.get("oxygen_capacity")
	if capacity == null:
		findings.append("[%s] oxygen_capacity export is missing; must be > 0 (suit-oxygen.md §5)" % V_OXY_CAP)
	elif float(capacity) <= 0.0:
		findings.append("[%s] oxygen_capacity is %s; must be > 0 (suit-oxygen.md §5)" % [
			V_OXY_CAP, float(capacity),
		])

	var direction: Variant = level.get("default_gravity_direction")
	if direction == null:
		findings.append("[%s] default_gravity_direction export is missing; must be non-zero (gravity.md R7)" % V_GRAV_EXPORT)
	elif (direction as Vector2) == Vector2.ZERO:
		findings.append("[%s] default_gravity_direction is the zero vector; must be non-zero (gravity.md R7)" % V_GRAV_EXPORT)

	var multiplier: Variant = level.get("default_gravity_multiplier")
	if multiplier == null:
		findings.append("[%s] default_gravity_multiplier export is missing; must be > 0 (gravity.md R7)" % V_GRAV_EXPORT)
	elif float(multiplier) <= 0.0:
		findings.append("[%s] default_gravity_multiplier is %s; must be > 0 (gravity.md R7)" % [
			V_GRAV_EXPORT, float(multiplier),
		])


# V-WIRING (ADR-0002 delegated).
#
# This checks WIRING, not BINDING. Under D3.1 validate() runs at step (a) and
# bind() at step (c), so binding has not happened and cannot be observed. What
# can be observed is that each required export holds a live node — the condition
# under which step (c) will succeed. A consumer that is wired but whose bind()
# call was never written is caught later by the ADR-0002 per-consumer guard.
# The two checks are complementary; neither subsumes the other.
static func _check_wiring(level: Node, findings: PackedStringArray) -> void:
	for export_name: String in REQUIRED_CONSUMERS:
		var value: Variant = level.get(export_name)
		# Absent, null and empty are the same condition: the level is not wired.
		if value == null:
			findings.append("[%s] required consumer export \"%s\" is unset (ADR-0003 D3.3)" % [
				V_WIRING, export_name,
			])
			continue

		# Two authoring shapes reach here and both must resolve. ADR-0003 D3.3
		# describes NodePath exports; main.gd today uses direct typed node
		# references (@export var player: Player). Accepting only one shape would
		# report every level of the other shape unwired.
		if value is NodePath:
			var path := value as NodePath
			if path.is_empty():
				findings.append("[%s] required consumer export \"%s\" is unset (ADR-0003 D3.3)" % [
					V_WIRING, export_name,
				])
			elif level.get_node_or_null(path) == null:
				findings.append("[%s] required consumer export \"%s\" does not resolve to a live node (ADR-0003 D3.3)" % [
					V_WIRING, export_name,
				])
			continue

		# Resolution, not binding: the value must be a live Node. Do not call a
		# method on it and do not inspect it further.
		var node := value as Node
		if node == null or not is_instance_valid(node):
			findings.append("[%s] required consumer export \"%s\" does not resolve to a live node (ADR-0003 D3.3)" % [
				V_WIRING, export_name,
			])


# ── discovery ────────────────────────────────────────────────────────────────

# Depth-first type scan over get_children(). Adding a matched type is one call
# site — pass a different script.
#
# NOT get_nodes_in_group(): group membership is invisible bookkeeping, so a node
# an author forgot to add is invisible to validation and the level reports clean
# while shipping unwinnable. And technically get_nodes_in_group() is a SceneTree
# method — the CI path instantiates a level and never adds it to a tree, so it is
# not merely risky there, it is unavailable (ADR-0003 D3.2).
#
# NOT Node.find_children(): its `owned` parameter DEFAULTS TO TRUE, which
# silently drops descendants without a valid owner and reintroduces the same
# silent-miss failure by a different route (ADR-0003 F3, a forbidden pattern).
static func _collect(root: Node, type: Script) -> Array[Node]:
	var found: Array[Node] = []
	if root == null:
		return found
	_collect_into(root, type, found)
	return found


static func _collect_into(node: Node, type: Script, found: Array[Node]) -> void:
	for child: Node in node.get_children():
		if is_instance_of(child, type):
			found.append(child)
		_collect_into(child, type, found)
