class_name BaseCharacter
extends CharacterBody2D


signal died(character: BaseCharacter)

const SPEED = 200.0
# How far (px) a character's feet can dip into water before it counts as touching it.
const WATER_LEEWAY = 4.0
# How far ahead (px) _water_ahead looks when checking a step toward water.
const WATER_STEP = 4.0
# Jump speed: with the default gravity (980 px/s²) this jumps about 118 px, enough to get up a
# one-tile step but not a two-tile (128 px) one.
const JUMP_VELOCITY = -480.0
# On ice (anything in the "ice" group), how fast (px/s²) a character speeds up and slows down, so
# it slides instead of starting and stopping at once.
const ICE_ACCELERATION = 300.0
# The slash hit box: how far in front of the sprite it reaches, its size and how long it lasts.
const SLASH_REACH = 32.0
const SLASH_SIZE = Vector2(32, 32)
const SLASH_TIME = 0.15
# Every character starts each level with this much health; at 0 it dies.
const MAX_HEALTH = 16
# Touching an enemy (anything in the "enemies" group) while not attacking, or a hazard, costs
# this much health, then the character can't be hurt again for a moment.
const CONTACT_DAMAGE = 4
# Moving slower than this (px/s) counts as keeping still (see is_still).
const STILL_SPEED = 45.0
# The hazard groups: anything in one of these (like a pillar's lightning or flame) hurts
# characters that touch it. Each character decides what a hazard does to it (_touch_hazard).
const HAZARDS = ["hazard_electric", "hazard_fire"]
const HURT_COOLDOWN = 1.0

# Only the active character listens to the controller; the others just stand (or fall) still.
@export var active := true

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var crawling := false
# 1 when facing right, -1 when facing left.
var facing := 1
# A one-off animation (like placing a platform) that walking/idling mustn't interrupt.
var playing_action := false
var dead := false
# Gone into the goal cave: it stays there, hidden, and can't move, act or be hurt.
var in_goal := false
var health := MAX_HEALTH
# Seconds left before the character can be hurt again (it blinks meanwhile).
var hurt_cooldown := 0.0
# Seconds left of the current attack (claw, spear, torpedo roll...), while it can't be hurt
# by touching enemies.
var attack_time_left := 0.0
# The level's tile layers, checked for water (tiles with the tileset's "water" flag).
var tile_layers: Array[TileMapLayer] = []
# Below this y it has fallen out of the level (see LevelBounds).
var fall_death_y := LevelBounds.DEFAULT_FALL_DEATH_Y

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
# Notices enemies and hazards touching the character. It has a slightly bigger copy of each
# of the character's collision shapes, kept in step with them (the dragon swaps shapes).
var hurtbox: Area2D
var hurt_shapes := {}


func _ready() -> void:
	# Enemies look for the player characters here.
	add_to_group("characters")
	tile_layers = Water.layers_beside(self)
	# Falling below the level's lowest tiles means falling out of it, which kills it.
	fall_death_y = LevelBounds.fall_death_y(tile_layers)
	hurtbox = Area2D.new()
	hurtbox.collision_layer = 0
	for child in get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var copy := CollisionShape2D.new()
			copy.shape = RectangleShape2D.new()
			copy.shape.size = child.shape.size + Vector2(4, 4)
			hurtbox.add_child(copy)
			hurt_shapes[child] = copy
	add_child(hurtbox)


func _physics_process(delta: float) -> void:
	if in_goal:
		return
	_apply_gravity(delta)

	var direction := 0.0
	if active and _can_move():
		# move_left/move_right are the left stick's horizontal axis.
		direction = Input.get_axis("move_left", "move_right")
		_handle_jump()
	if direction != 0.0:
		_face(int(signf(direction)))
		if not _can_walk(direction):
			direction = 0.0

	if _on_ice():
		velocity.x = move_toward(velocity.x, direction * SPEED, ICE_ACCELERATION * delta)
	else:
		velocity.x = direction * SPEED
	move_and_slide()
	_update_animation()
	if global_position.y > fall_death_y:
		die()
	_check_enemy_contact(delta)


