# OxygenState suite — story LS-002, ADR-0002 Key Interfaces.
#
# Four things here are load-bearing and must not be weakened:
#
#   The assignment group (AC-5) asserts the OBSERVABLE truth for Godot 4.7.1: an
#   external write to a getter-only property is DISCARDED SILENTLY. It does not
#   assert that an error is raised. The 2026-08-26 probe
#   (production/qa/evidence/getter-only-assignment-probe-2026-08-26.md) drove
#   four assignment shapes against the 4.7.1 binary and got no parse error, no
#   runtime error and an unchanged backing field every time, with a live error
#   channel proven in the same run. Asserting a raise would fail against a
#   CORRECT implementation. OxygenState has no read-write field of its own, so a
#   LevelState.carrying_bucket write is used as the assignable negative control:
#   a green result then proves the test can tell a protected property from an
#   unprotected one rather than passing vacuously.
#
#   The no-refill group (AC-6) asserts by REFLECTION over the script method list,
#   never by reading source text. A source grep for "reset" passes on a method
#   named clear().
#
#   The two source-text tests are the exception, and are deliberate: "drain()
#   contains no conditional that lets a caller skip the decrement" and "the band
#   thresholds are not hardcoded" are both structural claims about the code, not
#   about behaviour, so no behavioural assertion can reach them. Both read
#   GDScript.source_code from a load(), never FileAccess, and both strip comment
#   lines first — the doc comments legitimately quote the GDD's threshold values.
#
#   Signals are recorded with plain connected callables rather than awaited, so
#   every test is synchronous, deterministic and frame-independent.
extends GdUnitTestSuite

const OXYGEN_STATE_SCRIPT_PATH: String = "res://src/scripts/oxygen_state.gd"

# Tolerance for every float comparison in this suite. AC-2 accumulates 600
# additions of 1.0/60.0, which cannot be expected to land on a bit-exact zero;
# the QA-plan addendum of 2026-08-25 requires the tolerance be stated rather
# than a bare == against zero.
const FLOAT_TOLERANCE: float = 1e-6

# The complete set of methods OxygenState is allowed to declare.
const ALLOWED_METHODS: Array[String] = ["_init", "drain", "_band_for"]

# Names that must never appear on the type. Every one of them is a refill or a
# reset path under a plausible-looking name.
const FORBIDDEN_METHODS: Array[String] = [
	"reset",
	"clear",
	"refill",
	"restore",
	"add_oxygen",
	"set_capacity",
	"set_remaining",
	"set_band",
]

# Band boundaries are asserted against the tuning resource, never against a
# literal — the same rule the implementation is held to.
var _tuning: OxygenTuning = Tuning.OXYGEN


# ── helpers ──────────────────────────────────────────────────────────────────

# Records every threshold_changed payload in emission order, as ints.
func _record_bands(state: OxygenState) -> Array[int]:
	var received: Array[int] = []
	state.threshold_changed.connect(
		func(emitted_band: OxygenState.Band) -> void:
			received.append(int(emitted_band))
	)
	return received


# Counts depleted emissions. An array is used rather than an int so the closure
# mutates a shared object rather than a captured copy.
func _record_depleted(state: OxygenState) -> Array[int]:
	var received: Array[int] = []
	state.depleted.connect(
		func() -> void:
			received.append(1)
	)
	return received


func _declared_method_names() -> Array[String]:
	var script: GDScript = load(OXYGEN_STATE_SCRIPT_PATH)
	var names: Array[String] = []
	for method: Dictionary in script.get_script_method_list():
		var method_name: String = String(method["name"])
		# Compiler-generated entries are prefixed with @.
		if not method_name.begins_with("@"):
			names.append(method_name)
	return names


# Every executable (non-comment, non-blank) line of the source, in order.
func _code_lines() -> Array[String]:
	var script: GDScript = load(OXYGEN_STATE_SCRIPT_PATH)
	var lines: Array[String] = []
	for raw: String in script.source_code.split("\n"):
		var stripped: String = raw.strip_edges()
		if stripped.is_empty() or stripped.begins_with("#"):
			continue
		lines.append(stripped)
	return lines


