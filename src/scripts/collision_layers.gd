## Central allocation of 2D physics collision layer bits (ADR-0004).
##
## Authoritative source. project.godot's layer_names are editor-facing only;
## on any disagreement, this file is correct and project.godot is the bug.
##
## Layer/mask values are AUTHORED data. Never assign collision_layer or
## collision_mask at runtime, and never call set_collision_layer_value() or
## set_collision_mask_value() — doing so breaks physics-props.md R1 in a way
## no test in this project can observe (ADR-0004 D4.6).
class_name CollisionLayers
extends RefCounted

## Terrain and animatable platforms.
const WORLD: int = 1 << 0   # 1
## The Player CharacterBody2D, and nothing else.
const PLAYER: int = 1 << 1  # 2
# bit 3 (value 4) is RETIRED — see ADR-0004 D4.2. Do not claim it.
## Cosmetic RigidBody2D props. Never interacts with PLAYER (physics-props.md R1).
const PROP: int = 1 << 3    # 8

## Every bit this project has allocated. Used to assert no scene claims another.
const ALLOCATED: int = WORLD | PLAYER | PROP  # 11

## Masks, named by the role that carries them.
const PLAYER_MASK: int = WORLD              # 1
const PROP_MASK: int = WORLD | PROP         # 9
const DETECTOR_MASK: int = PLAYER           # 2
const DETECTOR_LAYER: int = 0               # detectors need no layer (ADR-0004 L1)
