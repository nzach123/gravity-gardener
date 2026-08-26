## Level-scoped suit oxygen, owned by `LevelRoot` (ADR-0002).
##
## A plain `RefCounted`: never an autoload, never a singleton, never reachable
## globally. `LevelRoot._ready()` constructs one and injects it into every
## consumer; `reload_current_scene()` frees `LevelRoot`, which frees this object,
## which is why the type has no `reset()`, no refill and no setter
## (`suit-oxygen.md` AC3, AC4, AC5, forbidden pattern `level_state_reset_method`).
##
## Every externally-visible value is a getter-only computed property over a
## private backing field. Engine note for 4.7.1: an external write to a
## getter-only property is discarded SILENTLY — it neither succeeds nor raises
## (evidence: `production/qa/evidence/getter-only-assignment-probe-2026-08-26.md`).
## The safety guarantee holds; the diagnostic ADR-0002:291 claims does not. The
## shape below is therefore built for the safety reason, not the detection reason,
## and deliberately adds no error-raising setters.
##
## Band thresholds and the drain rate are read once from the injected
## [OxygenTuning] at construction. Nothing here writes to that resource and
## nothing here duplicates it (ADR-0006 D6.5, forbidden pattern
## `tuning_resource_runtime_mutation`), and the three band fractions are never
## hardcoded in this file.
##
## [method drain] carries no policy. It does not decide death, it does not check
## a paused flag and it does not check `level_complete`. [signal depleted] is a
## pure STATE signal meaning "the tank is empty"; `OxygenDrain` owns the kill
## decision and the completion suppression (ADR-0008, ADR-0005 D5.6), and it
## freezes the clock by not calling [method drain], never by [method drain]
## refusing (`suit-oxygen.md` R2, AC1).
class_name OxygenState
extends RefCounted

## Feedback bands, ordered from full to empty. The band a fraction belongs to is
## decided by [method _band_for]; see there for the boundary rule.
enum Band { NOMINAL, CAUTION, WARNING, CRITICAL }

## Emitted once per band ENTERED, carrying the new band. Never re-emitted for a
## band already current, and never emitted at construction — a signal emitted
## inside `_init()` cannot be received, because nothing is connected yet.
## Consumers must read [member band] when they bind.
##
## A single [method drain] large enough to cross two or more bands emits ONCE,
## carrying the final band only. Skipped bands are never entered, so they never
## fire (decision recorded 2026-08-26; `suit-oxygen.md` does not specify it).
signal threshold_changed(band: Band)

## Emitted exactly once, on the above-zero -> zero crossing of [member remaining].
## Carries no payload and no policy.
##
## An object poisoned by a non-positive capacity (see [method _init]) starts at
## zero, so it never crosses and therefore never emits this signal.
signal depleted

var _capacity: float = 0.0
var _remaining: float = 0.0
var _band: Band = Band.NOMINAL
var _drain_rate: float = 0.0
var _threshold_caution: float = 0.0
var _threshold_warning: float = 0.0
var _threshold_critical: float = 0.0

## Oxygen the suit held at level start, in seconds of drain at rate 1.0. Seeded
## once at construction; never written again.
var capacity: float:
	get: return _capacity

## Oxygen left. Written only by [method drain], never increases by any path, and
## is floored at zero (`suit-oxygen.md` R4, AC3).
var remaining: float:
	get: return _remaining

## [member remaining] over [member capacity], in `0.0..1.0`. Returns `0.0` when
## the capacity is zero rather than dividing — the poisoned object reads as
## empty, not as a crash.
var fraction: float:
	get:
		if _capacity <= 0.0:
			return 0.0
		return _remaining / _capacity

## The band [member fraction] currently falls in. Derived — nothing outside this
## class writes it.
var band: Band:
	get: return _band


## Constructs the oxygen state for a level holding [param initial_capacity]
## seconds of oxygen, reading the drain rate and the three band thresholds from
## [param tuning].
##
## `initial_capacity > 0` is a caller contract (`suit-oxygen.md` AC7, ADR-0002).
## GDScript cannot fail an `_init()`, so a non-positive capacity calls
## [method @GlobalScope.push_error] and leaves the object permanently depleted:
## capacity and remaining both `0.0`, band [constant Band.CRITICAL], no signal
## ever emitted. `assert()` is not used — the control manifest forbids it for
## guards, because it compiles out of release exports. `LevelValidation` reports
## the same breach at load time under `V-OXY-CAP` (ADR-0003), which is where
## authoring feedback belongs.
##
## (The parameter is named `initial_capacity` rather than `capacity` so it does
## not shadow the property of that name; a shadowing warning would fail the whole
## gdUnit4 suite at discovery.)
func _init(initial_capacity: float, tuning: OxygenTuning) -> void:
	_drain_rate = tuning.drain_rate
	_threshold_caution = tuning.threshold_caution
	_threshold_warning = tuning.threshold_warning
	_threshold_critical = tuning.threshold_critical
	if initial_capacity <= 0.0:
		push_error(
			"OxygenState requires capacity > 0, got %f. The object is left "
			% initial_capacity
			+ "permanently depleted (ADR-0002, suit-oxygen.md AC7)."
		)
		initial_capacity = 0.0
	_capacity = initial_capacity
	_remaining = initial_capacity
	_band = _band_for(fraction)


## Drains [param delta] seconds of suit time, scaled by the tuned drain rate.
## Called once per physics frame by `OxygenDrain`, unconditionally, in every
## player state.
##
## Unconditional by design: there is no state check before the decrement, so no
## caller can reach a state in which the clock stops (`suit-oxygen.md` R2, AC1).
## The single clamping expression both floors [member remaining] at zero and
## forbids any increase, so a negative [param delta] is not a refill back door.
##
## Emits [signal threshold_changed] when the recomputed band differs from the
## current one, and [signal depleted] on the above-zero -> zero crossing only.
func drain(delta: float) -> void:
	var was_above_zero: bool = _remaining > 0.0
	_remaining = clampf(_remaining - delta * _drain_rate, 0.0, _remaining)
	var next_band: Band = _band_for(fraction)
	if next_band != _band:
		_band = next_band
		threshold_changed.emit(_band)
	if was_above_zero and _remaining <= 0.0:
		depleted.emit()


## Maps [param oxygen_fraction] onto a [enum Band] using the tuned thresholds.
##
## A fraction landing EXACTLY on a threshold belongs to the LOWER band — the
## comparisons are `<=`, not `<`. This is not an implementer choice:
## `suit-oxygen.md` §4 states the rule verbatim as
## `nominal > 0.50 · caution <= 0.50 · warning <= 0.25 · critical <= 0.10`.
func _band_for(oxygen_fraction: float) -> Band:
	if oxygen_fraction <= _threshold_critical:
		return Band.CRITICAL
	if oxygen_fraction <= _threshold_warning:
		return Band.WARNING
	if oxygen_fraction <= _threshold_caution:
		return Band.CAUTION
	return Band.NOMINAL