# The executable lines of drain()'s body, in order, comments already stripped.
func _drain_body_lines() -> Array[String]:
	var script: GDScript = load(OXYGEN_STATE_SCRIPT_PATH)
	var body: Array[String] = []
	var inside: bool = false
	for raw: String in script.source_code.split("\n"):
		var stripped: String = raw.strip_edges()
		if raw.begins_with("func drain("):
			inside = true
			continue
		if inside:
			if raw.begins_with("func ") or raw.begins_with("##"):
				break
			if stripped.is_empty() or stripped.begins_with("#"):
				continue
			body.append(stripped)
	return body


# ── AC-1 — non-positive capacity is not constructible into a usable object ───

func test_zero_capacity_produces_a_permanently_depleted_object() -> void:
	# Decided shape (Implementation Notes require one to be picked): push_error()
	# plus a poisoned object. assert() is forbidden by the control manifest — it
	# compiles out of release exports.
	var state: OxygenState = OxygenState.new(0.0, _tuning)
	assert_float(state.capacity).is_equal_approx(0.0, FLOAT_TOLERANCE)
	assert_float(state.remaining).is_equal_approx(0.0, FLOAT_TOLERANCE)
	assert_float(state.fraction) \
		.override_failure_message("fraction must guard the divide, not produce NAN or INF.") \
		.is_equal_approx(0.0, FLOAT_TOLERANCE)
	assert_int(state.band).is_equal(OxygenState.Band.CRITICAL)


func test_negative_capacity_produces_a_permanently_depleted_object() -> void:
	var state: OxygenState = OxygenState.new(-1.0, _tuning)
	assert_float(state.capacity) \
		.override_failure_message("A negative capacity must not be stored as given.") \
		.is_equal_approx(0.0, FLOAT_TOLERANCE)
	assert_float(state.remaining).is_equal_approx(0.0, FLOAT_TOLERANCE)
	assert_float(state.fraction).is_equal_approx(0.0, FLOAT_TOLERANCE)
	assert_int(state.band).is_equal(OxygenState.Band.CRITICAL)


func test_a_very_small_positive_capacity_is_accepted() -> void:
	# The rule is capacity > 0, not "above some sensible floor". 0.0001 is a
	# legal, if unplayable, level.
	var state: OxygenState = OxygenState.new(0.0001, _tuning)
	assert_float(state.capacity).is_equal_approx(0.0001, FLOAT_TOLERANCE)
	assert_float(state.remaining).is_equal_approx(0.0001, FLOAT_TOLERANCE)
	assert_float(state.fraction).is_equal_approx(1.0, FLOAT_TOLERANCE)
	assert_int(state.band) \
		.override_failure_message("A full tank is NOMINAL regardless of how small it is.") \
		.is_equal(OxygenState.Band.NOMINAL)


func test_a_poisoned_object_never_emits_depleted() -> void:
	# Documented consequence of emitting on the crossing only, with no boolean
	# latch: an object that starts at zero never crosses. OxygenDrain must read
	# remaining when it binds rather than wait for the signal.
	var state: OxygenState = OxygenState.new(0.0, _tuning)
	var depletions: Array[int] = _record_depleted(state)
	var bands: Array[int] = _record_bands(state)
	for _i: int in range(5):
		state.drain(1.0)
	assert_array(depletions).is_empty()
	assert_array(bands) \
		.override_failure_message("A poisoned object is CRITICAL from construction; it enters no band.") \
		.is_empty()


# ── AC-2 — draining to exactly zero ──────────────────────────────────────────

func test_six_hundred_sixtieth_second_drains_reach_zero_within_tolerance() -> void:
	# drain_rate is 1.0 in the tuning resource, so 600 * (1/60) == 10 seconds of
	# accumulated delta against a 10-second tank.
	var state: OxygenState = OxygenState.new(10.0, _tuning)
	for _i: int in range(600):
		state.drain(1.0 / 60.0)
	assert_float(state.remaining) \
		.override_failure_message(
			"600 drains of 1/60 s against a 10 s tank must land on zero within %f. Got %f."
			% [FLOAT_TOLERANCE, state.remaining]) \
		.is_equal_approx(0.0, FLOAT_TOLERANCE)
	assert_float(state.fraction).is_equal_approx(0.0, FLOAT_TOLERANCE)


