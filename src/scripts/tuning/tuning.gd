## Canonical tuning instances. The ONLY place a tuning .tres path is written.
## Reached as Tuning.PROP / Tuning.OXYGEN / Tuning.WATERING.
##
## preload() resolves when this SCRIPT loads, which is independent of the
## SceneTree entirely — not merely tolerant of a null one. That is what lets
## LevelValidation (ADR-0003, null tree) and GravityAuthority (autoload,
## pre-level) share one mechanism. See ADR-0006 D6.3 and T2.
##
## preload, never load: a missing or renamed .tres is then a script parse error
## at startup rather than a null dereference on the first gravity flip.
##
## Tuning is NOT an autoload and must never become one — preload already gives
## it universal reach, and registering it would hand it exactly the tree
## dependency D6.3 exists to avoid. It holds three constants and nothing else:
## no methods, no variables, no signals, no _ready.
class_name Tuning

const WATERING: WateringTuning = preload("res://src/resources/tuning/watering_tuning.tres")
const OXYGEN:   OxygenTuning   = preload("res://src/resources/tuning/oxygen_tuning.tres")
const PROP:     PropTuning     = preload("res://src/resources/tuning/prop_tuning.tres")
