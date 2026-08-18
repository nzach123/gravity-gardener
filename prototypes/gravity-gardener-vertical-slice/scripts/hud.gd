# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Can the MVP core loop (gravity + watering + oxygen) be built
# fully compliant with ADR-0001 through ADR-0010 in the project's own MVP estimate?
# Date: 2026-08-17
#
# DELIBERATE SIMPLIFICATION: this is E1 (the oxygen gauge) only, per this slice's
# scope note — NOT ADR-0010's full 4-zone Z1-Z4 build-out. E1 is normally a
# viewport-upright, player-tracked, gravity-offset readout (hud.md P1); here it is a
# single screen-fixed CanvasLayer label. Still holds direct references to
# LevelState/OxygenState via bind() (ADR-0010 D10.4), still polls in _process (D10.5),
# still displays the COMPOSED oxygen_remaining / drain_rate value, not the raw
# OxygenTuning value (D10.5) — and never mutates state (Forbidden: hud_writes_game_state).
class_name HUD
extends CanvasLayer

@onready var oxygen_label: Label = $OxygenLabel

## Public, no private twin — gates every HUD read path (ADR-0010 D10.4).
var is_bound: bool = false

var level_state: LevelState
var oxygen_state: OxygenState

var _unbound_error_logged: bool = false


func bind(level_state_ref: LevelState, oxygen_state_ref: OxygenState) -> void:
	level_state = level_state_ref
	oxygen_state = oxygen_state_ref
	is_bound = true


func _process(_delta: float) -> void:
	if not is_bound:
		if not _unbound_error_logged:
			push_error("HUD: first unbound draw")
			_unbound_error_logged = true
		return
	_update_oxygen_readout()


func _update_oxygen_readout() -> void:
	if oxygen_state.capacity <= 0.0:
		# Distinct error appearance — not an empty bar, and not nothing (hud.md E1
		# error state; suit-oxygen.md §5 mis-authored-level case).
		oxygen_label.text = "O2: --"
		oxygen_label.modulate = Color.MAGENTA
		return

	var displayed_seconds: float = oxygen_state.remaining / Tuning.OXYGEN.drain_rate
	oxygen_label.text = "O2: %d" % ceili(displayed_seconds)

	var fraction: float = oxygen_state.fraction
	if fraction <= Tuning.OXYGEN.threshold_critical:
		oxygen_label.modulate = Color.RED
	elif fraction <= Tuning.OXYGEN.threshold_warning:
		oxygen_label.modulate = Color.ORANGE
	elif fraction <= Tuning.OXYGEN.threshold_caution:
		oxygen_label.modulate = Color.YELLOW
	else:
		oxygen_label.modulate = Color.WHITE
