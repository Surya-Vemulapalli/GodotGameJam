class_name Gem
extends LooseObject


# Where each kind of gem is drawn on sprites/ore.png. Ore walls in the tileset name the gem
# they drop in their "gem" custom data.
const REGIONS = {
	"yellow": Rect2(162, 21, 11, 16),
	"green": Rect2(99, 83, 10, 15),
	"white": Rect2(29, 145, 14, 14),
	"cyan": Rect2(147, 148, 12, 16),
	"red": Rect2(80, 223, 8, 18),
}

# Which gem this is; set it before adding the gem to the level.
@export var kind := "yellow"


func _ready() -> void:
	super()
	# Transpora can carry gems in its backpack.
	add_to_group("movable")
	# The Gem Eater hunts these.
	add_to_group("gems")
	var region: Rect2 = REGIONS[kind]
	var texture := $Sprite2D.texture.duplicate() as AtlasTexture
	texture.region = region
	$Sprite2D.texture = texture
	var shape := RectangleShape2D.new()
	shape.size = region.size
	$CollisionShape2D.shape = shape


func _physics_process(delta: float) -> void:
	super(delta)
	if not thrown:
		return
	for pedestal in get_tree().get_nodes_in_group("pedestals"):
		if pedestal.catches(self):
			pedestal.place(self)
			return


# Locks it onto a pedestal: it stops moving and can't be picked up or thrown any more.
func attach_to(pedestal: Node2D, socket: Vector2) -> void:
	thrown = false
	velocity = Vector2.ZERO
	remove_from_group("grabbable")
	remove_from_group("movable")
	# The Gem Eater can't eat it off a pedestal.
	remove_from_group("gems")
	$CollisionShape2D.set_deferred("disabled", true)
	reparent(pedestal, false)
	position = socket
	set_physics_process(false)
