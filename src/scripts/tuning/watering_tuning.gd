## Global watering feel constants (watering-system.md §7).
## Per-plant knobs (buckets_required, water_duration) are NOT here — they are
## exported on Plant, because per-instance variation is the level design
## vocabulary. See ADR-0006 D6.1.
##
## Every knob is @export_range using the GDD "safe range" column verbatim
## (ADR-0006 D6.4). @export_range is an AUTHORING-TIME constraint only: it
## shapes the inspector and does NOT validate a value typed into the .tres by
## hand (T4, VERIFIED TRUE 2026-08-24). Treat it as a hint, never a validator.
class_name WateringTuning
extends Resource

@export_range(0.4, 0.9)    var carry_speed_multiplier: float = 0.6
@export_range(60.0, 200.0) var throw_arc_height: float = 120.0
@export_range(0.4, 0.8)    var throw_duration: float = 0.6
@export_range(0.0, 90.0)   var throw_angle_spread: float = 45.0
