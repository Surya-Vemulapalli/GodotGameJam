extends "res://base_character.gd"


const LASER_SCENE = preload("res://transpora_laser.tscn")
# Where the laser's centre sits relative to the sprite's centre, when facing right:
# straight up out of the opening in the top of Transpora's head.
const LASER_OFFSET = Vector2(-4.5, -58)
# With an item in the backpack the laser is this many times as long (stacked straight up).
const FULL_BACKPACK_LASER = 10
# That long laser can't be held: one press fires it for this long (seconds), held or not.
const FULL_BACKPACK_LASER_TIME = 0.75
# Transpora is weak to terrestrial (ground) enemies: touching one does this many times the
# usual damage.
const TERRESTRIAL_WEAKNESS = 2
# How close (from the sprite's centre, as if facing right) an item must be to pick it up.
const ITEM_REACH = Vector2(48, 48)
# Where a put-down item goes relative to the sprite's centre, when facing right.
const PUT_DOWN_OFFSET = Vector2(32, 16)

# True while the backpack is closed around an item (sheet frames 11-17).
var carrying := false
# The item in the backpack. It rides along inside Transpora, hidden and switched off.
var item: Node2D
# The beam, while the slash button is held (or, the long one, for a moment).
var laser: Area2D
# While the long laser is firing: how long it has left (0 for the ordinary, held laser).
var laser_time_left := 0.0


func _ready() -> void:
	super()
	# Shelby hunts Transpora.
	add_to_group("transpora")


func _unhandled_input(event: InputEvent) -> void:
	super(event)
	if not active:
		return
	# "special" is bound to the controller's X button in the Input Map. It picks up an item
	# (anything in the "movable" group) into the backpack, or puts the one in there down.
	if event.is_action_pressed("special") and not playing_action:
		if item:
			_put_down()
		else:
			_pick_up()
	# Holding Y fires the laser (see _slash); letting go stops it, unless it's the long laser,
	# which fires for a set time instead.
	elif event.is_action_released("slash") and laser_time_left == 0.0:
		_stop_laser()


func _physics_process(delta: float) -> void:
	super(delta)
	if not laser:
		return
	# Switching to another character (or dying) stops the laser.
	if not active:
		_stop_laser()
		return
	if laser_time_left > 0.0:
		laser_time_left -= delta
		if laser_time_left <= 0.0:
			_stop_laser()
			return
	laser.position = sprite.position + Vector2(LASER_OFFSET.x * facing, LASER_OFFSET.y)


# Transpora's animation names are listed in CLAUDE.md.
func _update_animation() -> void:
	if playing_action:
		return
	var animation := "walk" if velocity.x != 0.0 else "idle"
	if carrying:
		animation = "carry_" + animation
	if laser:
		animation += "_laser"
	sprite.play(animation)


# Transpora's attack (Y) is the laser, straight up; it destroys anything in the "enemies"
# group it touches.
func _slash() -> void:
	_start_laser()


func _is_attacking() -> bool:
	return super() or laser != null


# The laser hits enemies like any attack; with an item in the backpack (the long laser) it defeats
# a Gem Eater in one hit.
func _on_slash_hit(body: Node) -> void:
	if carrying and body.is_in_group("gem_eater"):
		body.hit(body.hits)
	else:
		super(body)


func _start_laser() -> void:
	if laser or playing_action:
		return
	laser = LASER_SCENE.instantiate()
	laser.position = sprite.position + Vector2(LASER_OFFSET.x * facing, LASER_OFFSET.y)
	laser.body_entered.connect(_on_slash_hit)
	if carrying:
		_lengthen_laser(FULL_BACKPACK_LASER)
		laser_time_left = FULL_BACKPACK_LASER_TIME
	add_child(laser)


# Stacks copies of the beam straight up from the first, and stretches its hit box to match.
func _lengthen_laser(segments: int) -> void:
	var beam: Sprite2D = laser.get_node("Sprite2D")
	var height := beam.texture.get_height()
	for i in range(1, segments):
		var copy := beam.duplicate() as Sprite2D
		copy.position.y -= height * i
		laser.add_child(copy)
	var hit_box: CollisionShape2D = laser.get_node("CollisionShape2D")
	var shape := hit_box.shape.duplicate() as RectangleShape2D
	shape.size.y = height * segments
	hit_box.shape = shape
	hit_box.position.y = -height * (segments - 1) / 2.0


func _stop_laser() -> void:
	laser_time_left = 0.0
	if laser:
		laser.queue_free()
		laser = null


func _pick_up() -> void:
	var target := _item_in_reach()
	if not target:
		return
	_stop_laser()
	await _play_action("pick_up")
	if not is_instance_valid(target) or dead:
		return
	item = target
	item.reparent(self)
	item.visible = false
	item.process_mode = Node.PROCESS_MODE_DISABLED
	carrying = true


func _put_down() -> void:
	_stop_laser()
	await _play_action("put_down")
	if not is_instance_valid(item) or dead:
		return
	item.reparent(get_parent())
	item.global_position = sprite.global_position + Vector2(PUT_DOWN_OFFSET.x * facing, PUT_DOWN_OFFSET.y)
	item.visible = true
	item.process_mode = Node.PROCESS_MODE_INHERIT
	# Next to a ground pedestal that takes it, it goes on the pedestal.
	var pedestal := _pedestal_in_reach(item)
	if pedestal:
		pedestal.place(item)
	elif item is LooseObject:
		item.drop()
	item = null
	carrying = false


# The nearest item in front of Transpora, or null if none is close enough.
func _item_in_reach() -> Node2D:
	var nearest: Node2D = null
	for node in get_tree().get_nodes_in_group("movable"):
		var candidate := node as Node2D
		if not candidate or candidate == item or (candidate is LooseObject and candidate.thrown):
			continue
		var offset := candidate.global_position - sprite.global_position
		offset.x *= facing
		if offset.x < -8.0 or offset.x > ITEM_REACH.x or absf(offset.y) > ITEM_REACH.y:
			continue
		if not nearest or offset.length() < (nearest.global_position - sprite.global_position).length():
			nearest = candidate
	return nearest


# The nearest empty ground pedestal in front of Transpora that takes the item, or null.
func _pedestal_in_reach(for_item: Node) -> Pedestal:
	var nearest: Pedestal = null
	for node in get_tree().get_nodes_in_group("pedestals"):
		var pedestal := node as Pedestal
		if not pedestal or pedestal.on_ceiling or not pedestal.accepts(for_item):
			continue
		var offset := pedestal.global_position - sprite.global_position
		offset.x *= facing
		if offset.x < -8.0 or offset.x > ITEM_REACH.x + 16.0 or absf(offset.y) > ITEM_REACH.y + 16.0:
			continue
		if not nearest or offset.length() < (nearest.global_position - sprite.global_position).length():
			nearest = pedestal
	return nearest


func _contact_damage(enemy: Node) -> int:
	if enemy.is_in_group("terrestrial"):
		return CONTACT_DAMAGE * TERRESTRIAL_WEAKNESS
	return CONTACT_DAMAGE
