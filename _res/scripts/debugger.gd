extends Control
@onready var debuggerlabel: Label = $DebuggerLabel
@onready var player: Player = $"../.."



func _ready() -> void:
	pass
	
	
func _process(delta: float) -> void:
	var debug_string: String = ""
	var gravity = player.target_gravity
	var y_velocity = snapped(player.velocity.y, .1)
	var x_velocity = snapped(player.velocity.x, .1)
	var velocity: Vector2 = Vector2(x_velocity, y_velocity)
	var right_dir: Vector2 = player.right_dir
	var up_dir = player.up_dir
	if abs(gravity.x) > abs(gravity.y):
		if gravity.x > 0:
			debug_string += "Gravity: Right\n"
		else:
			debug_string += "Gravity: Left\n"
	else:
		if gravity.y > 0:
			debug_string += "Gravity: Down\n"
		else:
			debug_string += "Gravity: Up\n"
			
	if up_dir.y == -1.0:
		debug_string += "Up Dir: True\n"
	else:
		debug_string += "Up Dir: False\n"
	if right_dir.x == 1.0:
		debug_string += "Right Dir: True\n"
	else:
		debug_string += "Right Dir: False\n"
		
	if player.is_on_floor():
		debug_string += "On Ground\n"
	else:
		debug_string += "In Air\n"
	
	debug_string += "Velocity: %s\n" % velocity

	debuggerlabel.text = debug_string
