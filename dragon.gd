extends "res://base_character.gd"


# Sheet frames 1-9 show the dragon on its hind legs, where its wings shouldn't
# collide. Frame 9 leans forward between standing and crawling, so its body sits
# further right. Frames 10+ show it on all fours, where the wings count as part of its body.
const LAST_UPRIGHT_SHEET_FRAME = 8
const LEANING_SHEET_FRAME = 9
# Sheet frames 7-8 are the claw swipe; the body shape skips the claws so they don't collide.
const SLASH_SHEET_FRAMES = [7, 8]
const SHEET_COLUMNS = 5
const FIRE_SCENE = preload("res://fire.tscn")
const GEM_SCENE = preload("res://gem.tscn")
# Where the mouth sits relative to the sprite's centre in each pose.
const MOUTH_UPRIGHT = Vector2(22, -24)
const MOUTH_ALL_FOURS = Vector2(54, -4)
# How long the special button must be held to breathe blue fire instead of red.
const CHARGE_TIME = 1.0
# After breathing fire, the dragon shows the fire-breathing version of its pose for this long.
const FIRE_POSE_TIME = 0.3
const FIRE_POSES = {
	"idle": "fire",
	"run": "run_fire",
	"jump": "fire",
	"crawl_idle": "crawl_fire",
	"crawl_walk": "crawl_walk_fire",
	"fly": "fly_fire",
	"swim": "swim_fire",
}
# The claw swipe's hit box (sheet frames 7-8), from the sprite's centre when facing right.
const CLAW_OFFSET = Vector2(28, 0)
const CLAW_SIZE = Vector2(32, 32)
const CLAW_TIME = 0.25
# While flying or swimming, Y spins the dragon round instead. The spin's hit box covers its body (on all
# fours) and reaches past it on both sides, breaking ore and hitting enemies either side.
const SPIN_OFFSET = Vector2(13, 7)
const SPIN_SIZE = Vector2(144, 64)
const SPIN_TIME = 0.3
# There's no spin art, so it rolls like a torpedo, round the axis running from its nose to
# its tail, by squashing the flying sprite flat and flipping it upside down this many times.
const SPIN_ROLLS = 2
# How fast the dragon rises while the jump button is held on all fours.
const FLY_VELOCITY = -200.0
# On all fours in water tiles (those with the tileset's "water" flag) the dragon swims: the
# left stick steers it up and down underwater (holding jump swims up too), and otherwise it
# slows down to a gentle sink. Standing, it can't swim; it's immune to water, so it just
# sinks to the bottom and walks along it.
const SWIM_SPEED = 150.0
# Surfacing while swimming up (stick up or B), it leaps this fast out of the water, high
# enough to clear the bank.
const SURFACE_LEAP = -330.0
const SINK_SPEED = 40.0
const WATER_DRAG = 600.0

@onready var upright_shape: CollisionShape2D = $CollisionShape2D
@onready var leaning_shape: CollisionShape2D = $LeaningCollisionShape2D
@onready var all_fours_shape: CollisionShape2D = $AllFoursCollisionShape2D
@onready var slash_shape: CollisionShape2D = $SlashCollisionShape2D

# Seconds the special button has been held, or -1 when it isn't being held.
var fire_held_time := -1.0
var swimming := false
# Seconds left of the fire-breathing pose.
var fire_pose_left := 0.0


func _ready() -> void:
	super()
	# Zach hunts whatever is in this group.
	add_to_group("pyrazure")
	sprite.frame_changed.connect(_update_collision)
	sprite.animation_changed.connect(_update_collision)
	_update_collision()


func _unhandled_input(event: InputEvent) -> void:
	# It can't stand up in water (standing, it can't swim); it has to climb out first.
	if active and event.is_action_pressed("toggle_crawl") and crawling and _is_in_water():
		return
	super(event)
	if not active:
		return
	# Leaning forward (sheet frame 9) is the in-between pose when dropping to all fours
	# or getting back up. The base class has already flipped crawling by now.
	if event.is_action_pressed("toggle_crawl") and not playing_action:
		_play_action("crawl_transition")
	# "special" is bound to the controller's X button in the Input Map.
	# A tap breathes red fire on release; holding it breathes blue fire.
	if event.is_action_pressed("special"):
		fire_held_time = 0.0
	elif event.is_action_released("special") and fire_held_time >= 0.0:
		fire_held_time = -1.0
		_breathe_fire(false)


