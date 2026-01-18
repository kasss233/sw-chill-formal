class_name MaterialRippleMixin
extends RefCounted

## Material Design 涟漪效果混入类
## 为 Material Design 组件提供统一的涟漪效果实现

# 涟漪效果节点
var ripple_panel: ColorRect
var ripple_material: ShaderMaterial
var ripple_expand_tween: Tween
var ripple_fade_tween: Tween

# 涟漪配置
var ripple_color: Color = Color(0.5, 0.5, 0.5, 0.3)
var corner_radius: float = 4.0

# 宿主控件引用
var _host: Control

## 初始化涟漪效果
## host: 宿主控件
## shader_path: 涟漪shader路径
func setup(host: Control, shader_path: String = "res://scenes/main/ui/components/button/ripple.gdshader") -> void:
	_host = host
	
	if ripple_panel:
		return
	
	ripple_panel = ColorRect.new()
	ripple_panel.name = "RipplePanel"
	ripple_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ripple_panel.color = Color(1, 1, 1, 1)
	
	# 创建并应用涟漪 shader
	ripple_material = ShaderMaterial.new()
	var shader = load(shader_path)
	ripple_material.shader = shader
	ripple_material.set_shader_parameter("ripple_color", ripple_color)
	ripple_material.set_shader_parameter("ripple_radius", 0.0)
	ripple_material.set_shader_parameter("ripple_alpha", 0.0)
	ripple_material.set_shader_parameter("ripple_center", Vector2(0.5, 0.5))
	ripple_material.set_shader_parameter("button_size", Vector2(100, 40))
	ripple_material.set_shader_parameter("corner_radius", corner_radius)
	ripple_panel.material = ripple_material
	
	host.add_child(ripple_panel)
	ripple_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ripple_panel.size = host.size

## 设置涟漪颜色
func set_ripple_color(color: Color) -> void:
	ripple_color = color
	if ripple_material:
		ripple_material.set_shader_parameter("ripple_color", color)

## 设置圆角半径
func set_corner_radius(radius: float) -> void:
	corner_radius = radius
	if ripple_material:
		ripple_material.set_shader_parameter("corner_radius", radius)

## 更新按钮尺寸参数
func update_size(new_size: Vector2) -> void:
	if ripple_material:
		ripple_material.set_shader_parameter("button_size", new_size)
	if ripple_panel:
		ripple_panel.size = new_size

## 触发涟漪效果（按下时调用）
func trigger_ripple(local_mouse_pos: Vector2) -> void:
	if not ripple_panel or not ripple_material or not _host:
		return
	
	# 停止之前的动画
	if ripple_expand_tween and ripple_expand_tween.is_valid():
		ripple_expand_tween.kill()
	if ripple_fade_tween and ripple_fade_tween.is_valid():
		ripple_fade_tween.kill()
	
	var host_size = _host.size
	
	# 获取点击位置并转换为 UV 坐标
	var uv_center = local_mouse_pos / host_size
	uv_center = uv_center.clamp(Vector2.ZERO, Vector2.ONE)
	
	# 设置宽高比以保持圆形
	# 需要按照实际像素距离计算，所以直接使用 size 而不是比例
	var aspect = host_size.x / host_size.y if host_size.y > 0 else 1.0
	ripple_material.set_shader_parameter("aspect_ratio", Vector2(aspect, 1.0))
	ripple_material.set_shader_parameter("ripple_center", uv_center)
	ripple_material.set_shader_parameter("button_size", host_size)
	ripple_material.set_shader_parameter("corner_radius", corner_radius)
	
	# 计算需要的最大半径（从点击位置到最远角落的距离）
	var corners = [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2.ONE]
	var max_dist = 0.0
	for corner in corners:
		var dist = ((corner - uv_center) * Vector2(aspect, 1.0)).length()
		max_dist = max(max_dist, dist)
	
	# 确保涟漪面板可见并在最底层
	ripple_panel.show()
	_host.move_child(ripple_panel, 0)
	
	# 重置涟漪状态
	ripple_material.set_shader_parameter("ripple_radius", 0.0)
	ripple_material.set_shader_parameter("ripple_alpha", 1.0)
	
	# 创建扩散动画
	ripple_expand_tween = _host.create_tween()
	ripple_expand_tween.set_ease(Tween.EASE_OUT)
	ripple_expand_tween.set_trans(Tween.TRANS_CUBIC)
	ripple_expand_tween.tween_method(_set_ripple_radius, 0.0, max_dist * 1.1, 0.25)

## 淡出涟漪效果（松开时调用）
func fade_ripple() -> void:
	if not ripple_panel or not ripple_material or not _host:
		return
	
	# 只停止淡出动画
	if ripple_fade_tween and ripple_fade_tween.is_valid():
		ripple_fade_tween.kill()
	
	# 创建淡出动画
	ripple_fade_tween = _host.create_tween()
	ripple_fade_tween.set_ease(Tween.EASE_OUT)
	ripple_fade_tween.set_trans(Tween.TRANS_CUBIC)
	ripple_fade_tween.tween_method(_set_ripple_alpha, 1.0, 0.0, 0.2)

func _set_ripple_radius(value: float) -> void:
	if ripple_material:
		ripple_material.set_shader_parameter("ripple_radius", value)

func _set_ripple_alpha(value: float) -> void:
	if ripple_material:
		ripple_material.set_shader_parameter("ripple_alpha", value)

## 清理资源
func cleanup() -> void:
	if ripple_expand_tween and ripple_expand_tween.is_valid():
		ripple_expand_tween.kill()
	if ripple_fade_tween and ripple_fade_tween.is_valid():
		ripple_fade_tween.kill()
	if ripple_panel and is_instance_valid(ripple_panel):
		ripple_panel.queue_free()
