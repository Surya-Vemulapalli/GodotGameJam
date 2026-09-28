extends Enemy


# A fish that walks along the ground, back and forth, turning round at walls, ledges and water.


func _ready() -> void:
	super()
	add_to_group("non_mechanical")
	add_to_group("terrestrial")


func _move(delta: float) -> void:
	_walk(delta, SPEED)
