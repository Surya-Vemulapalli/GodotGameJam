extends Control


# The end page, shown once all four characters reach the cave on the last level: "You won!!" and
# "Thanks for playing" over the pink patterned background (sprites/end_page.png, tiled, drawn at
# 60% opacity over a light reddish pink BackgroundColor). Its
# button (gamepad A or the mouse) goes back to the start page.
const START_PAGE = "res://start.tscn"


func _ready() -> void:
	$Page/StartPage.pressed.connect(func(): get_tree().change_scene_to_file(START_PAGE))
	$Page/StartPage.grab_focus()
