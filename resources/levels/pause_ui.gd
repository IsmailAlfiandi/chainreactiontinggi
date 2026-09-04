extends CanvasLayer

@onready var pause_button = $PauseButton
@onready var pause_menu = $PauseMenu
@onready var resume_button = $PauseMenu/ResumeButton
@onready var main_menu_button = $PauseMenu/MainMenuButton


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.visible = false

	pause_button.pressed.connect(_on_pause_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)


func _on_pause_pressed():
	pause_menu.visible = true
	pause_button.visible = false
	get_tree().paused = true


func _on_resume_pressed():
	get_tree().paused = false
	pause_menu.visible = false
	pause_button.visible = true


func _on_main_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main_menu.tscn")