func _process(delta: float) -> void:
	# A dead dragon doesn't finish charging blue fire (that would cut its death animation short).
	if fire_held_time < 0.0 or dead:
		return
	fire_held_time += delta
	if fire_held_time >= CHARGE_TIME:
		# Breathe as soon as it's charged, and ignore the eventual release.
		fire_held_time = -1.0
		_breathe_fire(true)


func _physics_process(delta: float) -> void:
	var was_swimming := swimming
	swimming = crawling and _is_in_water()
	if was_swimming and not swimming and active and _swimming_up():
		velocity.y = minf(velocity.y, SURFACE_LEAP)
	var was_on_floor := is_on_floor()
	super(delta)
	fire_pose_left = maxf(fire_pose_left - delta, 0.0)
	# On all fours, it takes off whenever it leaves the ground and lands when it's back on it.
	if crawling and not swimming and not playing_action and not dead and was_on_floor != is_on_floor():
		_play_action("fly_transition")


func _apply_gravity(delta: float) -> void:
	if swimming:
		velocity.y = move_toward(velocity.y, SINK_SPEED, WATER_DRAG * delta)
	else:
		super(delta)


# Standing, the jump button jumps. On all fours the dragon can't jump: holding it swims up
# in water, and flies out of it (so it takes off straight out of the water as it surfaces).
# Swimming, the left stick also steers it up and down.
func _handle_jump() -> void:
	if not crawling:
		super()
	elif swimming:
		var vertical := Input.get_axis("move_up", "move_down")
		if Input.is_action_pressed("jump"):
			vertical = -1.0
		if vertical != 0.0:
			velocity.y = vertical * SWIM_SPEED
	elif Input.is_action_pressed("jump"):
		velocity.y = FLY_VELOCITY


# The dragon's animation names are listed in CLAUDE.md. On all fours it swims in water,
# and flies whenever it's off the ground; standing, it shows the jump pose in the air.
# Right after breathing fire it shows the fire version of the pose (FIRE_POSES).
func _update_animation() -> void:
	if playing_action:
		return
	var moving := velocity.x != 0.0
	var animation: String
	if swimming:
		animation = "swim"
	elif not crawling:
		if not is_on_floor():
			animation = "jump"
		else:
			animation = "run" if moving else "idle"
	elif not is_on_floor():
		animation = "fly"
	else:
		animation = "crawl_walk" if moving else "crawl_idle"
	if fire_pose_left > 0.0:
		animation = FIRE_POSES[animation]
	# Only start it when it changes, so "jump" plays through once and holds its last frame.
	if sprite.animation != animation:
		var was_breathing_fire := sprite.animation == FIRE_POSES["jump"]
		sprite.play(animation)
		# Back from breathing fire mid-jump: carry on holding the jump's last frame.
		if animation == "jump" and was_breathing_fire:
			sprite.frame = sprite.sprite_frames.get_frame_count("jump") - 1


# The dragon's slash (Y) is a claw swipe. It needs its front claws free, so on all fours it
# can't swipe; flying or swimming it spins instead.
func _slash() -> void:
	if playing_action:
		return
	if crawling:
		if swimming or not is_on_floor():
			_spin()
		return
	_spawn_hitbox(CLAW_OFFSET, CLAW_SIZE, CLAW_TIME)
	var centre := sprite.global_position + Vector2(CLAW_OFFSET.x * facing, CLAW_OFFSET.y)
	_break_tiles(Rect2(centre - CLAW_SIZE / 2.0, CLAW_SIZE))
	_break_objects(Rect2(centre - CLAW_SIZE / 2.0, CLAW_SIZE))
	_play_action("slash")


