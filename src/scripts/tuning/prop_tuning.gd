## Global prop constants (physics-props.md §7).
## mass, friction, bounce and damping are NOT here — they are per-prop scene
## exports, because variation between a light chair and a heavy table is the point.
##
## Every knob is @export_range using the GDD "safe range" column verbatim
## (ADR-0006 D6.4). @export_range is an AUTHORING-TIME constraint only and does
## not validate a hand-edited .tres (T4, VERIFIED TRUE 2026-08-24).
##
## props_per_level_budget is an int, not a float. V-PROP-BUDGET compares a node
## count against it (ADR-0003, unblocked by ADR-0006 D6.8).
class_name PropTuning
extends Resource

@export_range(0.8, 1.2)       var prop_gravity_scale: float = 1.0
@export_range(1000.0, 4000.0) var prop_max_speed: float = 2000.0
@export_range(10, 80)         var props_per_level_budget: int = 40
