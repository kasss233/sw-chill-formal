extends Control

## UI 引用（用于层级管理）
@export var _ui: UI = null

@onready var canvas_layer: CanvasLayer = $CanvasLayer
@onready var pomodoro_technique = $CanvasLayer/PomodoroTechnique
@onready var pomodoro_button = $pomodoro_button


func _ready() -> void:
	pomodoro_technique.visible = false
	# 设置 CanvasLayer 的初始层级
	canvas_layer.layer = 10

## 请求新的顶层层级
func _request_top_layer() -> void:
	if _ui:
		canvas_layer.layer = _ui.request_top_layer()
	else:
		# 降级方案：使用固定的高层级
		canvas_layer.layer = 100


func _on_pomodoro_button_state_changed(old_state: int, new_state: int) -> void:
	_request_top_layer()
	if new_state==0:
		GuiTransitions.hide("pomodorotechnique")
	else:
		# 请求新的顶层层级
		_request_top_layer()
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
