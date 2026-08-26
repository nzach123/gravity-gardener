# LevelState suite — story LS-001, ADR-0002 Key Interfaces.
#
# Two things here are load-bearing and must not be weakened:
#
#   The assignment group (AC-4) asserts the OBSERVABLE truth for Godot 4.7.1: an
#   external write to a getter-only property is DISCARDED SILENTLY. It does not
#   assert that an error is raised. The 2026-08-26 probe
#   (production/qa/evidence/getter-only-assignment-probe-2026-08-26.md) drove
#   four assignment shapes against the 4.7.1 binary and got no parse error, no
#   runtime error and an unchanged backing field every time, with a live error
#   channel proven in the same run. Asserting a raise would fail against a
#   CORRECT implementation. carrying_bucket is asserted in the same test as the
#   assignable negative control, so a green result proves the test can still tell
#   a protected field from an unprotected one rather than passing vacuously.
#
#   The no-reset group (AC-6) asserts by REFLECTION over the script method list,
#   never by reading source text. A source grep for "reset" passes on a method
#   named clear().
#
# Signals are recorded with plain connected callables rather than awaited, so
# every test is synchronous, deterministic and frame-independent.
extends GdUnitTestSuite

const LEVEL_STATE_SCRIPT_PATH: String = "res://src/scripts/level_state.gd"

# The complete set of methods LevelState is allowed to declare. mark_complete()
# is story 005 and must fail this list until that story lands and updates it.
const ALLOWED_METHODS: Array[String] = ["_init", "consume_bucket"]

# Names that must never appear on the type. level_state_reset_method is a
# recorded forbidden pattern precisely because adding one looks reasonable.
const FORBIDDEN_METHODS: Array[String] = [
	"reset",
	"clear",
	"set_buckets_total",
	"set_buckets_consumed",
	"set_goal_unlocked",
	"set_level_complete",
]


# ── helpers ──────────────────────────────────────────────────────────────────

# Records every goal_unlocked_changed payload in call order.
func _record_unlocked(state: LevelState) -> Array[bool]:
	var received: Array[bool] = []
	state.goal_unlocked_changed.connect(
		func(unlocked: bool) -> void:
			received.append(unlocked)
	)
	return received


# Records every bucket_consumed payload as [consumed, total] pairs, in order.
func _record_consumed(state: LevelState) -> Array[Vector2i]:
	var received: Array[Vector2i] = []
	state.bucket_consumed.connect(
		func(consumed: int, total: int) -> void:
			received.append(Vector2i(consumed, total))
	)
	return received


# Records BOTH signals into one array, in emission order. The two recorders above
# are used in separate tests, so each is blind to the other signal and neither can
# observe the relative order of two emits inside a single consume_bucket() call.
func _record_both(state: LevelState) -> Array[String]:
	var order: Array[String] = []
	state.bucket_consumed.connect(
		func(consumed: int, _total: int) -> void:
			order.append("bucket_consumed:%d" % consumed)
	)
	state.goal_unlocked_changed.connect(
		func(unlocked: bool) -> void:
			order.append("goal_unlocked_changed:%s" % unlocked)
	)
	return order


func _declared_method_names() -> Array[String]:
	var script: GDScript = load(LEVEL_STATE_SCRIPT_PATH)
	var names: Array[String] = []
	for method: Dictionary in script.get_script_method_list():
		var method_name: String = String(method["name"])
		# Compiler-generated entries are prefixed with @.
		if not method_name.begins_with("@"):
			names.append(method_name)
	return names


# ── AC-1 — goal_unlocked flips exactly at the boundary ───────────────────────

func test_goal_unlocked_is_false_before_the_last_bucket() -> void:
	var state: LevelState = LevelState.new(3)
	assert_bool(state.goal_unlocked).is_false()
	state.consume_bucket()
	state.consume_bucket()
	assert_bool(state.goal_unlocked) \
		.override_failure_message("goal_unlocked went true at 2 of 3 buckets.") \
		.is_false()


