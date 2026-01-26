extends Control
@onready var pomodoro_technique = $CanvasLayer/PomodoroTechnique
@onready var pomodoro_button = $pomodoro_button


func _ready() -> void:
	pomodoro_technique.visible = false
	

func _on_pomodoro_button_state_changed(_old_state: int, new_state: int) -> void:
	if new_state==0:
		GuiTransitions.hide("pomodorotechnique")
	else:
		GuiTransitions.show("pomodorotechnique")

signal work_started
func _on_pomodoro_technique_work_started() -> void:
	work_started.emit()


signal work_completed
func _on_pomodoro_technique_work_completed() -> void:
	work_completed.emit()

signal work_paused
func _on_pomodoro_technique_work_paused() -> void:
	work_paused.emit()

signal work_stopped
func _on_pomodoro_technique_work_stopped() -> void:
	work_stopped.emit()

signal work_continued
func _on_pomodoro_technique_work_continued() -> void:
	work_continued.emit()
