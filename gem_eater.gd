extends Enemy


# A harmless creature that eats gems. It stands still until there's a loose gem in the level,
# then runs at the nearest one, jumping walls on the way (it stops short of water), and eats it
# (the gem is gone for good). It never attacks and touching it doesn't hurt. It takes two hits
# to defeat, but being thrown still defeats it outright.
const RUN_SPEED = 400.0
const JUMP_VELOCITY = -400.0
# How close (px) it has to be to a gem to eat it: sideways from the middle of its body, and
# above or below.
const EAT_REACH = 20.0
const EAT_HEIGHT = 40.0

var eating := false


func _init() -> void:
	hits = 2
	harmless = true


func _ready() -> void:
	super()
	add_to_group("terrestrial")
	add_to_group("non_mechanical")
	sprite.animation_finished.connect(_on_animation_finished)


func _move(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = 0.0
	var gem := _nearest_gem()
	if gem and not eating:
		var to_gem := gem.global_position - body.global_position
		if absf(to_gem.x) <= EAT_REACH and absf(to_gem.y) <= EAT_HEIGHT:
			_eat(gem)
		else:
			if int(signf(to_gem.x)) != direction:
				_turn()
			# It won't run into water; it waits at the edge instead.
			if not (is_on_floor() and Water.is_water_at(tile_layers, _foot_ahead())):
				velocity.x = direction * RUN_SPEED
				if is_on_floor() and is_on_wall() and get_wall_normal().x * direction < 0.0:
					velocity.y = JUMP_VELOCITY
	move_and_slide()
	_update_animation()


# Just past its leading foot.
func _foot_ahead() -> Vector2:
	var rect := body.global_transform * body.shape.get_rect()
	return Vector2(rect.end.x + 4.0 if direction > 0 else rect.position.x - 4.0, rect.end.y + 6.0)


# The nearest gem lying loose in the level (not carried, held or locked on a pedestal).
func _nearest_gem() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance := INF
	for node in get_tree().get_nodes_in_group("gems"):
		var gem := node as Node2D
		if not gem or not gem.visible or gem.is_queued_for_deletion() or gem.get_node("CollisionShape2D").disabled:
			continue
		var distance := body.global_position.distance_to(gem.global_position)
		if distance < nearest_distance:
			nearest = gem
			nearest_distance = distance
	return nearest


func _eat(gem: Node2D) -> void:
	eating = true
	gem.queue_free()
	sprite.play("eat")


func _on_animation_finished() -> void:
	if sprite.animation == "eat":
		eating = false


func _update_animation() -> void:
	if eating:
		return
	if absf(velocity.x) > 0.0 or not is_on_floor():
		sprite.play("run")
	else:
		sprite.play("idle")
