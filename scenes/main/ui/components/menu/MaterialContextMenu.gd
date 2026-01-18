@tool
class_name MaterialContextMenu
extends MaterialMenu

## Material Design 风格上下文菜单（右键菜单）
## 附加到控件上，在右键点击时自动弹出

## 目标控件（右键点击此控件时弹出菜单）
var target_control: Control:
	set(value):
		# 断开旧控件的信号
		if target_control and target_control.gui_input.is_connected(_on_target_gui_input):
			target_control.gui_input.disconnect(_on_target_gui_input)
		
		target_control = value
		
		# 连接新控件的信号
		if target_control and not target_control.gui_input.is_connected(_on_target_gui_input):
			target_control.gui_input.connect(_on_target_gui_input)

## 是否在目标控件禁用时也禁用菜单
@export var disable_when_target_disabled: bool = true

func _ready() -> void:
	super._ready()
	
	# 如果在编辑器中，不处理输入
	if Engine.is_editor_hint():
		return

func _on_target_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if disable_when_target_disabled and target_control:
				# 检查控件是否禁用
				if target_control is BaseButton and target_control.disabled:
					return
				if target_control.has_method("is_disabled") and target_control.is_disabled():
					return
			
			popup_at_mouse()
			target_control.accept_event()

## 附加到控件
func attach_to(control: Control) -> void:
	target_control = control

## 从控件分离
func detach() -> void:
	target_control = null