func test_one_further_drain_leaves_remaining_at_zero_and_not_negative() -> void:
	var state: OxygenState = OxygenState.new(10.0, _tuning)
	for _i: int in range(601):
		state.drain(1.0 / 60.0)
	assert_float(state.remaining) \
		.override_failure_message("remaining went negative; the clamp at zero is missing.") \
		.is_greater_equal(0.0)
	assert_float(state.remaining).is_equal_approx(0.0, FLOAT_TOLERANCE)


# ── AC-3 — depleted emits exactly once ───────────────────────────────────────

func test_depleted_is_emitted_exactly_once_across_extra_drains() -> void:
	var state: OxygenState = OxygenState.new(1.0, _tuning)
	var depletions: Array[int] = _record_depleted(state)
	for _i: int in range(4):
		state.drain(0.5)
	for _i: int in range(10):
		state.drain(0.5)
	assert_int(depletions.size()) \
		.override_failure_message("depleted must fire once on the crossing, not once per call after it.") \
		.is_equal(1)


func test_a_single_oversized_drain_emits_depleted_exactly_once() -> void:
	var state: OxygenState = OxygenState.new(100.0, _tuning)
	var depletions: Array[int] = _record_depleted(state)
	state.drain(999.0)
	assert_float(state.remaining).is_equal_approx(0.0, FLOAT_TOLERANCE)
	assert_int(depletions.size()).is_equal(1)
	state.drain(999.0)
	assert_int(depletions.size()) \
		.override_failure_message("A second oversized drain re-emitted depleted.") \
		.is_equal(1)


# ── AC-4 — band transitions fire once per band, in order ─────────────────────

func test_band_is_nominal_at_construction() -> void:
	var state: OxygenState = OxygenState.new(100.0, _tuning)
	assert_int(state.band).is_equal(OxygenState.Band.NOMINAL)
	assert_float(state.fraction).is_equal_approx(1.0, FLOAT_TOLERANCE)


func test_continuous_drain_records_caution_warning_critical_in_order() -> void:
	var state: OxygenState = OxygenState.new(100.0, _tuning)
	var bands: Array[int] = _record_bands(state)
	for _i: int in range(100):
		state.drain(1.0)
	assert_array(bands) \
		.override_failure_message(
			"Draining a full tank to empty must enter each band once, in order. Got: %s" % [bands]) \
		.is_equal([
			OxygenState.Band.CAUTION,
			OxygenState.Band.WARNING,
			OxygenState.Band.CRITICAL,
		])
	assert_int(state.band).is_equal(OxygenState.Band.CRITICAL)


func test_a_double_band_crossing_emits_only_the_final_band() -> void:
	# DECISION, not a discovery: suit-oxygen.md does not say. A band that is
	# skipped is never entered, so it never fires. The emit is driven by
	# "recomputed band differs from current", which yields this naturally.
	var state: OxygenState = OxygenState.new(100.0, _tuning)
	var bands: Array[int] = _record_bands(state)
	state.drain(80.0)
	assert_array(bands) \
		.override_failure_message(
			"A jump from NOMINAL past CAUTION into WARNING must emit WARNING alone. Got: %s" % [bands]) \
		.is_equal([OxygenState.Band.WARNING])
	assert_int(state.band).is_equal(OxygenState.Band.WARNING)


func test_a_jump_from_full_to_empty_emits_critical_alone() -> void:
	var state: OxygenState = OxygenState.new(100.0, _tuning)
	var bands: Array[int] = _record_bands(state)
	state.drain(100.0)
	assert_array(bands).is_equal([OxygenState.Band.CRITICAL])


func test_a_fraction_exactly_on_the_caution_threshold_is_caution() -> void:
	# Boundary DECISION: the threshold value belongs to the LOWER band. This is
	# the GDD's own wording — suit-oxygen.md section 4 states
	# "nominal > 0.50 - caution <= 0.50 - warning <= 0.25 - critical <= 0.10".
	var state: OxygenState = OxygenState.new(100.0, _tuning)
	state.drain(100.0 * (1.0 - _tuning.threshold_caution))
	assert_float(state.fraction).is_equal_approx(_tuning.threshold_caution, FLOAT_TOLERANCE)
	assert_int(state.band) \
		.override_failure_message("A fraction exactly on threshold_caution must be CAUTION, not NOMINAL.") \
		.is_equal(OxygenState.Band.CAUTION)


