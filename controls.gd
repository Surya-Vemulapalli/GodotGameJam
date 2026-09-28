extends Control


# The controls page. Back (or the gamepad's B button) returns to the start page.
const START_PAGE = "res://start.tscn"


func _ready() -> void:
	$Page/Back.pressed.connect(_back)
	$Page/Back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()


func _back() -> void:
	get_tree().change_scene_to_file(START_PAGE)