func _spin() -> void:
	playing_action = true
	_spawn_hitbox(SPIN_OFFSET, SPIN_SIZE, SPIN_TIME)
	var centre := sprite.global_position + Vector2(SPIN_OFFSET.x * facing, SPIN_OFFSET.y)
	_break_tiles(Rect2(centre - SPIN_SIZE / 2.0, SPIN_SIZE))
	_break_objects(Rect2(centre - SPIN_SIZE / 2.0, SPIN_SIZE))
	var roll := create_tween()
	var height := absf(sprite.scale.x)
	roll.tween_method(func(angle: float): sprite.scale.y = height * cos(angle), 0.0, TAU * SPIN_ROLLS, SPIN_TIME)
	await roll.finished
	sprite.scale.y = height
	playing_action = false


# Breaks anything the claw (or spin) reaches that's in the "breakable_claw" group and knows how
# (claw_break()), like the rope holding up a plank.
func _break_objects(rect: Rect2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, rect.get_center())
	query.collide_with_areas = true
	query.collide_with_bodies = true
	for hit in get_world_2d().direct_space_state.intersect_shape(query):
		var thing: Node = hit.collider
		# The rope is part of its plank; the plank does the breaking.
		var owner_node := thing.get_parent() if thing.get_parent().has_method("claw_break") else thing
		if thing.is_in_group("breakable_claw") and owner_node.has_method("claw_break"):
			owner_node.claw_break()


# Breaks any tiles the claw (or spin) reaches that the tileset marks "breakable_claw" (ore walls),
# leaving behind the gem named in their "gem" data.
func _break_tiles(rect: Rect2) -> void:
	for layer in tile_layers:
		var start := layer.local_to_map(layer.to_local(rect.position))
		var end := layer.local_to_map(layer.to_local(rect.end))
		for x in range(start.x, end.x + 1):
			for y in range(start.y, end.y + 1):
				var cell := Vector2i(x, y)
				var data := layer.get_cell_tile_data(cell)
				if not data or not data.get_custom_data("breakable_claw"):
					continue
				var kind: String = data.get_custom_data("gem")
				layer.erase_cell(cell)
				if kind:
					var gem: Gem = GEM_SCENE.instantiate()
					gem.kind = kind
					get_parent().add_child(gem)
					gem.global_position = layer.to_global(layer.map_to_local(cell))


func _breathe_fire(blue: bool) -> void:
	var fire = FIRE_SCENE.instantiate()
	fire.shooter = self
	fire.blue = blue
	fire.direction = Vector2(facing, 0)
	var mouth := MOUTH_UPRIGHT if _current_sheet_frame() <= LEANING_SHEET_FRAME else MOUTH_ALL_FOURS
	mouth.x *= facing
	# Add it to the level rather than the dragon so it doesn't follow the dragon around.
	get_parent().add_child(fire)
	fire.global_position = sprite.global_position + mouth
	fire_pose_left = FIRE_POSE_TIME


func _update_collision() -> void:
	var sheet_frame := _current_sheet_frame()
	var active := all_fours_shape
	if sheet_frame in SLASH_SHEET_FRAMES:
		active = slash_shape
	elif sheet_frame <= LAST_UPRIGHT_SHEET_FRAME:
		active = upright_shape
	elif sheet_frame == LEANING_SHEET_FRAME:
		active = leaning_shape
	# Collision shapes can't be toggled mid-physics-step, so defer it.
	for shape in [upright_shape, leaning_shape, all_fours_shape, slash_shape]:
		shape.set_deferred("disabled", shape != active)


# Works out which cell of the spritesheet (1-25) is showing, from the atlas region.
func _current_sheet_frame() -> int:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture
	var cell := texture.region.position / texture.region.size
	return int(cell.y) * SHEET_COLUMNS + int(cell.x) + 1


# Pyrazure is immune to fire, and electricity (like an electric pillar's lightning) kills it
# instantly.
func _touch_hazard(hazard: String) -> void:
	if hazard == "hazard_electric":
		die()
	elif hazard != "hazard_fire":
		super(hazard)


func _swimming_up() -> bool:
	return Input.is_action_pressed("jump") or Input.get_axis("move_up", "move_down") < 0.0


# Standing, Pyrazure keeps out of the water: it can't walk or jump out over it (it can still
# cross on Squadroshock's platforms). On all fours it can go in and swim.
func _can_walk(direction: float) -> bool:
	return crawling or not _water_ahead(direction)
