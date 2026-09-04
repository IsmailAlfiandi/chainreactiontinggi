extends Control


func _ready():
	$ButtonContainer/Level1Button.pressed.connect(_on_level_1_pressed)
	$ButtonContainer/Level2Button.pressed.connect(_on_level_2_pressed)
	$ButtonContainer/Level3Button.pressed.connect(_on_level_3_pressed)
	$ButtonContainer/BackButton.pressed.connect(_on_back_pressed)


func _on_level_1_pressed():
	get_tree().change_scene_to_file("res://resources/levels/demo_level.tscn")


func _on_level_2_pressed():
	print("Level 2 belum dibuat")


func _on_level_3_pressed():
	print("Coming Soon")


func _on_back_pressed():
	get_tree().change_scene_to_file("res://main_menu.tscn")
