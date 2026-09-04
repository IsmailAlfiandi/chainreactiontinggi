extends Node2D

func _ready() -> void:
	ScoreManager.all_enemies_killed.connect(_on_all_enemies_killed)

func _on_all_enemies_killed() -> void:
	print("GAME WON!")
