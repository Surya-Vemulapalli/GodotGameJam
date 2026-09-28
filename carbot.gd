extends Enemy


# A robot car that drives along the ground, back and forth, turning round at walls, ledges and
# water. It's mechanical: red fire doesn't hurt it, but blue fire and every other attack do.
const DRIVE_SPEED = 90.0


func _init() -> void:
	art_faces_left = false


func _ready() -> void:
	super()
	add_to_group("mechanical")
	add_to_group("terrestrial")


func _move(delta: float) -> void:
	_walk(delta, DRIVE_SPEED)
