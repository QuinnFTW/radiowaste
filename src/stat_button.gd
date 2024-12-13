extends Button

@onready var PlayerText := get_node("PlayerTextArea")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PlayerText.visible = false
	pass

func _toggled(toggle) -> void:
	PlayerText.visible = toggle
	pass
