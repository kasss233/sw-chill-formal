extends Control

## MaterialSwitch Demo 开关演示场景

func _ready() -> void:
	# 连接开关信号
	var switches = find_children("", "MaterialSwitch", true, false)
	for sw in switches:
		if sw.toggled.is_connected(_on_switch_toggled):
			continue
		sw.toggled.connect(_on_switch_toggled.bind(sw))

func _on_switch_toggled(switch: MaterialSwitch, pressed: bool) -> void:
	print("开关 '", switch.label_text, "' 状态: ", pressed)

	# 如果是带颜色的开关，更新颜色演示
	if switch.name.begins_with("Color"):
		_update_color_switch(switch, pressed)

func _update_color_switch(switch: MaterialSwitch, pressed: bool) -> void:
	# 根据开关名称设置不同的颜色
	match switch.name:
		"ColorSwitch":
			if pressed:
				switch.active_color = Color(0.3, 0.7, 0.3)  # 绿色
			else:
				switch.inactive_color = Color(0.6, 0.6, 0.6)
		"ColorSwitch2":
			if pressed:
				switch.active_color = Color(0.95, 0.5, 0.3)  # 橙色
			else:
				switch.inactive_color = Color(0.6, 0.6, 0.6)
		"ColorSwitch3":
			if pressed:
				switch.active_color = Color(0.7, 0.3, 0.7)  # 紫色
			else:
				switch.inactive_color = Color(0.6, 0.6, 0.6)

## 演示：动态创建开关
func _on_create_switch_pressed() -> void:
	var new_switch = MaterialSwitch.new()
	new_switch.label_text = "新开关"
	add_child(new_switch)
	new_switch.position = Vector2(20, 400)
	new_switch.toggled.connect(_on_switch_toggled.bind(new_switch))

## 演示：切换所有开关
func _on_toggle_all_pressed() -> void:
	var switches = find_children("", "MaterialSwitch", true, false)
	for sw in switches:
		sw.button_pressed = not sw.button_pressed

## 演示：全部开启
func _on_turn_on_all_pressed() -> void:
	var switches = find_children("", "MaterialSwitch", true, false)
	for sw in switches:
		sw.button_pressed = true

## 演示：全部关闭
func _on_turn_off_all_pressed() -> void:
	var switches = find_children("", "MaterialSwitch", true, false)
	for sw in switches:
		sw.button_pressed = false