func test_a_fraction_exactly_on_the_warning_threshold_is_warning() -> void:
	var state: OxygenState = OxygenState.new(100.0, _tuning)
	state.drain(100.0 * (1.0 - _tuning.threshold_warning))
	assert_float(state.fraction).is_equal_approx(_tuning.threshold_warning, FLOAT_TOLERANCE)
	assert_int(state.band) \
		.override_failure_message("A fraction exactly on threshold_warning must be WARNING, not CAUTION.") \
		.is_equal(OxygenState.Band.WARNING)


func test_a_fraction_exactly_on_the_critical_threshold_is_critical() -> void:
	var state: OxygenState = OxygenState.new(100.0, _tuning)
	state.drain(100.0 * (1.0 - _tuning.threshold_critical))
	assert_float(state.fraction).is_equal_approx(_tuning.threshold_critical, FLOAT_TOLERANCE)
	assert_int(state.band) \
		.override_failure_message("A fraction exactly on threshold_critical must be CRITICAL, not WARNING.") \
		.is_equal(OxygenState.Band.CRITICAL)


func test_a_band_already_entered_is_not_reemitted() -> void:
	var state: OxygenState = OxygenState.new(100.0, _tuning)
	var bands: Array[int] = _record_bands(state)
	state.drain(60.0)
	state.drain(5.0)
	state.drain(5.0)
	assert_array(bands) \
		.override_failure_message("CAUTION was re-emitted while already the current band. Got: %s" % [bands]) \
		.is_equal([OxygenState.Band.CAUTION])


# ── AC-5 — remaining never increases by any path ─────────────────────────────

func test_external_assignment_leaves_protected_properties_unchanged() -> void:
	# See the file header. This asserts the 4.7.1 observable behaviour — the
	# write is silently discarded — NOT that an error is raised.
	var state: OxygenState = OxygenState.new(100.0, _tuning)
	state.drain(10.0)

	state.capacity = 999.0
	state.remaining = 999.0
	state.fraction = 1.0
	state.band = OxygenState.Band.NOMINAL

	assert_float(state.capacity) \
		.override_failure_message("capacity was writable from outside the class.") \
		.is_equal_approx(100.0, FLOAT_TOLERANCE)
	assert_float(state.remaining) \
		.override_failure_message("remaining was writable from outside the class.") \
		.is_equal_approx(90.0, FLOAT_TOLERANCE)
	assert_float(state.fraction) \
		.override_failure_message("fraction was writable from outside the class.") \
		.is_equal_approx(0.9, FLOAT_TOLERANCE)
	assert_int(state.band).is_equal(OxygenState.Band.NOMINAL)

	# NEGATIVE CONTROL — OxygenState has no read-write field of its own, so a
	# genuinely assignable property on the sibling state object stands in. If the
	# engine were ignoring every write in this run, this assertion would fail and
	# expose the four above as a vacuous pass.
	var control: LevelState = LevelState.new(1)
	control.carrying_bucket = true
	assert_bool(control.carrying_bucket) \
		.override_failure_message(
			"The control property did not take an assignment, so the assertions " +
			"above prove nothing about protection.") \
		.is_true()


func test_object_set_leaves_protected_properties_unchanged() -> void:
	# The dynamic shape, which bypasses the static type entirely. Object.set()
	# returns void in 4.7.1 — capturing its result is itself a script error, so
	# the calls below deliberately discard it.
	var state: OxygenState = OxygenState.new(100.0, _tuning)
	state.drain(10.0)
	state.set("capacity", 999.0)
	state.set("remaining", 999.0)
	state.set("fraction", 1.0)
	state.set("band", OxygenState.Band.NOMINAL)
	assert_float(state.capacity).is_equal_approx(100.0, FLOAT_TOLERANCE)
	assert_float(state.remaining).is_equal_approx(90.0, FLOAT_TOLERANCE)
	assert_float(state.fraction).is_equal_approx(0.9, FLOAT_TOLERANCE)

	var control: LevelState = LevelState.new(1)
	control.set("carrying_bucket", true)
	assert_bool(control.carrying_bucket) \
		.override_failure_message("Object.set() reached nothing at all — vacuous pass.") \
		.is_true()


