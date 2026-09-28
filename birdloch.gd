extends Enemy


# An underwater creature that swims back and forth at its depth, turning round at walls and
# wherever the water ends, so it never leaves the water. Until it's fully underwater (say, placed
# above a pool), it falls. If its water drains away (a blue button), it dies.


func _ready() -> void:
	super()
	add_to_group("aquatic")
	add_to_group("non_mechanical")


func _move(delta: float) -> void:
	if _drained_out():
		queue_free()
		return
	var rect := body.global_transform * body.shape.get_rect()
	if not Water.is_water_at(tile_layers, Vector2(rect.get_center().x, rect.position.y + 1.0)):
		velocity.x = 0.0
		velocity.y += gravity * delta
		move_and_slide()
		return
	velocity.y = 0.0
	var ahead := Vector2(rect.end.x + 4.0 if direction > 0 else rect.position.x - 4.0, rect.get_center().y)
	if (is_on_wall() and get_wall_normal().x * direction < 0.0) or not Water.is_water_at(tile_layers, ahead):
		_turn()
	velocity.x = direction * SPEED
	move_and_slide()
