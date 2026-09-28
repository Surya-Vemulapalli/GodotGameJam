extends Enemy


# A walking robot with a yellow probe. It can't hurt anyone (touching it is harmless), but it
# shuts down machinery. It stands still until a machine within sight_range is on; then it walks
# over to it (waiting at the edge if a gap, water or a wall is in the way), and once the machine
# is just in front of it (or under its feet, like a levipad), it pokes it with its probe and
# switches it off: a mechanized door closes, a bridge machine pulls its bridge back in, a levipad
# stops. Then it stands still again until another machine nearby is switched on. Being a robot, red fire doesn't hurt it; it takes three hits
# to defeat (being thrown still defeats it outright).
# How far ahead of its body (px) its probe reaches.
const REACH = 24.0
# How close (px) a running machine has to be for it to notice and go after it. Set per
# Deactivator in the level.
@export var sight_range := 400.0
# Close enough (px, sideways) to a machine it can't reach (say, a levipad overhead) to stop and wait.
const CLOSE_ENOUGH = 8.0

var poking := false


func _init() -> void:
	harmless = true
	hits = 3


func _ready() -> void:
	super()
	add_to_group("terrestrial")
	add_to_group("mechanical")
	sprite.animation_finished.connect(_on_animation_finished)


func _move(delta: float) -> void:
	if not poking:
		var machine := _machine_in_reach()
		if machine:
			poking = true
			machine.shut_down()
			sprite.play("deactivate")
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = 0.0
	var target: Node = null if poking else _nearest_running_machine()
	if target:
		var to_target := _middle(target).x - body.global_position.x
		if absf(to_target) > CLOSE_ENOUGH:
			if int(signf(to_target)) != direction:
				_turn()
			var blocked := is_on_wall() and get_wall_normal().x * direction < 0.0
			if not (is_on_floor() and (blocked or _edge_ahead())):
				velocity.x = direction * SPEED
	move_and_slide()
	if not poking:
		sprite.play("walk" if velocity.x != 0.0 else "idle")


# The nearest machine within sight_range that's on, or null.
func _nearest_running_machine() -> Node:
	var nearest: Node = null
	var nearest_distance := sight_range
	for node in get_tree().get_nodes_in_group("machine"):
		if not _running_machine(node) or not node.get_node_or_null("CollisionShape2D"):
			continue
		var distance := body.global_position.distance_to(_middle(node))
		if distance <= nearest_distance:
			nearest = node
			nearest_distance = distance
	return nearest


func _middle(machine: Node) -> Vector2:
	var shape: CollisionShape2D = machine.get_node("CollisionShape2D")
	return (shape.global_transform * shape.shape.get_rect()).get_center()


# A running machine it's standing on, or else one just in front of it, level with it, or null.
func _machine_in_reach() -> Node:
	for node in get_tree().get_nodes_in_group("machine"):
		if node.has_method("carries") and node.carries(self) and _running_machine(node):
			return node
	if is_on_floor():
		for i in get_slide_collision_count():
			var ground := get_slide_collision(i).get_collider() as Node
			if _running_machine(ground):
				return ground
	var me := body.global_transform * body.shape.get_rect()
	for node in get_tree().get_nodes_in_group("machine"):
		if not _running_machine(node):
			continue
		var shape := node.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if not shape:
			continue
		var it := shape.global_transform * shape.shape.get_rect()
		if it.end.y < me.position.y or it.position.y > me.end.y:
			continue
		var gap := it.position.x - me.end.x if direction > 0 else me.position.x - it.end.x
		if gap >= -me.size.x and gap <= REACH:
			return node
	return null


func _running_machine(node: Node) -> bool:
	return node != null and node.is_in_group("machine") and node.has_method("is_on") and node.is_on()


func _on_animation_finished() -> void:
	if sprite.animation == "deactivate":
		poking = false
		sprite.play("idle")
