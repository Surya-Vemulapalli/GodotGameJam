extends CanvasLayer


# Asks a yes/no question ("Do you want to restart this level?" unless `question` is set before
# it's added) with Yes and No buttons. It runs while the game is paused; B (ui_cancel) counts as
# No. It frees itself once answered.
signal answered(yes: bool)

var question := ""


func _ready() -> void:
	if question:
		$Center/Panel/Rows/Question.text = question
	%Yes.pressed.connect(_answer.bind(true))
	%No.pressed.connect(_answer.bind(false))
	# No is picked to start with, so an accidental press doesn't throw the level away.
	%No.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_answer(false)


func _answer(yes: bool) -> void:
	answered.emit(yes)
	queue_free()
