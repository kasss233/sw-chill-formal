extends UI
## 竖屏 UI 控制器，处理手机输入法键盘避让

@onready var _keyboard_spacer: MarginContainer = %KeyboardSpacer
@onready var _tab_panel: MarginContainer = $MarginContainer/VBoxContainer/TabPanel

var _last_keyboard_height: int = 0


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return

	var keyboard_height := DisplayServer.virtual_keyboard_get_height()
	if keyboard_height == _last_keyboard_height:
		return

	_last_keyboard_height = keyboard_height

	# 将像素高度转换为视口坐标
	var window_height := float(DisplayServer.window_get_size().y)
	var viewport_height := get_viewport().get_visible_rect().size.y
	var scale := viewport_height / window_height if window_height > 0.0 else 1.0
	var scaled_height := keyboard_height * scale

	# 减去 TabPanel 高度，因为它在 spacer 下方已占据底部空间
	var spacer_height := maxf(0.0, scaled_height - _tab_panel.size.y)
	_keyboard_spacer.custom_minimum_size.y = spacer_height
