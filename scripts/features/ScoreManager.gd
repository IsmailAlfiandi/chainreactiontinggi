extends Node

var score: int = 0
var enemies_remaining: int = 0

signal score_changed(new_score)
signal all_enemies_killed

func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)


func register_enemy() -> void:
	enemies_remaining += 1


func enemy_killed() -> void:
	enemies_remaining -= 1
	
	if enemies_remaining <= 0:
		all_enemies_killed.emit()
