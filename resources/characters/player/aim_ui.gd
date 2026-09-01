extends Control

@onready var power_label: Label = $powerLabel
@onready var angle_label: Label = $angleLabel

# How high above the player the UI appears
@export var offset: Vector2 = Vector2(0, -70)

func _ready():
	# Hide by default
	visible = false
	# Make sure it doesn't block mouse clicks
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_aim(power: float, angle_rad: float, max_power: float):
	visible = true
	
	# Power text
	power_label.text = "Power: %d" % int(power)
	# Optional: change color based on power
	var ratio = power / max_power
	if ratio < 0.4:
		power_label.modulate = Color.GREEN
	elif ratio < 0.75:
		power_label.modulate = Color.YELLOW
	else:
		power_label.modulate = Color.RED
	
	# Angle in degrees (0° = right, 90° = up, etc.)
	var degrees = -rad_to_deg(angle_rad)
	# Normalize to -180 ~ 180 for nicer display
	if degrees > 180:
		degrees -= 360
	angle_label.text = "Angle: %.0f°" % degrees

func hide_aim():
	visible = false
