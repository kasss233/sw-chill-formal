extends Control

## MaterialProgressIndicator 演示脚本
## 展示线性/圆形、确定/不确定四种模式组合

@onready var linear_determinate: MaterialProgressIndicator = $VBoxContainer/HBoxContainer/VBox1/LinearDeterminate
@onready var linear_indeterminate: MaterialProgressIndicator = $VBoxContainer/HBoxContainer/VBox2/LinearIndeterminate
@onready var circular_determinate: MaterialProgressIndicator = $VBoxContainer/HBoxContainer2/VBox3/CircularDeterminate
@onready var circular_indeterminate: MaterialProgressIndicator = $VBoxContainer/HBoxContainer2/VBox4/CircularIndeterminate

@onready var progress_slider: HSlider = $VBoxContainer/ControlPanel/ProgressSlider
@onready var progress_label: Label = $VBoxContainer/ControlPanel/ProgressLabel

@onready var btn_0: Button = $VBoxContainer/ButtonPanel/Btn0
@onready var btn_25: Button = $VBoxContainer/ButtonPanel/Btn25
@onready var btn_50: Button = $VBoxContainer/ButtonPanel/Btn50
@onready var btn_75: Button = $VBoxContainer/ButtonPanel/Btn75
@onready var btn_100: Button = $VBoxContainer/ButtonPanel/Btn100

var _demo_progress: float = 0.0
var _auto_progress: bool = false

func _ready() -> void:
	# 初始化滑块
	if progress_slider:
		progress_slider.min_value = 0.0
		progress_slider.max_value = 1.0
		progress_slider.step = 0.01
		progress_slider.value = 0.0
		progress_slider.value_changed.connect(_on_progress_slider_changed)

	# 连接按钮信号
	if btn_0:
		btn_0.pressed.connect(_on_btn_0_pressed)
	if btn_25:
		btn_25.pressed.connect(_on_btn_25_pressed)
	if btn_50:
		btn_50.pressed.connect(_on_btn_50_pressed)
	if btn_75:
		btn_75.pressed.connect(_on_btn_75_pressed)
	if btn_100:
		btn_100.pressed.connect(_on_btn_100_pressed)

	_update_progress_label()

func _on_progress_slider_changed(value: float) -> void:
	_demo_progress = value

	# 滑块拖动时使用立即设置（无动画），避免延迟感
	if linear_determinate:
		linear_determinate.set_progress_immediate(value)
	if circular_determinate:
		circular_determinate.set_progress_immediate(value)

	_update_progress_label()

## 按钮点击时使用动画过渡
func _set_progress_animated(value: float) -> void:
	_demo_progress = value

	# 临时断开滑块信号，避免触发 _on_progress_slider_changed
	if progress_slider:
		progress_slider.value_changed.disconnect(_on_progress_slider_changed)
		progress_slider.value = value
		progress_slider.value_changed.connect(_on_progress_slider_changed)

	# 使用动画设置进度
	if linear_determinate:
		linear_determinate.set_progress_value(value)
	if circular_determinate:
		circular_determinate.set_progress_value(value)

	_update_progress_label()

func _on_btn_0_pressed() -> void:
	_set_progress_animated(0.0)

func _on_btn_25_pressed() -> void:
	_set_progress_animated(0.25)

func _on_btn_50_pressed() -> void:
	_set_progress_animated(0.5)

func _on_btn_75_pressed() -> void:
	_set_progress_animated(0.75)

func _on_btn_100_pressed() -> void:
	_set_progress_animated(1.0)

func _update_progress_label() -> void:
	if progress_label:
		progress_label.text = "进度: %d%%" % int(_demo_progress * 100)

## 自动进度演示
func start_auto_progress() -> void:
	_auto_progress = true
	_demo_progress = 0.0
	_animate_progress()

func _animate_progress() -> void:
	if not _auto_progress:
		return

	var tween = create_tween()
	tween.tween_property(self, "_demo_progress", 1.0, 3.0)
	tween.tween_callback(func():
		if _auto_progress:
			_demo_progress = 0.0
			_animate_progress()
	)

	# 同步更新滑块和进度条
	tween.parallel().tween_method(func(v: float):
		if progress_slider:
			progress_slider.value = v
		if linear_determinate:
			linear_determinate.set_progress_immediate(v)
		if circular_determinate:
			circular_determinate.set_progress_immediate(v)
		_update_progress_label()
	, 0.0, 1.0, 3.0)

func stop_auto_progress() -> void:
	_auto_progress = false