func test_a_negative_delta_does_not_increase_remaining() -> void:
	# The obvious back door into AC3, which the GDD does not mention. The single
	# clamping expression forbids it without a guard that could also let a caller
	# skip the decrement.
	var state: OxygenState = OxygenState.new(100.0, _tuning)
	state.drain(40.0)
	state.drain(-1.0)
	assert_float(state.remaining) \
		.override_failure_message("drain(-1.0) refilled the tank.") \
		.is_equal_approx(60.0, FLOAT_TOLERANCE)
	state.drain(-999.0)
	assert_float(state.remaining).is_equal_approx(60.0, FLOAT_TOLERANCE)


func test_a_negative_delta_after_depletion_does_not_refill() -> void:
	var state: OxygenState = OxygenState.new(10.0, _tuning)
	var depletions: Array[int] = _record_depleted(state)
	var bands: Array[int] = _record_bands(state)
	state.drain(10.0)
	state.drain(-50.0)
	assert_float(state.remaining).is_equal_approx(0.0, FLOAT_TOLERANCE)
	assert_int(state.band).is_equal(OxygenState.Band.CRITICAL)
	assert_int(depletions.size()).is_equal(1)
	assert_array(bands).is_equal([OxygenState.Band.CRITICAL])


func test_remaining_never_increases_across_a_mixed_call_sequence() -> void:
	var state: OxygenState = OxygenState.new(50.0, _tuning)
	var previous: float = state.remaining
	var deltas: Array[float] = [1.0, -1.0, 5.0, -100.0, 0.0, 20.0, -0.5, 40.0]
	for step_delta: float in deltas:
		state.drain(step_delta)
		assert_float(state.remaining) \
			.override_failure_message("remaining increased on drain(%f)." % step_delta) \
			.is_less_equal(previous)
		previous = state.remaining
	assert_float(previous).is_equal_approx(0.0, FLOAT_TOLERANCE)


# ── AC-6 — drain() holds no state checks ─────────────────────────────────────

func test_drain_decrements_before_any_branch_in_its_source() -> void:
	# Structural, because no behavioural assertion can reach "there is no
	# conditional that lets a caller skip the decrement" — a guard that happens
	# to be false in every tested state would pass every behavioural test. The
	# clamp at zero is permitted; a branch reached BEFORE the decrement, or any
	# early return, is not.
	var body: Array[String] = _drain_body_lines()
	assert_int(body.size()) \
		.override_failure_message("The drain() body scan came back empty — the extraction is broken.") \
		.is_greater(0)

	var decrement_index: int = -1
	var branch_index: int = -1
	for i: int in range(body.size()):
		var line: String = body[i]
		# Both assignment forms count. Recognising only `_remaining =` would fail
		# this suite against a behaviour-preserving refactor to `_remaining -=`,
		# which is still compliant — the detector must track the rule, not one
		# spelling of it.
		if decrement_index == -1 and (
			line.begins_with("_remaining =") or line.begins_with("_remaining -=")
		):
			decrement_index = i
		if branch_index == -1 and (
			line.begins_with("if ")
			or line.begins_with("elif ")
			or line.begins_with("match ")
			or line.begins_with("while ")
			or line.begins_with("for ")
			or line.begins_with("return")
		):
			branch_index = i

	assert_int(decrement_index) \
		.override_failure_message("drain() has no assignment to _remaining at all. Body: %s" % [body]) \
		.is_greater_equal(0)
	assert_bool(branch_index == -1 or branch_index > decrement_index) \
		.override_failure_message(
			"drain() branches before it decrements, so a caller can reach a state " +
			"where the clock stops (suit-oxygen.md R2, AC1). Body: %s" % [body]) \
		.is_true()
	for line: String in body:
		assert_bool(line.begins_with("return")) \
			.override_failure_message("drain() contains an early return: %s" % line) \
			.is_false()


