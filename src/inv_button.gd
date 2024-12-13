extends Button

@onready var InvText := get_node("InventoryTextArea")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	InvText.visible = false
	pass

func _toggled(toggle) -> void:
	InvText.visible = toggle
	pass
