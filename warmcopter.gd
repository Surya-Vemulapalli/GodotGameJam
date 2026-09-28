extends Enemy


# A small flying robot with a rotor on top. It flies back and forth at its height, ignoring
# gravity, like Neverpig: it turns round at walls, and after flying `patrol_distance` either side of
# where it started (unless `wall_to_wall` is on: then it only turns round at walls). Being a robot,
# red fire doesn't hurt it; blue fire and every other attack do.
@export var patrol_distance := 256.0
@export var wall_to_wall := false

# Where it started; noted on its first move, once it's in its place in the level.
var start_x := NAN


func _ready() -> void:
	super()
	add_to_group("aerial")
	add_to_group("mechanical")


func _move(_delta: float) -> void:
	if is_nan(start_x):
		start_x = global_position.x
	var gone_too_far := not wall_to_wall and (global_position.x - start_x) * direction >= patrol_distance
	if gone_too_far or (is_on_wall() and get_wall_normal().x * direction < 0.0):
		_turn()
	velocity = Vector2(direction * SPEED, 0.0)
	move_and_slide()
