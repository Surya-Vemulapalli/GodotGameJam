extends Control


# The start page: Play starts level 1, Controls shows the controls page, Quit closes the game.
# Works with the gamepad (D-pad / left stick to move between buttons, A to press) and the mouse.
const FIRST_LEVEL = "res://levels/level_1.tscn"
const CONTROLS_PAGE = "res://controls.tscn"


func _ready() -> void:
	$Menu/Play.pressed.connect(func(): get_tree().change_scene_to_file(FIRST_LEVEL))
	$Menu/Controls.pressed.connect(func(): get_tree().change_scene_to_file(CONTROLS_PAGE))
	$Menu/Quit.pressed.connect(func(): get_tree().quit())
	$Menu/Play.grab_focus()
