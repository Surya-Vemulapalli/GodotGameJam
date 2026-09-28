extends "res://base_character.gd"


# How close (from the sprite's centre, as if facing right) something must be to pick it up.
const PICK_UP_REACH = Vector2(56, 40)
# Where a carried object sits relative to the sprite's centre, when facing right.
const HOLD_OFFSET = Vector2(24, -2)
# Where a carried object sits while Lobulux winds up (sheet frame 5), when facing right: above its hand.
const AIM_HOLD_OFFSET = Vector2(0, -34)
# How hard things are thrown, in whichever direction the left stick points.
const LOB_SPEED = 560.0
# How far the left stick must be pushed to throw.
const AIM_THRESHOLD = 0.5

# What it's carrying, if anything: a Squadroshock platform, a gem, an enemy, or anything else
# in the "grabbable" group (they all have pick_up(), throw() and `thrown`).
var held: Node2D
# Wound up and waiting for a direction on the left stick.
var aiming := false
# Whether the stick has been back in the middle since winding up, so a stick that was already
# pushed (say, while walking) doesn't throw straight away.
var aim_centred := false


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if not active or playing_action:
		return
	# "special" is bound to the controller's X button in the Input Map. Next to a lever it
	# pulls the lever. Otherwise the first press grabs something (a Squadroshock platform, a
	# gem, an enemy...), the second winds up, then pushing the left stick throws it that way.
	if event.is_action_pressed("special") and not aiming:
		if is_instance_valid(held):
			_wind_up()
		else:
			var lever := _lever_in_reach()
			if lever:
				_pull(lever)
			else:
				_pick_up()


func _physics_process(delta: float) -> void:
	super(delta)
	if aiming and active:
		_aim()
	if is_instance_valid(held):
		var offset := AIM_HOLD_OFFSET if aiming else HOLD_OFFSET
		held.global_position = sprite.global_position + Vector2(offset.x * facing, offset.y)


# Lobulux can't walk or jump while holding or throwing something.
func _can_move() -> bool:
	return not aiming and not is_instance_valid(held)


# Lobulux can't go out over water; it can only cross it on Squadroshock's platforms.
func _can_walk(direction: float) -> bool:
	return not _water_ahead(direction)


# Lobulux dies instantly to fire hazards (anything in the "hazard_fire" group, like a fire
# pillar). There's no friendly fire, so Pyrazure's fire breath doesn't count.
func _touch_hazard(hazard: String) -> void:
	if hazard == "hazard_fire":
		die()
	else:
		super(hazard)


# Lobulux's animations are listed in CLAUDE.md.
func _update_animation() -> void:
	if playing_action:
		return
	if aiming:
		sprite.play("lob_ready")
	elif is_instance_valid(held):
		sprite.play("hold")
	else:
		sprite.play("walk" if velocity.x != 0.0 else "idle")


func _pick_up() -> void:
	var target := _grabbable_in_reach()
	if not target:
		return
	# Reaching for an enemy counts as attacking it, so it can't hurt Lobulux meanwhile.
	attack_time_left = 0.5
	await _play_action("pick_up")
	if is_instance_valid(target) and not target.thrown:
		held = target
		held.pick_up()


func _wind_up() -> void:
	aiming = true
	aim_centred = _aim_input().length() < AIM_THRESHOLD


func _aim() -> void:
	if not is_instance_valid(held):
		aiming = false
		return
	var aim := _aim_input()
	if aim.length() < AIM_THRESHOLD:
		aim_centred = true
	elif aim_centred:
		_throw(aim.normalized())


func _aim_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _throw(direction: Vector2) -> void:
	aiming = false
	if direction.x != 0.0:
		_face(int(signf(direction.x)))
	# Let go as the arm swings through (sheet frame 6), then settle back (frame 3).
	held.throw(self, direction * LOB_SPEED)
	held = null
	await _play_action("lob")


# The nearest resting grabbable object in front of Lobulux, or null if none is close enough.
# The one it's standing on doesn't count.
func _grabbable_in_reach() -> Node2D:
	var nearest: Node2D = null
	for node in get_tree().get_nodes_in_group("grabbable"):
		var candidate := node as Node2D
		if not candidate or candidate.get("thrown") or not candidate.is_inside_tree() or _standing_on(candidate):
			continue
		var offset: Vector2 = candidate.global_position - sprite.global_position
		offset.x *= facing
		if offset.x < -8.0 or offset.x > PICK_UP_REACH.x or absf(offset.y) > PICK_UP_REACH.y:
			continue
		if not nearest or offset.length() < (nearest.global_position - sprite.global_position).length():
			nearest = candidate
	return nearest


func _standing_on(body: Node) -> bool:
	if not is_on_floor():
		return false
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_collider() == body and collision.get_normal().y < -0.7:
			return true
	return false


func _pull(lever: Lever) -> void:
	await _play_action("pull_lever")
	if is_instance_valid(lever) and not dead:
		lever.pull()


# The nearest lever in front of Lobulux, or null if none is close enough.
func _lever_in_reach() -> Lever:
	var nearest: Lever = null
	for node in get_tree().get_nodes_in_group("lever"):
		var lever := node as Lever
		if not lever:
			continue
		var offset := lever.global_position - sprite.global_position
		offset.x *= facing
		if offset.x < -8.0 or offset.x > PICK_UP_REACH.x or absf(offset.y) > PICK_UP_REACH.y:
			continue
		if not nearest or offset.length() < (nearest.global_position - sprite.global_position).length():
			nearest = lever
	return nearest
