extends Enemy


# An underwater creature that swims back and forth at its depth like Birdloch, until a character
# gets in the water near it: then it swims straight at them. It never leaves the water, so a
# character who climbs out is safe. Until it's fully underwater (say, placed above a pool), it
# falls. If its water drains away (a blue button), it dies. Touching a character who's keeping still
# does double damage.
const CHASE_SPEED = 110.0
# How close (px) a character in the water has to be before it notices them.
const SIGHT_RANGE = 480.0


func _ready() -> void:
	super()
	add_to_group("aquatic")
	add_to_group("non_mechanical")


# Touching a character who's keeping still does double damage.
func contact_multiplier(character: BaseCharacter) -> int:
	return 2 if character.is_still() else 1


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
	var target := _target()
	if target:
		_chase(target, rect)
	else:
		_patrol(rect)
	move_and_slide()


func _patrol(rect: Rect2) -> void:
	velocity.y = 0.0
	if (is_on_wall() and get_wall_normal().x * direction < 0.0) or not _water_ahead(rect, Vector2(direction, 0)):
		_turn()
	velocity.x = direction * SPEED


# Swims at the target, but never out of the water: it stops moving along whichever axis would
# take it out.
func _chase(target: BaseCharacter, rect: Rect2) -> void:
	var to_target: Vector2 = target.sprite.global_position - rect.get_center()
	if absf(to_target.x) > 4.0 and int(signf(to_target.x)) != direction:
		_turn()
	velocity = to_target.normalized() * CHASE_SPEED
	if velocity.x != 0.0 and not _water_ahead(rect, Vector2(signf(velocity.x), 0)):
		velocity.x = 0.0
	if velocity.y != 0.0 and not _water_ahead(rect, Vector2(0, signf(velocity.y))):
		velocity.y = 0.0


# Whether there's water just past its edge in that direction (a unit step along one axis).
func _water_ahead(rect: Rect2, step: Vector2) -> bool:
	var point := rect.get_center()
	if step.x != 0.0:
		point.x = rect.end.x + 4.0 if step.x > 0.0 else rect.position.x - 4.0
	else:
		point.y = rect.end.y + 4.0 if step.y > 0.0 else rect.position.y - 4.0
	return Water.is_water_at(tile_layers, point)


# The nearest character within sight that's in the water, still in the level and out of the cave.
func _target() -> BaseCharacter:
	var nearest: BaseCharacter = null
	var nearest_distance := SIGHT_RANGE
	for node in get_tree().get_nodes_in_group("characters"):
		var character := node as BaseCharacter
		if not character or character.dead or character.in_goal or not character._touching_water():
			continue
		var distance := global_position.distance_to(character.sprite.global_position)
		if distance <= nearest_distance:
			nearest = character
			nearest_distance = distance
	return nearest
