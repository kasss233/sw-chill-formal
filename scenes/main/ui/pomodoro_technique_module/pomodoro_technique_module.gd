extends Control
@onready var pomodoro_technique = $CanvasLayer/PomodoroTechnique
@onready var pomodoro_button = $pomodoro_button

func _ready() -> void:
	pomodoro_technique.visible = false
	

func _on_pomodoro_button_state_changed(old_state: int, new_state: int) -> void:
	if new_state==0:
		GuiTransitions.hide("pomodorotechnique")
	else:
		GuiTransitions.show("pomodorotechnique")
