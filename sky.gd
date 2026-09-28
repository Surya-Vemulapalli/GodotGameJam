@tool
extends Node2D


# A level's sky: one of the nine 64x64 skies on sprites/skies.png (numbered 1-9 left to right,
# top to bottom; sky 1 is the start and controls pages', level N uses sky N + 1), drawn 10x
# (640 px, the height of the screen) over a plain fill of the sky's own colour. It scrolls
# sideways with the level (repeating) but stays put on the screen vertically, so it shows
# wherever the camera is, however tall the level.
const SIZE = 64.0
const SCALE = 10.0
# Each sky's plain colour (its corner pixels).
const COLORS = [
	Color8(0, 249, 238), Color8(0, 214, 247), Color8(0, 111, 234),
	Color8(0, 31, 253), Color8(69, 75, 118), Color8(26, 0, 114),
	Color8(20, 9, 58), Color8(20, 9, 58), Color8(65, 0, 161),
]

@export_range(1, 9) var sky := 2:
	set(value):
		sky = value
		_update_look()


func _ready() -> void:
	_update_look()


func _update_look() -> void:
	var picture := get_node_or_null("Parallax/Sprite2D") as Sprite2D
	if not picture:
		return
	var index := sky - 1
	picture.region_rect = Rect2((index % 3) * SIZE, (index / 3) * SIZE, SIZE, SIZE)
	($Background/Color as ColorRect).color = COLORS[index]
