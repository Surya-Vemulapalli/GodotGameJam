extends Enemy


# Zach, a special enemy that hunts Pyrazure. It walks toward her, jumping when a wall is in the
# way, and flies straight at her whenever walking won't get there (she's well above it, a gap
# or water is in the way, or a wall is too tall to jump). Unlike Pyrazure it can fly while
# standing and slash while flying: once she's in reach it slashes whoever is in front of it. It stops once she's dead or
# in the goal cave. Like any enemy, touching it hurts; it takes four hits to defeat (being thrown
# still defeats it outright).
const WALK_SPEED = 140.0
const FLY_SPEED = 160.0
const JUMP_VELOCITY = -400.0
# How close (horizontally) it gets before it stops and waits.
const CLOSE_ENOUGH = 8.0
# How far above it Pyrazure has to be before it flies up after her.
const FLY_HEIGHT = 48.0
# The slash: how far in front of it the hit box reaches, its size, the damage it does, and how
# often it can slash.
const SLASH_OFFSET = Vector2(34, -6)
const SLASH_SIZE = Vector2(44, 56)
const SLASH_DAMAGE = 4
const SLASH_COOLDOWN = 1.0
const SLASH_TIME = 0.25

var flying := false
var slash_cooldown := 0.0
var slashing := false


func _init() -> void:
	art_faces_left = false
	hits = 4


func _ready() -> void:
	super()
	add_to_group("terrestrial")
	add_to_group("non_mechanical")


func _move(delta: float) -> void:
	slash_cooldown = maxf(slash_cooldown - delta, 0.0)
	var target := _target()
	if not target:
		flying = false
		_fall_and_stop(delta)
		return
	var to_target: Vector2 = target.sprite.global_position - global_position
	if absf(to_target.x) >= CLOSE_ENOUGH and int(signf(to_target.x)) != direction:
		_turn()
	_decide_flying(to_target)
	if flying:
		_fly_toward(to_target)
	else:
		_walk_toward(to_target, delta)
	if slash_cooldown == 0.0 and _in_reach(to_target):
		_slash()
	_update_animation()


# It takes off when walking won't reach Pyrazure: she's well above it, the ground ahead runs
# out (a gap or water), or it jumped at a wall and is falling back against it. It lands again
# only once there's solid ground under it, the way ahead is walkable and she isn't above it,
# so it never drops out of the air over water or a gap.
func _decide_flying(to_target: Vector2) -> void:
	var she_is_above := -to_target.y > FLY_HEIGHT
	var going := absf(to_target.x) >= CLOSE_ENOUGH
	if flying:
		if not she_is_above and _ground_below() and not (going and _edge_ahead()) and not _blocked_by_wall():
			flying = false
	elif she_is_above:
		flying = true
	elif is_on_floor():
		flying = going and _edge_ahead()
	else:
		flying = _blocked_by_wall() and velocity.y >= 0.0


# Flies straight at Pyrazure; if a wall is in the way it climbs straight up it first.
func _fly_toward(to_target: Vector2) -> void:
	if _blocked_by_wall():
		velocity = Vector2(direction * FLY_SPEED * 0.25, -FLY_SPEED)
	elif to_target.length() > CLOSE_ENOUGH:
		velocity = to_target.normalized() * FLY_SPEED
	else:
		velocity = Vector2.ZERO
	move_and_slide()


# Whether there's solid ground (not water) just under its feet.
func _ground_below() -> bool:
	var rect := body.global_transform * body.shape.get_rect()
	var point := Vector2(rect.get_center().x, rect.end.y + 4.0)
	if Water.is_water_at(tile_layers, point):
		return false
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_point(query).is_empty()


func _blocked_by_wall() -> bool:
	return is_on_wall() and get_wall_normal().x * direction < 0.0


func _walk_toward(to_target: Vector2, delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	var speed := WALK_SPEED if absf(to_target.x) >= CLOSE_ENOUGH else 0.0
	# A wall in the way: jump it.
	if speed > 0.0 and is_on_floor() and _blocked_by_wall():
		velocity.y = JUMP_VELOCITY
	velocity.x = direction * speed
	move_and_slide()


func _fall_and_stop(delta: float) -> void:
	velocity.x = 0.0
	if not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()
	_update_animation()


func _in_reach(to_target: Vector2) -> bool:
	return absf(to_target.x) <= SLASH_OFFSET.x + SLASH_SIZE.x / 2.0 and absf(to_target.y) <= SLASH_SIZE.y


# Slashes in front of it: any character in the hit box takes damage.
func _slash() -> void:
	slash_cooldown = SLASH_COOLDOWN
	slashing = true
	var shape := RectangleShape2D.new()
	shape.size = SLASH_SIZE
	var collision := CollisionShape2D.new()
	collision.shape = shape
	var hitbox := Area2D.new()
	# On layer 4, so a weak spot like Squadroshock's head can notice it.
	hitbox.collision_layer = 8
	hitbox.add_to_group("enemy_attacks")
	# Characters are on collision layer 3.
	hitbox.collision_mask = 4
	hitbox.add_child(collision)
	hitbox.position = Vector2(SLASH_OFFSET.x * direction, SLASH_OFFSET.y)
	hitbox.body_entered.connect(_on_slash_hit)
	add_child(hitbox)
	sprite.play("slash")
	await get_tree().create_timer(SLASH_TIME, false).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()
	slashing = false


func _on_slash_hit(body: Node) -> void:
	if body is BaseCharacter and not body.dead and not body.in_goal and body.hurt_cooldown == 0.0:
		body.take_damage(body._contact_damage(self))


# Pyrazure, if she's still in the level and out of the cave.
func _target() -> BaseCharacter:
	for node in get_tree().get_nodes_in_group("pyrazure"):
		var pyrazure := node as BaseCharacter
		if pyrazure and not pyrazure.dead and not pyrazure.in_goal:
			return pyrazure
	return null


func _update_animation() -> void:
	if slashing:
		return
	if flying:
		sprite.play("fly")
	elif not is_on_floor():
		sprite.play("jump")
	elif absf(velocity.x) > 0.0:
		sprite.play("walk")
	else:
		sprite.play("idle")
