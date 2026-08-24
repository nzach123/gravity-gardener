## Global oxygen constants (suit-oxygen.md §7).
## oxygen_capacity is NOT here — it is the per-level difficulty dial, exported
## on the level root and derived from O_level (suit-oxygen.md R6).
##
## drain_rate is the AUTHORED DESIGN DEFAULT. The player-facing accessibility
## setting is user data, not design data; composing the two belongs to ADR-0008
## (ADR-0006 D6.6). Nothing may write to this resource at runtime (D6.5).
##
## Every knob is @export_range using the GDD "safe range" column verbatim
## (ADR-0006 D6.4). The three threshold_* knobs have no GDD range and take
## 0.0-1.0, the only range a fraction can have. @export_range is an
## AUTHORING-TIME constraint only and does not validate a hand-edited .tres
## (T4, VERIFIED TRUE 2026-08-24).
class_name OxygenTuning
extends Resource

@export_range(0.3, 0.6) var margin: float = 0.4
@export_range(0.5, 1.0) var drain_rate: float = 1.0
@export_range(0.0, 1.0) var threshold_caution: float = 0.50
@export_range(0.0, 1.0) var threshold_warning: float = 0.25
@export_range(0.0, 1.0) var threshold_critical: float = 0.10
