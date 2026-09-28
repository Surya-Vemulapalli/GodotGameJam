extends Enemy


# A flatworm that crawls back and forth along the ground, turning round at walls, ledges and
# water. When a character is just ahead of it, at about its height, it lunges: it stretches out
# straight and shoots forward, hurting whoever it runs into (the usual contact damage).
const CRAWL_SPEED = 40.0
# How far ahead of its head (and above or below it) a character has to be for it to lunge.
const LUNGE_REACH = 96.0
const LUNGE_HEIGHT = 40.0
const LUNGE_SPEED = 320.0
const LUNGE_TIME = 0.25
# The shortest wait between lunges.
const LUNGE_COOLDOWN = 1.5

var lunge_left := 0.0
var lunge_cooldown := 0.0


func _ready() -> void:
	super()
	add_to_group("non_mechanical")
	add_to_group("terrestrial")


func _move(delta: float) -> void:
	lunge_cooldown = maxf(lunge_cooldown - delta, 0.0)
	if lunge_left > 0.0:
		_lunge(delta)
	elif lunge_cooldown == 0.0 and is_on_floor() and _character_ahead():
		lunge_left = LUNGE_TIME
		lunge_cooldown = LUNGE_COOLDOWN
		sprite.play("lunge")
	else:
		_walk(delta, CRAWL_SPEED)


func _lunge(delta: float) -> void:
	lunge_left = maxf(lunge_left - delta, 0.0)
	if not is_on_floor():
		velocity.y += gravity * delta
	# It won't lunge off a ledge, into water or through a wall.
	if _edge_ahead() or (is_on_wall() and get_wall_normal().x * direction < 0.0):
		lunge_left = 0.0
	velocity.x = direction * LUNGE_SPEED if lunge_left > 0.0 else 0.0
	move_and_slide()
	if lunge_left == 0.0:
		sprite.play("crawl")


# Whether a living character (outside the goal cave) is just in front of its head.
func _character_ahead() -> bool:
	var rect := body.global_transform * body.shape.get_rect()
	var head := rect.position.x if direction < 0 else rect.end.x
	for node in get_tree().get_nodes_in_group("characters"):
		var character := node as BaseCharacter
		if not character or character.dead or character.in_goal:
			continue
		var to := character.global_position + _body_centre(character) - Vector2(head, rect.get_center().y)
		if to.x * direction > 0.0 and absf(to.x) <= LUNGE_REACH and absf(to.y) <= LUNGE_HEIGHT:
			return true
	return false


# The middle of a character's current collision shape, relative to its origin.
func _body_centre(character: BaseCharacter) -> Vector2:
	for child in character.get_children():
		if child is CollisionShape2D and not child.disabled:
			return (child.transform * child.shape.get_rect()).get_center()
	return Vector2.ZERO
