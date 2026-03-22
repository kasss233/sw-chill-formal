@tool
class_name FrostedPanel
extends PanelContainer

@export_group("Corner & Border")
@export var corner_radius: float = 21.0:
	set(value):
		corner_radius = value
		_update_shader_params()

@export var show_border: bool = true:
	set(value):
		show_border = value
		_update_shader_params()

@export var border_width: float = 1.0:
	set(value):
		border_width = value
		_update_shader_params()

@export var border_color: Color = Color("ffffff33"):
	set(value):
		border_color = value
		_update_shader_params()

@export_group("Frosted Effect")
@export_range(0.0, 10.0) var blur_amount: float = 6.0:
	set(value):
		blur_amount = value
		_update_shader_params()

@export_range(0.0, 3.0) var saturation: float = 1.6:
	set(value):
		saturation = value
		_update_shader_params()

@export_range(0.0, 2.0) var brightness: float = 1.1:
	set(value):
		brightness = value
		_update_shader_params()

@export var tint_color: Color = Color("6969694b"):
	set(value):
		tint_color = value
		_update_shader_params()

@export_range(0.0, 1.0) var noise_amount: float = 0:
	set(value):
		noise_amount = value
		_update_shader_params()

@export var noise_texture: Texture2D:
	set(value):
		noise_texture = value
		_update_shader_params()

@export_group("Shadow")
@export var show_shadow: bool = true:
	set(value):
		show_shadow = value
		_update_shadow_padding()
		_update_shader_params()

@export var shadow_color: Color = Color(0.1, 0.1, 0.1, 0.3):
	set(value):
		shadow_color = value
		_update_shader_params()

@export_range(0.0, 32.0) var shadow_size: float = 8.0:
	set(value):
		shadow_size = value
		_update_shadow_padding()
		_update_shader_params()

@export var shadow_offset: Vector2 = Vector2(0, 4):
	set(value):
		shadow_offset = value
		_update_shadow_padding()
		_update_shader_params()

@export_group("AI Glow")
@export var glow_width: float = 4.0:
	set(value):
		glow_width = value
		_update_shader_params()

@export var glow_speed: float = 0.8:
	set(value):
		glow_speed = value
		_update_shader_params()

@export var glow_softness: float = 2.0:
	set(value):
		glow_softness = value
		_update_shader_params()

var _shadow_padding: float = 0.0
var _glow_intensity: float = 0.0
var _glow_tween: Tween = null


func _ready() -> void:
	if material:
		material = material.duplicate()
	else:
		material = ShaderMaterial.new()
		material.shader = preload("res://scenes/main/ui/components/frosted_panel/frosted_panel.gdshader")

	# Default noise if none provided
	if noise_texture == null:
		var noise = FastNoiseLite.new()
		noise.frequency = 0.1
		var noise_tex = NoiseTexture2D.new()
		noise_tex.noise = noise
		noise_tex.width = 64
		noise_tex.height = 64
		# We don't want to save this to disk, just use it
		noise_texture = noise_tex

	_update_shadow_padding()
	connect("resized", _on_resized)
	_on_resized()
	_update_shader_params()


func _update_shadow_padding() -> void:
	# Calculate padding needed for shadow
	if show_shadow:
		_shadow_padding = shadow_size + max(abs(shadow_offset.x), abs(shadow_offset.y))
	else:
		_shadow_padding = 0.0

	# Apply padding as theme override for content margin
	var style = get_theme_stylebox("panel")
	if style:
		var new_style = style.duplicate() as StyleBoxFlat
		if new_style:
			new_style.content_margin_left = _shadow_padding
			new_style.content_margin_right = _shadow_padding
			new_style.content_margin_top = _shadow_padding
			new_style.content_margin_bottom = _shadow_padding
			# Make the stylebox transparent (shader handles rendering)
			new_style.bg_color = Color.TRANSPARENT
			add_theme_stylebox_override("panel", new_style)
	else:
		# Create a new transparent stylebox with padding
		var new_style = StyleBoxFlat.new()
		new_style.bg_color = Color.TRANSPARENT
		new_style.content_margin_left = _shadow_padding
		new_style.content_margin_right = _shadow_padding
		new_style.content_margin_top = _shadow_padding
		new_style.content_margin_bottom = _shadow_padding
		add_theme_stylebox_override("panel", new_style)


func _on_resized() -> void:
	if material:
		material.set_shader_parameter("size", size)


func _update_shader_params() -> void:
	if material:
		material.set_shader_parameter("corner_radius", corner_radius)
		material.set_shader_parameter("show_border", show_border)
		material.set_shader_parameter("border_width", border_width)
		material.set_shader_parameter("border_color", border_color)
		material.set_shader_parameter("blur_amount", blur_amount)
		material.set_shader_parameter("saturation", saturation)
		material.set_shader_parameter("brightness", brightness)
		material.set_shader_parameter("tint_color", tint_color)
		material.set_shader_parameter("noise_amount", noise_amount)
		material.set_shader_parameter("noise_texture", noise_texture)
		material.set_shader_parameter("show_shadow", show_shadow)
		material.set_shader_parameter("shadow_color", shadow_color)
		material.set_shader_parameter("shadow_size", shadow_size)
		material.set_shader_parameter("shadow_offset", shadow_offset)
		material.set_shader_parameter("shadow_padding", _shadow_padding)
		material.set_shader_parameter("size", size)
		material.set_shader_parameter("glow_width", glow_width)
		material.set_shader_parameter("glow_speed", glow_speed)
		material.set_shader_parameter("glow_softness", glow_softness)
		material.set_shader_parameter("glow_intensity", _glow_intensity)


func start_ai_glow(duration: float = 0.4) -> void:
	if _glow_tween:
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_glow_tween.tween_method(_set_glow_intensity, _glow_intensity, 1.0, duration)


func stop_ai_glow(duration: float = 0.6) -> void:
	if _glow_tween:
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_glow_tween.tween_method(_set_glow_intensity, _glow_intensity, 0.0, duration)


func is_ai_glow_active() -> bool:
	return _glow_intensity > 0.001


func _set_glow_intensity(value: float) -> void:
	_glow_intensity = value
	if material:
		material.set_shader_parameter("glow_intensity", value)
