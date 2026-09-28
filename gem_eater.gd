extends Enemy


# A harmless creature that eats gems. It stands still until there's a loose gem in the level,
# then runs at the nearest one, jumping walls on the way (it stops short of water), and eats it
# (the gem is gone for good). If the gem is below the ground it's on, it runs to the nearer end of
# that ground and drops off, instead of running back and forth above the gem. It runs straight
# through other enemies (they don't block it or count as ground). It never attacks and touching it doesn't hurt. It takes two hits
# to defeat, but being thrown still defeats it outright.
const RUN_SPEED = 400.0
const JUMP_VELOCITY = -400.0
# How close (px) it has to be to a gem to eat it: sideways from the middle of its body, and
# above or below.
const EAT_REACH = 20.0
const EAT_HEIGHT = 40.0
# How far along its ground (px) it looks for the way down to a gem below it, and in what steps.
const DROP_SEARCH = 2560.0
const DROP_STEP = 16.0

# Gems this Gem Eater leaves alone (it doesn't go after or eat them).
@export var ignored_gems: Array[Node2D] = []

var eating := false
# While a gem is below it: the way it's running to get off its ground (0 when not doing that).
var drop_direction := 0
# Set once it's in the air after heading for the way down.
var dropping := false


func _init() -> void:
	hits = 2
	harmless = true


func _ready() -> void:
	super()
	add_to_group("terrestrial")
	add_to_group("non_mechanical")
	# Transpora's long laser (with an item in the backpack) defeats it in one hit.
	add_to_group("gem_eater")
	sprite.animation_finished.connect(_on_animation_finished)
	# Once every enemy is in the level (and in the "enemies" group).
	_ignore_enemies.call_deferred()


# It runs through other enemies instead of bumping into them. (Only its own movement ignores
# them: an enemy Lobulux throws at it still hits it.)
func _ignore_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy != self and enemy is PhysicsBody2D:
			add_collision_exception_with(enemy)


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
			var heading := int(signf(to_gem.x))
			if is_on_floor():
				if dropping:
					# Landed after dropping off: look again from here.
					dropping = false
					drop_direction = 0
				if to_gem.y > EAT_HEIGHT:
					# The gem is below: make for the way down and stick to it.
					if drop_direction == 0:
						drop_direction = _way_down(heading)
				else:
					drop_direction = 0
			elif drop_direction != 0:
				# Keep going the way it dropped off until it lands, so it doesn't turn back onto
				# the ground it just left.
				dropping = true
			if drop_direction != 0:
				heading = drop_direction
			if heading != 0 and heading != direction:
				_turn()
			# It won't run into water; it waits at the edge instead.
			if not (is_on_floor() and Water.is_water_at(tile_layers, _foot_ahead())):
				velocity.x = direction * RUN_SPEED
				if is_on_floor() and is_on_wall() and get_wall_normal().x * direction < 0.0:
					if drop_direction != 0:
						# A wall on the way down: try the other way instead of climbing it.
						drop_direction = -drop_direction
					else:
						velocity.y = JUMP_VELOCITY
	move_and_slide()
	_update_animation()


# Which way (-1 or 1) the nearest drop off the ground it's standing on is: where the ground ends
# (not into water) before a wall does. If there's none within DROP_SEARCH, it heads `fallback`.
func _way_down(fallback: int) -> int:
	var rect := body.global_transform * body.shape.get_rect()
	var best := 0
	var best_distance := INF
	for side: int in [-1, 1]:
		var edge: float = rect.end.x if side > 0 else rect.position.x
		var distance := 0.0
		while distance < DROP_SEARCH and distance < best_distance:
			var x: float = edge + side * distance
			if _solid_at(Vector2(x, rect.get_center().y)):
				break
			var below := Vector2(x, rect.end.y + 6.0)
			if not _solid_at(below):
				if not Water.is_water_at(tile_layers, below):
					best = side
					best_distance = distance
				break
			distance += DROP_STEP
	return best if best != 0 else fallback


func _solid_at(point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	# Only the level itself (tiles, doors, platforms), not characters, loose things or enemies.
	query.collision_mask = 1
	var exclude: Array[RID] = [get_rid()]
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is CollisionObject2D:
			exclude.append(enemy.get_rid())
	query.exclude = exclude
	return not get_world_2d().direct_space_state.intersect_point(query).is_empty()


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
		if not gem or gem in ignored_gems or not gem.visible or gem.is_queued_for_deletion() or gem.get_node("CollisionShape2D").disabled:
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