# Whether it's standing on ice.
func _on_ice() -> bool:
	if not is_on_floor():
		return false
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var ground := collision.get_collider() as Node
		if ground and ground.is_in_group("ice") and collision.get_normal().y < -0.7:
			return true
	return false


func _check_enemy_contact(delta: float) -> void:
	for body_shape in hurt_shapes:
		hurt_shapes[body_shape].position = body_shape.position
		hurt_shapes[body_shape].disabled = body_shape.disabled
	attack_time_left = maxf(attack_time_left - delta, 0.0)
	# Hazards come first: some kill instantly, even while blinking.
	for thing in hurtbox.get_overlapping_areas() + hurtbox.get_overlapping_bodies():
		for hazard in HAZARDS:
			if thing.is_in_group(hazard) and not dead:
				_touch_hazard(hazard)
	if dead:
		return
	if hurt_cooldown > 0.0:
		hurt_cooldown = maxf(hurt_cooldown - delta, 0.0)
		# Blink while it can't be hurt.
		sprite.visible = hurt_cooldown == 0.0 or int(hurt_cooldown * 10.0) % 2 == 0
		return
	if dead or _is_attacking():
		return
	for body in hurtbox.get_overlapping_bodies():
		# An enemy Lobulux is holding or has thrown can't hurt anyone.
		if body.is_in_group("enemies") and not body.get("held") and not body.get("thrown") and not body.get("harmless"):
			var damage := _contact_damage(body)
			# Some enemies hit harder in some situations (Seasire, against a character keeping still).
			if body.has_method("contact_multiplier"):
				damage *= body.contact_multiplier(self)
			take_damage(damage)
			return


func take_damage(amount: int) -> void:
	if dead:
		return
	health = maxi(health - amount, 0)
	hurt_cooldown = HURT_COOLDOWN
	if health == 0:
		sprite.visible = true
		die()


# Whether the character is in the middle of an attack, so touching an enemy doesn't hurt it.
func _is_attacking() -> bool:
	return attack_time_left > 0.0


# Whether it's keeping still: slower than STILL_SPEED (so Pyrazure gently sinking in water, when
# not swimming, counts as still).
func is_still() -> bool:
	return velocity.length() < STILL_SPEED


# How much touching this enemy hurts. Characters can override this (Transpora is weak to
# terrestrial enemies).
func _contact_damage(_enemy: Node) -> int:
	return CONTACT_DAMAGE


# Touching a hazard costs CONTACT_DAMAGE (unless it's still blinking from the last hit).
# Characters override this for what they're immune to or killed by.
func _touch_hazard(_hazard: String) -> void:
	if hurt_cooldown == 0.0:
		take_damage(CONTACT_DAMAGE)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("toggle_crawl"):
		crawling = not crawling
	elif event.is_action_pressed("slash"):
		_slash()


# Whether the controller can walk and jump the character right now. Characters can override
# this (Lobulux stands still while aiming a throw).
func _can_move() -> bool:
	return true


# Whether the character may walk that way (-1 left, 1 right). It still turns to face it.
# Characters can override this (Lobulux won't step out onto water).
func _can_walk(_direction: float) -> bool:
	return true


# Whether stepping that way (-1 left, 1 right) would take the character out over water that
# no platform covers. On the ground it only stops when water is just past its leading foot
# and a step further on none of its feet would be on anything solid (ground or a platform):
# it can straddle gaps between floating platforms narrower than itself, and walk right up to
# the edge of a bank.
func _water_ahead(direction: float) -> bool:
	var collision: CollisionShape2D = null
	for child in get_children():
		if child is CollisionShape2D and not child.disabled:
			collision = child
			break
	if not collision:
		return false
	var rect := collision.global_transform * collision.shape.get_rect()
	var edge := rect.end.x if direction > 0.0 else rect.position.x
	var query := PhysicsPointQueryParameters2D.new()
	query.exclude = [get_rid()]
	# Already in water (say, it fell in): let it move, so it isn't stuck.
	if Water.is_water_at(tile_layers, Vector2(rect.get_center().x, rect.end.y - 2.0)):
		return false
	# In the air, look down the column just past its leading edge: if water comes before
	# anything solid, it's heading out over water.
	if not is_on_floor():
		var x := edge + 6.0 * signf(direction)
		var y := rect.end.y
		while y < rect.end.y + 600.0:
			if Water.is_water_at(tile_layers, Vector2(x, y)):
				return true
			query.position = Vector2(x, y)
			if not get_world_2d().direct_space_state.intersect_point(query).is_empty():
				return false
			y += 6.0
		return false
	var step := WATER_STEP * signf(direction)
	if not Water.is_water_at(tile_layers, Vector2(edge + step, rect.end.y + 6.0)):
		return false
	# Only the level and platforms hold it up (characters are on other layers).
	query.collision_mask = 1
	var x := rect.position.x + step
	while x <= rect.end.x + step:
		query.position = Vector2(x, rect.end.y + 2.0)
		if not get_world_2d().direct_space_state.intersect_point(query).is_empty():
			return false
		x += 2.0
	return true


