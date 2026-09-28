class_name Enemy
extends CharacterBody2D


# Shared by the enemies. Every character's attack hits things in the "enemies" group (hit()), and
# Lobulux can grab enemies (they're "grabbable") and throw them: a thrown enemy is defeated when
# it hits something, taking out any enemy it hits too. Most enemies are defeated by one hit
# otherwise; set `hits` for tougher ones. Each enemy moves in its own way (_move).
const SPEED = 60.0
# After a hit that doesn't defeat it, it blinks and can't be hit again for this long.
const HIT_COOLDOWN = 0.5
# Falling this far down means it has fallen out of the level.
const FALL_DEATH_Y = 1500.0

# -1 moving left, 1 moving right. Enemies start off moving the way their art faces.
var direction := -1
# Which way the art is drawn facing. Most enemies face left; Carbot faces right.
var art_faces_left := true
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var tile_layers: Array[TileMapLayer] = []
# Held by Lobulux: it stops moving and nothing touches it.
var held := false
# Flying after Lobulux threw it.
var thrown := false
# How many hits it takes to defeat it.
var hits := 1
var hit_cooldown := 0.0
# A harmless enemy doesn't hurt characters that touch it.
var harmless := false
# Set once it has been in water (see _drained_out).
var been_in_water := false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if not art_faces_left:
		direction = 1
	add_to_group("enemies")
	add_to_group("grabbable")
	tile_layers = Water.layers_beside(self)


func _physics_process(delta: float) -> void:
	if hit_cooldown > 0.0:
		hit_cooldown = maxf(hit_cooldown - delta, 0.0)
		sprite.visible = hit_cooldown == 0.0 or int(hit_cooldown * 10.0) % 2 == 0
	if held:
		return
	if thrown:
		_fly(delta)
	else:
		_move(delta)
	if global_position.y > FALL_DEATH_Y:
		queue_free()


func _move(_delta: float) -> void:
	pass


# For fish that die out of water (Birdloch, Seasire, Spikefish): whether the water it was in has drained away
# (a blue button). Only counts once it has been in water, so one placed above a pool can still fall in.
func _drained_out() -> bool:
	var in_water := Water.is_water_at(tile_layers, body.global_position)
	if in_water:
		been_in_water = true
	return been_in_water and not in_water


# An attack hit it: it's defeated once it has taken `hits` hits. A strong attack (blue fire)
# counts as more than one.
func hit(amount := 1) -> void:
	if hit_cooldown > 0.0 or is_queued_for_deletion():
		return
	hits -= amount
	if hits <= 0:
		queue_free()
	else:
		hit_cooldown = HIT_COOLDOWN


func pick_up() -> void:
	held = true
	thrown = false
	body.set_deferred("disabled", true)


func throw(by: Node2D, launch_velocity: Vector2) -> void:
	held = false
	thrown = true
	velocity = launch_velocity
	body.set_deferred("disabled", false)
	if by:
		add_collision_exception_with(by)


func _fly(delta: float) -> void:
	velocity.y += gravity * delta
	var collision := move_and_collide(velocity * delta)
	if not collision:
		return
	var other := collision.get_collider() as Node
	# Throwing defeats outright, however many hits an enemy takes otherwise.
	if other and other.is_in_group("enemies"):
		other.queue_free()
	queue_free()


func _turn() -> void:
	direction = -direction
	sprite.flip_h = (direction > 0) == art_faces_left
	body.position.x = -body.position.x


# Walks along the ground, back and forth, turning round at walls, ledges and water.
func _walk(delta: float, speed: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	elif (is_on_wall() and get_wall_normal().x * direction < 0.0) or _edge_ahead():
		_turn()
	velocity.x = direction * speed
	move_and_slide()


# Whether the ground runs out (or turns to water) just ahead of its front foot.
func _edge_ahead() -> bool:
	var rect := body.global_transform * body.shape.get_rect()
	var ahead := Vector2(rect.end.x + 4.0 if direction > 0 else rect.position.x - 4.0, rect.end.y + 6.0)
	if Water.is_water_at(tile_layers, ahead):
		return true
	var query := PhysicsPointQueryParameters2D.new()
	query.position = ahead
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_point(query).is_empty()
