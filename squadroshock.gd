extends "res://base_character.gd"


const PLATFORM_SCENE = preload("res://platform.tscn")
# The spark burst shown on an enemy the spear hits.
const SPEAR_HIT_SCENE = preload("res://spear_hit.tscn")
# Where the platform's centre goes relative to the sprite's centre, when facing right.
const PLATFORM_OFFSET = Vector2(56, 4)
# Squadroshock's head (the red beak at the top right of its art) is its weak spot: an enemy (or
# an enemy's attack) touching it kills Squadroshock instantly. Obstacles (like a flame pillar)
# don't count: touching the head they just do their usual damage. The box sits on the head, measured
# from the sprite's centre as if facing right, a little bigger than the head so touches register.
const HEAD_OFFSET = Vector2(12, -24.5)
const HEAD_SIZE = Vector2(22, 14)
# Squadroshock can have this many platforms out at once; after that it can't place any more.
const MAX_PLATFORMS = 10
# How close a machine (anything in the "machine" group, like a mechanized door) must be in front
# of Squadroshock for X to switch it on or off instead of placing a platform.
const MACHINE_REACH = 32.0

# The electric spear's hit box, from the sprite's centre when facing right. It starts at
# the bolt sticking out past the shield in frame 8 and reaches 30 px beyond the art, so the
# jab has some reach.
const SPEAR_OFFSET = Vector2(36, 2)
const SPEAR_SIZE = Vector2(48, 12)
const SPEAR_TIME = 0.25

# The platforms Squadroshock has placed that are still around.
var platforms: Array[ShieldPlatform] = []


var head: Area2D


func _ready() -> void:
	super()
	head = Area2D.new()
	head.collision_layer = 0
	# Enemies (layer 1) and enemies' attacks (layer 4, like Zach's slash).
	head.collision_mask = 1 | 8
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = HEAD_SIZE
	head.add_child(shape)
	add_child(head)


func _physics_process(delta: float) -> void:
	super(delta)
	# Squadroshock can't survive water at all.
	if not dead and _touching_water():
		die()
	head.position = sprite.position + Vector2(HEAD_OFFSET.x * facing, HEAD_OFFSET.y)
	if not dead and not in_goal and _head_hit():
		die()


func _head_hit() -> bool:
	for body in head.get_overlapping_bodies():
		# An enemy Lobulux is holding or has thrown can't hurt anyone.
		if body.is_in_group("enemies") and not body.get("held") and not body.get("thrown") and not body.get("harmless"):
			return true
	for area in head.get_overlapping_areas():
		if area.is_in_group("enemy_attacks"):
			return true
	return false


# Squadroshock can't jump.
func _handle_jump() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if not active:
		return
	# "special" is bound to the controller's X button in the Input Map. Next to a machine it
	# switches the machine on or off; anywhere else it places a platform.
	if event.is_action_pressed("special") and not playing_action:
		var machine := _machine_in_reach()
		if machine:
			_toggle_machine(machine)
		else:
			_place_platform()


# Squadroshock's slash (Y) is an electric spear jab.
func _slash() -> void:
	if playing_action:
		return
	_spawn_hitbox(SPEAR_OFFSET, SPEAR_SIZE, SPEAR_TIME)
	_play_action("spear")


# The spear is Squadroshock's only hit box, so every enemy it hits gets the spark burst.
func _on_slash_hit(body: Node) -> void:
	super(body)
	if not body.is_in_group("enemies"):
		return
	var spark := SPEAR_HIT_SCENE.instantiate() as Node2D
	# In the level, so it stays put, centred on the enemy's body (its collision shape).
	get_parent().add_child(spark)
	var shape := body.get_node_or_null("CollisionShape2D") as Node2D
	spark.global_position = shape.global_position if shape else body.global_position


func _place_platform() -> void:
	if _platforms_out() >= MAX_PLATFORMS:
		return
	# Frames 6-7 pull the shield back then push it out; the platform appears once it's out.
	await _play_action("place_platform")
	var platform: ShieldPlatform = PLATFORM_SCENE.instantiate()
	platforms.append(platform)
	platform.facing = facing
	# Add it to the level rather than the character so it stays put.
	get_parent().add_child(platform)
	platform.global_position = sprite.global_position + Vector2(PLATFORM_OFFSET.x * facing, PLATFORM_OFFSET.y)


func _platforms_out() -> int:
	var count := 0
	for platform in platforms:
		if is_instance_valid(platform):
			count += 1
	return count


func _toggle_machine(machine: Node) -> void:
	await _play_action("toggle_machine")
	if is_instance_valid(machine) and not dead:
		machine.toggle()


# The machine Squadroshock is standing on (like a levipad), or else the nearest machine just in
# front of it, overlapping it top to bottom, or null.
func _machine_in_reach() -> Node2D:
	for node in get_tree().get_nodes_in_group("machine"):
		if node.has_method("carries") and node.carries(self):
			return node
	if is_on_floor():
		for i in get_slide_collision_count():
			var ground := get_slide_collision(i).get_collider() as Node2D
			if ground and ground.is_in_group("machine"):
				return ground
	var body: CollisionShape2D = $CollisionShape2D
	var me := body.global_transform * body.shape.get_rect()
	var nearest: Node2D = null
	var nearest_gap := INF
	for node in get_tree().get_nodes_in_group("machine"):
		var shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if not shape:
			continue
		var it := shape.global_transform * shape.shape.get_rect()
		if it.end.y < me.position.y or it.position.y > me.end.y:
			continue
		var gap := it.position.x - me.end.x if facing > 0 else me.position.x - it.end.x
		if gap < -me.size.x or gap > MACHINE_REACH:
			continue
		if gap < nearest_gap:
			nearest = node
			nearest_gap = gap
	return nearest


# Squadroshock is immune to electricity.
func _touch_hazard(hazard: String) -> void:
	if hazard != "hazard_electric":
		super(hazard)