# Falls when off the floor. Characters can override this (the dragon floats in water).
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


# Goes into the goal cave for good.
func enter_goal() -> void:
	in_goal = true
	active = false
	velocity = Vector2.ZERO
	visible = false
	hurtbox.set_deferred("monitoring", false)


# Stops listening to the controller, plays "die" if the character has it, then leaves the level.
func die() -> void:
	if dead:
		return
	dead = true
	active = false
	died.emit(self)
	if sprite.sprite_frames.has_animation("die"):
		playing_action = true
		sprite.play("die")
		await sprite.animation_finished
	queue_free()


# Whether the middle of the character is in a water tile.
func _is_in_water() -> bool:
	return Water.is_water_at(tile_layers, sprite.global_position)


# Whether any part of the character's collision shape overlaps a water tile.
func _touching_water() -> bool:
	for child in get_children():
		var collision := child as CollisionShape2D
		if not collision or collision.disabled or not collision.shape:
			continue
		# Shrink it a touch so standing flush against the water doesn't count, and leave its
		# feet a few px of leeway, so a foot poking over the edge of a bank (level with the
		# water's surface) or a sub-pixel dip doesn't count as falling in.
		var rect := (collision.global_transform * collision.shape.get_rect()).grow_individual(-0.5, -0.5, -0.5, -WATER_LEEWAY)
		if Water.overlaps(tile_layers, rect):
			return true
	return false


# Jumps off the floor. Characters can override this to use the jump button differently.
func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY


# Plays stand_idle, stand_walk, crawl_idle or crawl_walk, if the character has it.
func _update_animation() -> void:
	if playing_action:
		return
	var animation := "crawl" if crawling else "stand"
	animation += "_walk" if velocity.x != 0.0 else "_idle"
	if sprite.sprite_frames.has_animation(animation):
		sprite.play(animation)


# Plays a non-looping animation through once, then goes back to walking/idling.
func _play_action(animation: String) -> void:
	playing_action = true
	sprite.play(animation)
	await sprite.animation_finished
	playing_action = false


func _face(direction: int) -> void:
	if direction == facing:
		return
	facing = direction
	sprite.flip_h = facing < 0
	# Mirror the collision shapes around the sprite so they flip with it.
	for child in get_children():
		if child is CollisionShape2D:
			child.position.x = 2.0 * sprite.position.x - child.position.x


# There's no slash art yet, so this is just a brief invisible hit box in front of the character.
func _slash() -> void:
	_spawn_hitbox(Vector2(SLASH_REACH, 0), SLASH_SIZE, SLASH_TIME)


# A brief invisible hit box. offset is from the sprite's centre, as if facing right.
func _spawn_hitbox(offset: Vector2, size: Vector2, time: float) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	var hitbox := Area2D.new()
	hitbox.add_child(collision)
	hitbox.position = sprite.position + Vector2(offset.x * facing, offset.y)
	hitbox.body_entered.connect(_on_slash_hit)
	add_child(hitbox)
	get_tree().create_timer(time).timeout.connect(hitbox.queue_free)
	attack_time_left = maxf(attack_time_left, time)


func _on_slash_hit(body: Node) -> void:
	# Only things in the "enemies" group get hit, so the floor and other characters are safe.
	if body.is_in_group("enemies"):
		body.hit()
