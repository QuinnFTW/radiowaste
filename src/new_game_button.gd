extends Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func _pressed() -> void:
	get_tree().change_scene_to_file("res://scn/prologue.tscn")
	pass
