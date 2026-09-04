extends Control


func _ready():
	$ButtonContainer/PlayButton.pressed.connect(_on_play_button_pressed)
	$ButtonContainer/SettingsButton.pressed.connect(_on_settings_button_pressed)
	$ButtonContainer/QuitButton.pressed.connect(_on_quit_button_pressed)


func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://level_select.tscn")


func _on_settings_button_pressed():
	print("Settings")


func _on_quit_button_pressed():
	get_tree().quit()
