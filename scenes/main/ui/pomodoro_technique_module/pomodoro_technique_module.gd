class_name PomodoroTechniqueModule
extends Control

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var pomodoro_technique = $CanvasLayer/PomodoroTechnique
@onready var pomodoro_button = $pomodoro_button


func _ready() -> void:
	pomodoro_technique.visible = false
	canvas_layer.layer = 10


func _on_pomodoro_button_state_changed(_old_state: int, new_state: int) -> void:
	LayerManager.bring_to_front(canvas_layer)
	if new_state == 0:
		GuiTransitions.hide("pomodorotechnique")
	else:
		GuiTransitions.show("pomodorotechnique")


func show_module() -> void:
	if not pomodoro_technique.visible:
		LayerManager.bring_to_front(canvas_layer)
		GuiTransitions.show("pomodorotechnique")
		pomodoro_button.set_state_no_signal(1)
