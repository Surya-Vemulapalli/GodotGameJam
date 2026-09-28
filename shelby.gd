extends Enemy


# Shelby: a shelled crawler that lives in water but goes anywhere. It clings to whatever it's
# on (a pool's bottom, walls, the ground, ceilings), following it round corners, and hunts
# Transpora: it crawls toward her (from the start, or once she comes within `sight_range`),
# climbing walls in the way, and when it's on a ceiling right above her it lets go and drops
# on her. Touching it
# hurts as usual (it isn't a terrestrial enemy, so no extra damage to Transpora).
# Animations: `idle` 1 (legs tucked in), `walk` 2, 3, 4.
const CRAWL_SPEED = 70.0
# How close to straight above Transpora (px) it has to be on a ceiling to drop on her.
const DROP_REACH = 12.0
# How close (px) it checks for the surface it's clinging to.
const STICK = 2.0
# Where the art's middle is in its 64x64 frame (legs out), relative to the frame's centre.
const ART_CENTRE = Vector2(-4, 6.5)
# How far the tucked-in shell (idle) sits above the legs-out walking art's feet.
const TUCK = 7.0

# It starts clinging to this surface of wherever it's placed (on "floor" it falls onto
# whatever is below).
@export_enum("floor", "ceiling", "left_wall", "right_wall") var starts_on := "floor"
# How close Transpora has to come before it notices her and starts hunting. 0 means it
# hunts her from the start, wherever she is.
@export var sight_range := 0.0

# Which way the surface it's clinging to is (down on a floor, up on a ceiling...).
var clinging_to := Vector2.DOWN
var clinging := false
# Which way along the surface it's crawling: +1 or -1 along _tangent().
var crawl_sign := 1.0
var hunting := false
var started := false


func _ready() -> void:
	super()
	add_to_group("aquatic")
	add_to_group("non_mechanical")


func _move(delta: float) -> void:
	if not started:
		started = true
		_start_clinging()
	var target := _target()
	if target and not hunting and (sight_range <= 0.0 or global_position.distance_to(_centre(target)) <= sight_range):
		hunting = true
	if not clinging:
		_fall(delta)
		_update_look(false)
		return
	var direction := _choose_direction(target)
	if direction == Vector2.ZERO:
		_update_look(false)
		return
	_crawl(direction, delta)
	_maybe_drop(target)
	_update_look(clinging)


func pick_up() -> void:
	super()
	clinging = false
	clinging_to = Vector2.DOWN
	_update_look(false)


# Placed on a wall or ceiling: stick to it straight away (the nearest one that way, up to 4
# tiles off).
func _start_clinging() -> void:
	var surfaces := {"floor": Vector2.DOWN, "ceiling": Vector2.UP, "left_wall": Vector2.LEFT, "right_wall": Vector2.RIGHT}
	if starts_on == "floor":
		return
	clinging_to = surfaces[starts_on]
	if move_and_collide(clinging_to * 256.0):
		clinging = true
	else:
		clinging_to = Vector2.DOWN


# Falling (dropped from a ceiling, or placed in mid-air): lands on whatever is below.
func _fall(delta: float) -> void:
	velocity.x = 0.0
	velocity.y += gravity * delta
	var collision := move_and_collide(velocity * delta)
	if collision and collision.get_normal().y < -0.7:
		clinging = true
		clinging_to = Vector2.DOWN
		velocity = Vector2.ZERO


# The way along the surface that counts as +1 (left on a floor).
func _tangent() -> Vector2:
	return Vector2(-clinging_to.y, clinging_to.x)


# On a floor or ceiling it heads toward Transpora's side; on a wall it keeps going the way it
# was (so it climbs over walls in its way). Zero when it has nothing to do.
func _choose_direction(target: BaseCharacter) -> Vector2:
	if not target or not hunting:
		return Vector2.ZERO
	var tangent := _tangent()
	if clinging_to.x == 0.0:
		var dx := _centre_x(target) - global_position.x
		if absf(dx) < 4.0:
			return Vector2.ZERO
		crawl_sign = signf(dx) * signf(tangent.x)
	return tangent * crawl_sign


func _crawl(direction: Vector2, delta: float) -> void:
	var collision := move_and_collide(direction * CRAWL_SPEED * delta)
	if collision:
		if collision.get_normal().dot(direction) < -0.7:
			# An inside corner: climb onto the surface in front, away from the old one.
			var old := clinging_to
			clinging_to = direction
			_crawl_toward(-old)
			return
		# A slope: slide along it.
		move_and_collide(collision.get_remainder().slide(collision.get_normal()))
	if not test_move(global_transform, clinging_to * STICK):
		# The surface ran out (an outside corner): go round it onto the face beyond.
		var old := clinging_to
		clinging_to = -direction
		_crawl_toward(old)
		move_and_collide(old * STICK)
		if not move_and_collide(clinging_to * (STICK + 4.0)):
			# Nothing there after all (say, the end of a thin ledge): let go and fall.
			clinging = false
			clinging_to = Vector2.DOWN
			velocity = Vector2.ZERO


func _crawl_toward(way: Vector2) -> void:
	crawl_sign = signf(way.dot(_tangent()))


# On a ceiling right above Transpora: let go and drop on her.
func _maybe_drop(target: BaseCharacter) -> void:
	if clinging_to != Vector2.UP or not target:
		return
	if _centre(target).y > global_position.y and absf(_centre_x(target) - global_position.x) <= DROP_REACH:
		clinging = false
		clinging_to = Vector2.DOWN
		velocity = Vector2.ZERO


# The middle of a character's body (their origin isn't in the middle of their art).
func _centre(character: BaseCharacter) -> Vector2:
	for child in character.get_children():
		if child is CollisionShape2D and not child.disabled:
			return (child.global_transform * child.shape.get_rect()).get_center()
	return character.global_position


func _centre_x(character: BaseCharacter) -> float:
	return _centre(character).x


# Turns the art so its feet are on the surface it's clinging to, facing the way it crawls.
func _update_look(walking: bool) -> void:
	var angle := Vector2.DOWN.angle_to(clinging_to)
	sprite.rotation = angle
	sprite.play("walk" if walking else "idle")
	# The art faces left; mirror it when crawling right (as seen with its feet down).
	var local_way := (_tangent() * crawl_sign).rotated(-angle)
	if absf(local_way.x) > 0.1:
		sprite.flip_h = local_way.x > 0.0
	var centre := ART_CENTRE
	if sprite.flip_h:
		centre.x = -centre.x
	sprite.offset = -centre + (Vector2.ZERO if walking else Vector2(0, TUCK))


# Transpora, if she's still in the level and out of the cave.
func _target() -> BaseCharacter:
	for node in get_tree().get_nodes_in_group("transpora"):
		var transpora := node as BaseCharacter
		if transpora and not transpora.dead and not transpora.in_goal:
			return transpora
	return null
