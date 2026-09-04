extends Control

@onready var power_label: Label = $powerLabel
@onready var angle_label: Label = $angleLabel
@onready var power_bar: TextureProgressBar = $powerBar
@onready var angle_bar: TextureProgressBar = $angleBar

@export var offset: Vector2 = Vector2(0, -70)

func _ready():
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Power circle
	power_bar.min_value = 0
	power_bar.max_value = 100
	power_bar.value = 0
	power_bar.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	power_bar.radial_fill_degrees = 360
	power_bar.tint_progress = Color.GREEN
	
	# Angle circle
	angle_bar.min_value = 0
	angle_bar.max_value = 360
	angle_bar.value = 0
	angle_bar.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	angle_bar.radial_fill_degrees = 360
	angle_bar.tint_progress = Color.BLUE

func show_aim(power: float, angle_rad: float, max_power: float):
	visible = true
	
	# -------------------------
	# POWER
	# -------------------------
	var power_ratio: float = clamp(power / max_power, 0.0, 1.0)
	var power_percent: int = int(power_ratio * 100.0)
	
	# Power percentage label
	power_label.text = "Power: %d%%" % power_percent
	
	# Power color
	if power_ratio < 0.5:
		power_label.modulate = Color.GREEN
	elif power_ratio < 0.99:
		power_label.modulate = Color.YELLOW
	else:
		power_label.modulate = Color.RED
	
	# Power bar value
	power_bar.value = power_percent
	
	# Power bar color
	if power_ratio < 0.5:
		power_bar.tint_progress = Color.GREEN
	elif power_ratio < 0.75:
		power_bar.tint_progress = Color.YELLOW
	else:
		power_bar.tint_progress = Color.RED
	
	
	# -------------------------
	# ANGLE
	# -------------------------
	var degrees: float = -rad_to_deg(angle_rad)
	
	if degrees > 180:
		degrees -= 360
	
	angle_label.text = "Angle: %.0f°" % degrees
	
	# Normalize to 0 - 360
	degrees = fmod(degrees + 360.0, 360.0)
	
	angle_bar.value = degrees
	
	# Angle bar is ALWAYS BLUE
	angle_bar.tint_progress = Color.BLUE

func hide_aim():
	visible = false