func test_goal_unlocked_is_true_after_the_last_bucket() -> void:
	var state: LevelState = LevelState.new(3)
	state.consume_bucket()
	state.consume_bucket()
	state.consume_bucket()
	assert_bool(state.goal_unlocked).is_true()
	assert_int(state.buckets_consumed).is_equal(3)


func test_goal_unlocked_is_true_from_construction_when_total_is_zero() -> void:
	# 0 >= 0. A level with no plants is legal at this layer (ADR-0003 owns the
	# authoring judgement, not this type).
	var state: LevelState = LevelState.new(0)
	assert_bool(state.goal_unlocked).is_true()
	assert_int(state.buckets_total).is_equal(0)
	assert_int(state.buckets_consumed).is_equal(0)


func test_goal_unlocked_flips_on_the_first_bucket_when_total_is_one() -> void:
	var state: LevelState = LevelState.new(1)
	assert_bool(state.goal_unlocked).is_false()
	state.consume_bucket()
	assert_bool(state.goal_unlocked).is_true()


# ── AC-2 — goal_unlocked_changed fires on the transition only ────────────────

func test_goal_unlocked_changed_is_emitted_once_with_true() -> void:
	var state: LevelState = LevelState.new(2)
	var received: Array[bool] = _record_unlocked(state)
	state.consume_bucket()
	state.consume_bucket()
	state.consume_bucket()
	assert_array(received) \
		.override_failure_message(
			"goal_unlocked_changed must fire exactly once, with true. Got: %s" % [received]) \
		.is_equal([true])


func test_goal_unlocked_changed_is_not_reemitted_on_a_fourth_call() -> void:
	var state: LevelState = LevelState.new(2)
	var received: Array[bool] = _record_unlocked(state)
	for _i: int in range(4):
		state.consume_bucket()
	assert_int(received.size()).is_equal(1)


func test_goal_unlocked_changed_is_silent_before_the_transition() -> void:
	var state: LevelState = LevelState.new(2)
	var received: Array[bool] = _record_unlocked(state)
	state.consume_bucket()
	assert_array(received) \
		.override_failure_message("goal_unlocked_changed fired at 1 of 2 buckets.") \
		.is_empty()


func test_zero_total_never_emits_goal_unlocked_changed() -> void:
	# Documented decision, not an oversight: a signal emitted inside _init()
	# cannot be received, since nothing is connected yet. The zero-bucket level
	# is unlocked from construction and consumers must READ goal_unlocked when
	# they bind rather than wait for the signal.
	var state: LevelState = LevelState.new(0)
	var received: Array[bool] = _record_unlocked(state)
	state.consume_bucket()
	assert_bool(state.goal_unlocked).is_true()
	assert_array(received).is_empty()


# ── AC-3 — buckets_consumed is bounded and monotonic ─────────────────────────

func test_buckets_consumed_never_exceeds_buckets_total() -> void:
	var state: LevelState = LevelState.new(2)
	for _i: int in range(5):
		state.consume_bucket()
	assert_int(state.buckets_consumed) \
		.override_failure_message("buckets_consumed ran past buckets_total.") \
		.is_equal(2)
	assert_int(state.buckets_total).is_equal(2)


func test_buckets_consumed_never_decreases_across_a_call_sequence() -> void:
	var state: LevelState = LevelState.new(3)
	var previous: int = state.buckets_consumed
	for _i: int in range(6):
		state.consume_bucket()
		assert_int(state.buckets_consumed) \
			.override_failure_message("buckets_consumed decreased.") \
			.is_greater_equal(previous)
		previous = state.buckets_consumed
	assert_int(previous).is_equal(3)


func test_bucket_consumed_is_not_emitted_past_the_cap() -> void:
	var state: LevelState = LevelState.new(2)
	var received: Array[Vector2i] = _record_consumed(state)
	for _i: int in range(5):
		state.consume_bucket()
	assert_array(received).is_equal([Vector2i(1, 2), Vector2i(2, 2)])


