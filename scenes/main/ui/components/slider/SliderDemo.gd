extends Control

## MaterialSlider 演示场景脚本

@onready var horizontal_slider: MaterialSlider = $VBoxContainer/HBoxContainer/VBox1/HorizontalSlider
@onready var vertical_slider: MaterialSlider = $VBoxContainer/HBoxContainer/VBox2/VerticalSlider
@onready var custom_slider: MaterialSlider = $VBoxContainer/CustomSlider
@onready var value_label: Label = $VBoxContainer/ValueLabel

func _ready() -> void:
	# 横向滑动条
	horizontal_slider.value = 50

	# 竖向滑动条（已在场景中设置 orientation = 1）
	vertical_slider.value = 75

	# 自定义样式滑动条 - 绿色主题，更粗
	custom_slider.track_thickness = 40
	custom_slider.set_colors(
		Color(0.3, 0.8, 0.4),      # 激活色（绿色）
		Color(0.9, 0.9, 0.9),      # 未激活色
		Color.WHITE                # 滑块色
	)
	custom_slider.value = 30

	# 连接信号
	horizontal_slider.value_changed.connect(_on_horizontal_changed)
	vertical_slider.value_changed.connect(_on_vertical_changed)
	custom_slider.value_changed.connect(_on_custom_changed)

	_update_label()

func _on_horizontal_changed(val: float) -> void:
	print("横向滑动条: ", val)
	_update_label()

func _on_vertical_changed(val: float) -> void:
	print("竖向滑动条: ", val)
	_update_label()

func _on_custom_changed(val: float) -> void:
	print("自定义滑动条: ", val)
	_update_label()

func _update_label() -> void:
	if value_label:
		value_label.text = "横向: %d | 竖向: %d | 自定义: %d" % [
			int(horizontal_slider.value),
			int(vertical_slider.value),
			int(custom_slider.value)
		]