func test_the_band_thresholds_are_not_hardcoded_in_the_source() -> void:
	# ADR-0006: the thresholds are the tuning resource's values. Comment lines are
	# stripped first — the doc comments legitimately quote the GDD's wording.
	# "0.5" and "0.1" are listed as well as "0.50" and "0.10", and they are the
	# reason this test has teeth. A developer hardcoding these thresholds writes
	# the short form — it is the idiomatic GDScript spelling and it is how
	# oxygen_tuning.gd spells the same defaults. An exact-string list of only the
	# padded forms passes against two thirds of the violation it exists to catch.
	# The short forms subsume the padded ones; both are kept for legibility.
	var forbidden_literals: Array[String] = ["0.50", "0.5", "0.25", "0.10", "0.1"]
	for line: String in _code_lines():
		for literal: String in forbidden_literals:
			assert_bool(line.contains(literal)) \
				.override_failure_message(
					"OxygenState hardcodes the band literal %s: %s" % [literal, line]) \
				.is_false()


func test_the_tuning_values_are_read_from_the_injected_resource() -> void:
	var source: String = "\n".join(_code_lines())
	for property_name: String in [
		"tuning.drain_rate",
		"tuning.threshold_caution",
		"tuning.threshold_warning",
		"tuning.threshold_critical",
	]:
		assert_str(source) \
			.override_failure_message("OxygenState never reads %s." % property_name) \
			.contains(property_name)


func test_the_source_never_writes_to_or_duplicates_the_tuning_resource() -> void:
	# tuning_resource_runtime_mutation, ADR-0006 D6.5.
	var source: String = "\n".join(_code_lines())
	assert_str(source).not_contains("duplicate()")
	for property_name: String in [
		"tuning.drain_rate =",
		"tuning.threshold_caution =",
		"tuning.threshold_warning =",
		"tuning.threshold_critical =",
	]:
		assert_str(source) \
			.override_failure_message("OxygenState writes to the tuning resource: %s" % property_name) \
			.not_contains(property_name)


func test_declared_methods_do_not_include_a_refill_path() -> void:
	var declared: Array[String] = _declared_method_names()
	assert_int(declared.size()) \
		.override_failure_message("The method scan came back empty — the reflection is broken.") \
		.is_greater(0)
	for forbidden: String in FORBIDDEN_METHODS:
		var message: String = (
			"OxygenState declares %s. Refill is object lifetime, not a function "
			% forbidden
			+ "(ADR-0002, forbidden pattern level_state_reset_method). Declared: %s"
			% [declared]
		)
		assert_array(declared).override_failure_message(message).not_contains([forbidden])


func test_declared_methods_are_exactly_init_drain_and_the_band_helper() -> void:
	# Stronger than the name blacklist: any new method — a setter, a refill under
	# another name, or policy leaking in from OxygenDrain — fails here.
	assert_array(_declared_method_names()) \
		.contains_exactly_in_any_order(ALLOWED_METHODS)


func test_oxygen_state_declares_exactly_its_two_signals() -> void:
	var script: GDScript = load(OXYGEN_STATE_SCRIPT_PATH)
	var signal_names: Array[String] = []
	for entry: Dictionary in script.get_script_signal_list():
		signal_names.append(String(entry["name"]))
	assert_array(signal_names) \
		.contains_exactly_in_any_order(["threshold_changed", "depleted"])


func test_oxygen_state_is_a_refcounted_and_not_a_node() -> void:
	# ADR-0002: a plain RefCounted constructed by LevelRoot, never an autoload,
	# never a Node in the tree. `state is Node` cannot be written — 4.7.1 rejects
	# it at PARSE time on a statically-typed RefCounted. The engine class name is
	# the runtime form of the same fact.
	var state: OxygenState = OxygenState.new(1.0, _tuning)
	assert_str(state.get_class()) \
		.override_failure_message("OxygenState must be a plain RefCounted (ADR-0002).") \
		.is_equal("RefCounted")
	assert_bool(ClassDB.is_parent_class(state.get_class(), "Node")).is_false()