func test_consume_bucket_on_a_zero_total_level_is_a_no_op() -> void:
	var state: LevelState = LevelState.new(0)
	var received: Array[Vector2i] = _record_consumed(state)
	state.consume_bucket()
	assert_int(state.buckets_consumed).is_equal(0)
	assert_array(received).is_empty()


# ── AC-4 — the getter-only properties cannot be written from outside ─────────

func test_external_assignment_leaves_protected_properties_unchanged() -> void:
	# See the file header. This asserts the 4.7.1 observable behaviour — the
	# write is silently discarded — NOT that an error is raised. carrying_bucket
	# in the same test is the negative control: if the engine were ignoring every
	# write, that assertion would fail and expose the vacuous pass.
	var state: LevelState = LevelState.new(3)
	state.consume_bucket()

	state.buckets_total = 99
	state.buckets_consumed = 99
	state.goal_unlocked = true
	state.level_complete = true

	assert_int(state.buckets_total) \
		.override_failure_message("buckets_total was writable from outside the class.") \
		.is_equal(3)
	assert_int(state.buckets_consumed) \
		.override_failure_message("buckets_consumed was writable from outside the class.") \
		.is_equal(1)
	assert_bool(state.goal_unlocked) \
		.override_failure_message("goal_unlocked was writable from outside the class.") \
		.is_false()
	assert_bool(state.level_complete) \
		.override_failure_message("level_complete was writable from outside the class.") \
		.is_false()

	# NEGATIVE CONTROL — the one field that is genuinely read-write.
	state.carrying_bucket = true
	assert_bool(state.carrying_bucket) \
		.override_failure_message(
			"carrying_bucket did not take an assignment, so the four assertions " +
			"above prove nothing about protection.") \
		.is_true()
	state.carrying_bucket = false
	assert_bool(state.carrying_bucket).is_false()


func test_object_set_leaves_protected_properties_unchanged() -> void:
	# The dynamic shape, which bypasses the static type entirely. Object.set()
	# returns void in 4.7.1 — capturing its result is itself a script error, so
	# the calls below deliberately discard it.
	var state: LevelState = LevelState.new(2)
	state.set("buckets_total", 99)
	state.set("buckets_consumed", 99)
	state.set("goal_unlocked", true)
	state.set("level_complete", true)
	assert_int(state.buckets_total).is_equal(2)
	assert_int(state.buckets_consumed).is_equal(0)
	assert_bool(state.goal_unlocked).is_false()
	assert_bool(state.level_complete).is_false()

	state.set("carrying_bucket", true)
	assert_bool(state.carrying_bucket) \
		.override_failure_message("Object.set() reached nothing at all — vacuous pass.") \
		.is_true()


func test_carrying_bucket_defaults_to_false() -> void:
	var state: LevelState = LevelState.new(1)
	assert_bool(state.carrying_bucket).is_false()


# ── AC-5 — bucket_consumed carries both numbers ──────────────────────────────

func test_bucket_consumed_carries_consumed_and_total() -> void:
	var state: LevelState = LevelState.new(3)
	var received: Array[Vector2i] = _record_consumed(state)
	state.consume_bucket()
	assert_array(received).is_equal([Vector2i(1, 3)])


func test_bucket_consumed_reports_each_pour_in_order() -> void:
	var state: LevelState = LevelState.new(3)
	var received: Array[Vector2i] = _record_consumed(state)
	state.consume_bucket()
	state.consume_bucket()
	state.consume_bucket()
	assert_array(received).is_equal([Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3)])


# ── Signal emission order within one consume_bucket() call ───────────────────
# Not named by any acceptance criterion. Added 2026-08-26 from the LS-001 code
# review, which found the order observable to consumers but unpinned by any test.

func test_bucket_consumed_is_emitted_before_goal_unlocked_changed() -> void:
	# The order is observable to every consumer binding both signals. A HUD that
	# received goal_unlocked_changed first would light the goal indicator while
	# its bucket counter still read one short. LS-004 binds both.
	var state: LevelState = LevelState.new(2)
	var order: Array[String] = _record_both(state)
	state.consume_bucket()
	state.consume_bucket()
	assert_array(order) \
		.override_failure_message(
			"consume_bucket() must emit bucket_consumed BEFORE " +
			"goal_unlocked_changed on the transition call. Got: %s" % [order]) \
		.is_equal([
			"bucket_consumed:1",
			"bucket_consumed:2",
			"goal_unlocked_changed:true",
		])


