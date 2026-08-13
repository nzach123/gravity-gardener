class_name PlayerWateringComponent
extends Node

# ---------------------------------------------------------------
# RUNTIME STATE
# ---------------------------------------------------------------
var is_watering: bool = false
var current_plant: Plant = null

# ---------------------------------------------------------------
# SIGNALS
# ---------------------------------------------------------------
signal watering_started
signal watering_stopped

# ---------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------
## Lock the player into watering mode.
func lock() -> void:
	is_watering = true
	watering_started.emit()

## Unlock the player from watering mode.
func unlock() -> void:
	is_watering = false
	current_plant = null
	watering_stopped.emit()