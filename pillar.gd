@tool
class_name Pillar
extends Node2D


# An electric or fire pillar: a nozzle on the ground (yellow for lightning, red for fire) with
# lightning or a flame rising from it.
# Touching the lightning or flame is a hazard ("hazard_electric" / "hazard_fire") for the player
# characters only; enemies pass through it unharmed. A Squadroshock
# platform resting on the pad blocks it: the lightning or flame stops until the platform is
# taken away. Its origin is the bottom of the pad, on the ground. Characters walk through the
# pad from the side; platforms land on it from above.
const LOOKS = {
	"electric": {"pad": Rect2(212, 59, 11, 5), "hazard": Rect2(276, 0, 18, 62), "offset": 6.0, "gap": 0.0},
	"fire": {"pad": Rect2(338, 58, 9, 6), "hazard": Rect2(10, 64, 26, 64), "offset": 0.5, "gap": 0.0},
}

@export_enum("electric", "fire") var kind := "electric":
	set(value):
		kind = value
		_update_look()
# How many lightning bolts (or flames) tall it is, stacked up from the pad. Make it tall
# enough that Pyrazure can't just fly over it.
@export_range(1, 200) var height := 1:
	set(value):
		height = value
		_update_look()

var blocked := false


func _ready() -> void:
	_update_look()
	if Engine.is_editor_hint():
		return
	add_to_group(kind + "_pillar")
	$Hazard.add_to_group("hazard_" + kind)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var now_blocked := _platform_on_pad()
	if now_blocked != blocked:
		blocked = now_blocked
		$Hazard.visible = not blocked
		$Hazard/CollisionShape2D.set_deferred("disabled", blocked)


# Whether a platform has come to rest on the pad.
func _platform_on_pad() -> bool:
	var pad: CollisionShape2D = $Pad/CollisionShape2D
	var top := pad.global_transform * pad.shape.get_rect()
	for node in get_tree().get_nodes_in_group("platforms"):
		var platform := node as ShieldPlatform
		if not platform or platform.thrown or platform.get_node("CollisionShape2D").disabled:
			continue
		var shape: CollisionShape2D = platform.get_node("CollisionShape2D")
		var rect := shape.global_transform * shape.shape.get_rect()
		if absf(rect.end.y - top.position.y) <= 2.0 and rect.position.x < top.end.x and rect.end.x > top.position.x:
			return true
	return false


func _update_look() -> void:
	var pad_sprite := get_node_or_null("Pad/Sprite2D") as Sprite2D
	var pad_shape := get_node_or_null("Pad/CollisionShape2D") as CollisionShape2D
	var hazard_sprite := get_node_or_null("Hazard/Sprite2D") as Sprite2D
	var hazard_shape := get_node_or_null("Hazard/CollisionShape2D") as CollisionShape2D
	if not pad_sprite or not pad_shape or not hazard_sprite or not hazard_shape:
		return
	var look: Dictionary = LOOKS[kind]
	var pad: Rect2 = look["pad"]
	var hazard: Rect2 = look["hazard"]
	pad_sprite.region_rect = pad
	pad_sprite.position = Vector2(0, -pad.size.y / 2.0)
	var pad_rect := RectangleShape2D.new()
	pad_rect.size = pad.size
	pad_shape.shape = pad_rect
	pad_shape.position = pad_sprite.position
	# The lightning or flame stands on the pad, where it is in the art.
	var bottom := -pad.size.y - float(look["gap"])
	hazard_sprite.region_rect = hazard
	hazard_sprite.position = Vector2(look["offset"], bottom - hazard.size.y / 2.0)
	# The extra segments stack straight up from the first one.
	var segments := get_node("Hazard")
	for child in segments.get_children():
		if child.name.begins_with("Segment"):
			segments.remove_child(child)
			child.queue_free()
	for i in range(1, height):
		var segment := hazard_sprite.duplicate() as Sprite2D
		segment.name = "Segment%d" % i
		segment.position.y -= hazard.size.y * i
		segments.add_child(segment)
	var hazard_rect := RectangleShape2D.new()
	hazard_rect.size = Vector2(hazard.size.x * 0.8, hazard.size.y * height)
	hazard_shape.shape = hazard_rect
	hazard_shape.position = Vector2(look["offset"], bottom - hazard.size.y * height / 2.0)