# ── AC-6 — the type has no reset path (reflection, not source text) ──────────

func test_declared_methods_do_not_include_a_reset_path() -> void:
	var declared: Array[String] = _declared_method_names()
	assert_int(declared.size()) \
		.override_failure_message("The method scan came back empty — the reflection is broken.") \
		.is_greater(0)
	for forbidden: String in FORBIDDEN_METHODS:
		var message: String = (
			"LevelState declares %s. Restart is object lifetime, not a clear "
			% forbidden
			+ "function (ADR-0002, forbidden pattern level_state_reset_method). "
			+ "Declared: %s" % [declared]
		)
		assert_array(declared).override_failure_message(message).not_contains([forbidden])


func test_declared_methods_are_exactly_init_and_consume_bucket() -> void:
	# Stronger than the name blacklist: any new method — a setter, a clear under
	# another name, or mark_complete() arriving early — fails here. Story 005
	# updates ALLOWED_METHODS when it lands the latch.
	assert_array(_declared_method_names()) \
		.contains_exactly_in_any_order(ALLOWED_METHODS)


func test_level_state_declares_exactly_its_two_signals() -> void:
	var script: GDScript = load(LEVEL_STATE_SCRIPT_PATH)
	var signal_names: Array[String] = []
	for entry: Dictionary in script.get_script_signal_list():
		signal_names.append(String(entry["name"]))
	assert_array(signal_names) \
		.contains_exactly_in_any_order(["goal_unlocked_changed", "bucket_consumed"])


func test_level_state_is_a_refcounted_and_not_a_node() -> void:
	# ADR-0002: a plain RefCounted constructed by LevelRoot, never an autoload,
	# never a Node in the tree.
	# `state is Node` cannot be written — 4.7.1 rejects it at PARSE time
	# ("Expression is of type LevelState so it can't be of type Node"), which is a
	# stronger guarantee than a runtime assertion but not one a test can hold. The
	# engine class name is the runtime form of the same fact.
	var state: LevelState = LevelState.new(1)
	assert_str(state.get_class()) \
		.override_failure_message("LevelState must be a plain RefCounted (ADR-0002).") \
		.is_equal("RefCounted")
	assert_bool(ClassDB.is_parent_class(state.get_class(), "Node")).is_false()


# ── Negative construction — the clamp added by LS-001, kept by developer decision
# on 2026-08-26. Outside the story's written scope: the story and ADR-0002 state
# only "callers must pass buckets_total >= 0", making a negative a caller bug with
# no defined behaviour. It is kept because the silent alternative is worse — with
# no clamp, `_goal_unlocked = (0 >= -3)` is true, so a mis-authored level would
# unlock its goal at construction with no diagnostic at all. push_error() makes the
# caller bug loud; the clamp makes the resulting state coherent.

func test_a_negative_total_is_clamped_to_zero() -> void:
	var state: LevelState = LevelState.new(-3)
	assert_int(state.buckets_total) \
		.override_failure_message(
			"A negative buckets_total must be clamped to 0, not stored as given."
		) \
		.is_equal(0)


func test_a_negative_total_leaves_the_goal_coherent_not_corrupt() -> void:
	# The point of the clamp: consumed(0) >= total(0) is a defensible unlocked
	# state, whereas consumed(0) >= total(-3) would be unlocked for the wrong
	# reason and consume_bucket() would be a permanent no-op.
	var state: LevelState = LevelState.new(-3)
	assert_bool(state.goal_unlocked).is_true()
	assert_int(state.buckets_consumed).is_equal(0)

	# Still inert afterwards, exactly as a zero-total level is.
	state.consume_bucket()
	assert_int(state.buckets_consumed).is_equal(0)
	assert_int(state.buckets_total).is_equal(0)
