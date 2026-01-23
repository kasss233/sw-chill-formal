@tool
class_name InnerPanel
extends PanelContainer

## 内部子面板组件
## 用于在 FrostedPanel 等外部面板内部作为子容器使用
## 提供圆角、边框和半透明背景效果

@export_group("Corner & Border")
@export var corner_radius: float = 8.0:
	set(value):
		corner_radius = value
		_update_shader_params()

@export var border_width: float = 1.0:
	set(value):
		border_width = value
		_update_shader_params()

@export var border_color: Color = Color(1, 1, 1, 0.1):
	set(value):
		border_color = value
		_update_shader_params()

@export_group("Background")
@export var background_color: Color = Color(1, 1, 1, 0.05):
	set(value):
		background_color = value
		_update_shader_params()

@export_group("Content Padding")
@export var content_padding: float = 8.0:
	set(value):
		content_padding = value
		_update_content_padding()

func _ready() -> void:
	if material:
		material = material.duplicate()
	else:
		material = ShaderMaterial.new()
		material.shader = preload("res://scenes/main/ui/components/inner_panel/inner_panel.gdshader")
	
	_update_content_padding()
	connect("resized", _on_resized)
	_on_resized()
	_update_shader_params()

func _update_content_padding() -> void:
	# Apply padding as theme override for content margin
	var style = get_theme_stylebox("panel")
	if style:
		var new_style = style.duplicate() as StyleBoxFlat
		if new_style:
			new_style.content_margin_left = content_padding
			new_style.content_margin_right = content_padding
			new_style.content_margin_top = content_padding
			new_style.content_margin_bottom = content_padding
			# Make the stylebox transparent (shader handles rendering)
			new_style.bg_color = Color.TRANSPARENT
			add_theme_stylebox_override("panel", new_style)
	else:
		# Create a new transparent stylebox with padding
		var new_style = StyleBoxFlat.new()
		new_style.bg_color = Color.TRANSPARENT
		new_style.content_margin_left = content_padding
		new_style.content_margin_right = content_padding
		new_style.content_margin_top = content_padding
		new_style.content_margin_bottom = content_padding
		add_theme_stylebox_override("panel", new_style)

func _on_resized() -> void:
	if material:
		material.set_shader_parameter("size", size)

func _update_shader_params() -> void:
	if material:
		material.set_shader_parameter("corner_radius", corner_radius)
		material.set_shader_parameter("border_width", border_width)
		material.set_shader_parameter("border_color", border_color)
		material.set_shader_parameter("background_color", background_color)
		material.set_shader_parameter("size", size)
