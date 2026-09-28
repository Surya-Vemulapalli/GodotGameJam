extends Enemy


# A lizard that walks along the ground, back and forth like Landfish. When a character comes up
# close in front of it, it stops and bites them (mouth opening, frames 3 and 4); close behind it,
# it stops and lashes its tail back at them (frame 6). It does one attack at a time, then walks on.
# Its art is drawn at 1.5 times size (the sprite's scale), and its body and attacks match that.
# How close (px, from the middle of its body) a character has to be to set it off, and how far
# above or below.
const ATTACK_REACH = 96.0
const ATTACK_HEIGHT = 60.0
# Each attack: the animation, the frame of it that hits, and its hit box (x is measured forwards
# from the middle of its body, so the tail's is negative) and size.
const BITE = {"animation": "bite", "frame": 1, "offset": Vector2(54, -13), "size": Vector2(48, 48)}
const WHIP = {"animation": "whip", "frame": 0, "offset": Vector2(-60, -25), "size": Vector2(60, 54)}
# How long a hit box lasts, and how long after an attack before it can attack again.
const HIT_TIME = 0.25
const ATTACK_COOLDOWN = 1.5

# The attack it's doing (BITE or WHIP), or empty.
var attack := {}
var attack_cooldown := 0.0


func _ready() -> void:
	super()
	add_to_group("non_mechanical")
	add_to_group("terrestrial")
	sprite.frame_changed.connect(_on_frame_changed)
	sprite.animation_finished.connect(_on_animation_finished)


func _move(delta: float) -> void:
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	if attack.is_empty() and attack_cooldown == 0.0 and is_on_floor():
		if _character_near(1):
			_start(BITE)
		elif _character_near(-1):
			_start(WHIP)
	if attack.is_empty():
		_walk(delta, SPEED)
		return
	velocity.x = 0.0
	if not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()


# Whether a character is close in front of it (side 1) or behind it (side -1).
func _character_near(side: int) -> bool:
	var middle := body.global_position
	for node in get_tree().get_nodes_in_group("characters"):
		var character := node as BaseCharacter
		if not character or character.dead or character.in_goal:
			continue
		var to_character: Vector2 = character.sprite.global_position - middle
		if to_character.x * direction * side > 0.0 and absf(to_character.x) <= ATTACK_REACH and absf(to_character.y) <= ATTACK_HEIGHT:
			return true
	return false


func _start(which: Dictionary) -> void:
	attack = which
	sprite.play(which.animation)
	if which.frame == 0:
		_hit()


func _on_frame_changed() -> void:
	if not attack.is_empty() and sprite.animation == attack.animation and sprite.frame == attack.frame and attack.frame > 0:
		_hit()


# The attack's hit box: any character in it takes damage.
func _hit() -> void:
	var shape := RectangleShape2D.new()
	shape.size = attack.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	var hitbox := Area2D.new()
	# On layer 4, so a weak spot like Squadroshock's head can notice it.
	hitbox.collision_layer = 8
	hitbox.add_to_group("enemy_attacks")
	# Characters are on collision layer 3.
	hitbox.collision_mask = 4
	hitbox.add_child(collision)
	hitbox.position = Vector2(body.position.x + attack.offset.x * direction, attack.offset.y)
	hitbox.body_entered.connect(_on_hit)
	add_child(hitbox)
	await get_tree().create_timer(HIT_TIME, false).timeout
	if is_instance_valid(hitbox):
		hitbox.queue_free()


func _on_hit(hit: Node) -> void:
	if hit is BaseCharacter and not hit.dead and not hit.in_goal and hit.hurt_cooldown == 0.0:
		hit.take_damage(hit._contact_damage(self))


func _on_animation_finished() -> void:
	if not attack.is_empty() and sprite.animation == attack.animation:
		attack = {}
		attack_cooldown = ATTACK_COOLDOWN
		sprite.play("walk")
