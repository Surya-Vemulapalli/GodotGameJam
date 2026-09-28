@tool
class_name Portal
extends Area2D


# A one-way portal (sprites/portal.png: frame 1 the entrance, frame 2 the exit). A character that
# touches an entrance comes out at the exit named in its `destination`, feet on the exit's origin,
# still moving the way it was. Exits do nothing when touched, so a pair only works one way. Its
# origin is the bottom of the portal, on the ground.
const REGIONS = {
	"entrance": Rect2(21, 10, 37, 49),
	"exit": Rect2(21, 74, 37, 49),
}

@export_enum("entrance", "exit") var kind := "entrance":
	set(value):
		kind = value
		_update_look()
# Entrances only: the exit portal it sends characters to.
@export var destination: Portal


func _ready() -> void:
	_update_look()
	if Engine.is_editor_hint():
		return
	# Notice characters (collision layer 3).
	collision_layer = 0
	collision_mask = 4
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if kind != "entrance" or not is_instance_valid(destination):
		return
	var character := body as BaseCharacter
	if not character or character.dead or character.in_goal:
		return
	# Deferred: it can't be moved while Godot is reporting the touch.
	_send.call_deferred(character)


func _send(character: BaseCharacter) -> void:
	if not is_instance_valid(character) or not is_instance_valid(destination):
		return
	var shape := character.get_node("CollisionShape2D") as CollisionShape2D
	var feet := shape.global_transform * shape.shape.get_rect()
	character.global_position += destination.global_position - Vector2(feet.get_center().x, feet.end.y)


func _update_look() -> void:
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not sprite or not shape:
		return
	var region: Rect2 = REGIONS[kind]
	sprite.region_rect = region
	sprite.position = Vector2(0, -region.size.y / 2.0)
	var rect := RectangleShape2D.new()
	rect.size = region.size
	shape.shape = rect
	shape.position = sprite.position
