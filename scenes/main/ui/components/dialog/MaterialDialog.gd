@tool
class_name MaterialDialog
extends FrostedPanel

## Material Design 风格对话框
## 使用 FrostedPanel 实现毛玻璃背景效果
## 支持标题、内容、自定义按钮、背景遮罩、动画效果，遵循 Material Design 规范

signal dialog_confirmed()
signal dialog_cancelled()
signal dialog_closed()
signal button_pressed(button_index: int, button_text: String)

enum DialogType {
	INFO,        ## 信息对话框
	WARNING,     ## 警告对话框
	ERROR,       ## 错误对话框
	QUESTION,    ## 询问对话框
	CUSTOM       ## 自定义对话框
}

enum DialogSize {
	SMALL,       ## 小尺寸 (280dp)
	MEDIUM,      ## 中等尺寸 (400dp, 默认)
	LARGE,       ## 大尺寸 (560dp)
	CUSTOM       ## 自定义尺寸
}

## 对话框类型
@export var dialog_type: DialogType = DialogType.INFO:
	set(value):
		dialog_type = value
		_update_style()

## 对话框尺寸
@export var dialog_size: DialogSize = DialogSize.MEDIUM:
	set(value):
		dialog_size = value
		_update_size()

## 自定义宽度 (仅在 dialog_size 为 CUSTOM 时有效)
@export_range(200, 800, 10) var custom_width: int = 400:
	set(value):
		custom_width = value
		_update_size()

## 自定义高度 (仅在 dialog_size 为 CUSTOM 时有效, 0 表示自动)
@export_range(0, 600, 10) var custom_height: int = 0:
	set(value):
		custom_height = value
		_update_size()

## 对话框标题
@export var dialog_title: String = "":
	set(value):
		dialog_title = value
		_update_title()

## 对话框内容文字
@export_multiline var dialog_text: String = "":
	set(value):
		dialog_text = value
		_update_text()

## 自定义内容节点路径（优先于 dialog_text）
## 在编辑器中可以选择一个子节点的路径，该节点将替代默认的文本标签显示
@export_node_path("Control") var custom_content_path: NodePath = NodePath(""):
	set(value):
		custom_content_path = value
		_update_custom_content()

## 自定义内容节点引用（运行时自动解析）
var custom_content_node: Control = null

## 对话框图标
@export var dialog_icon: Texture2D:
	set(value):
		dialog_icon = value
		_update_icon()

## 内边距（注意：FrostedPanel 的 shadow_padding 会自动添加到此值之外）
@export_range(0, 64, 1) var padding: int = 32:
	set(value):
		padding = value
		_update_layout()

## 标题与内容间距
@export_range(0, 32, 1) var title_content_gap: int = 16:
	set(value):
		title_content_gap = value
		_update_layout()

## 内容与按钮间距
@export_range(0, 32, 1) var content_button_gap: int = 16:
	set(value):
		content_button_gap = value
		_update_layout()

## 按钮间距
@export_range(0, 16, 1) var button_gap: int = 8:
	set(value):
		button_gap = value
		_update_layout()

## 是否模态 (模态对话框会阻止背景交互)
@export var modal: bool = true

## 是否点击背景关闭
@export var close_on_background_click: bool = true

## 是否显示背景遮罩
@export var show_background_overlay: bool = true

## 背景遮罩渐变动画时长
@export_range(0.0, 1.0, 0.01) var overlay_fade_duration: float = 0.2

## 显示动画时长
@export_range(0.0, 1.0, 0.01) var show_animation_duration: float = 0.2

## 隐藏动画时长
@export_range(0.0, 1.0, 0.01) var hide_animation_duration: float = 0.15

## 背景遮罩颜色
@export var background_overlay_color: Color = Color(0, 0, 0, 0.5):
	set(value):
		background_overlay_color = value
		if _background_blocker:
			_background_blocker.color = background_overlay_color

## 背景遮罩透明度
@export_range(0.0, 1.0, 0.01) var background_overlay_alpha: float = 0.5:
	set(value):
		background_overlay_alpha = value
		if _background_blocker:
			var color = background_overlay_color
			color.a = background_overlay_alpha
			_background_blocker.color = color

@export_group("Buttons")
## 在检查器中配置的按钮列表
@export var buttons: Array[DialogButton] = []

# 内部节点
var _title_label: Label
var _text_label: RichTextLabel
var _icon_rect: TextureRect
var _content_container: VBoxContainer
var _button_container: HBoxContainer
var _background_blocker: ColorRect
var _blocker_canvas_layer: CanvasLayer
var _show_tween: Tween
var _overlay_tween: Tween  # 背景遮罩动画
var _buttons: Array[MaterialButton] = []
var _custom_content: Control = null  # 自定义内容节点引用

# 尺寸配置
const SIZE_MAP = {
	DialogSize.SMALL: {"width": 280, "min_height": 120},
	DialogSize.MEDIUM: {"width": 400, "min_height": 160},
	DialogSize.LARGE: {"width": 560, "min_height": 200}
}

# 图标尺寸
const ICON_SIZE: int = 48

func _ready() -> void:
	# 首先调用父类的 _ready()，让 FrostedPanel 初始化 shader
	super._ready()

	_setup_dialog()
	_update_style()
	_update_size()
	_update_layout()

	# 从检查器配置创建按钮
	_setup_buttons_from_config()

	# 编辑器模式下保持可见，运行时才隐藏
	if not Engine.is_editor_hint():
		visible = false
		modulate.a = 0

## 编辑器中节点树变化时重新初始化
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_CHILD_ORDER_CHANGED:
			if Engine.is_editor_hint() and is_inside_tree():
				# 延迟重新初始化，确保节点已完全添加
				call_deferred("_setup_dialog")
				call_deferred("_update_layout")

func _setup_dialog() -> void:
	# 设置基础属性
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 确保对话框使用固定尺寸，不会扩展填充
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# 设置 FrostedPanel 默认参数（只在编辑器中且使用默认值时）
	if Engine.is_editor_hint():
		if corner_radius == 12.0:
			corner_radius = 8.0
		if blur_amount == 3.0:
			blur_amount = 2.0
		if border_color == Color(1, 1, 1, 0.2):
			border_color = Color(0.3, 0.3, 0.3, 0.4)
		if shadow_size == 8.0:
			shadow_size = 12.0
			shadow_offset = Vector2(0, 6)

	# 创建内容容器
	_content_container = get_node_or_null("ContentContainer")
	if not _content_container:
		_content_container = VBoxContainer.new()
		_content_container.name = "ContentContainer"
		_content_container.add_theme_constant_override("separation", 0)
		_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content_container.size_flags_vertical = 0
		add_child(_content_container)

	# 创建或获取图标
	var is_new_icon = false
	_icon_rect = get_node_or_null("ContentContainer/IconRect")
	if not _icon_rect:
		is_new_icon = true
		_icon_rect = TextureRect.new()
		_icon_rect.name = "IconRect"
		_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon_rect.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		_icon_rect.visible = false
		_content_container.add_child(_icon_rect)

	# 创建或获取标题标签
	var is_new_title = false
	_title_label = get_node_or_null("ContentContainer/TitleLabel")
	if not _title_label:
		is_new_title = true
		_title_label = Label.new()
		_title_label.name = "TitleLabel"
		_content_container.add_child(_title_label)

	# 只对新创建的标签设置默认样式，编辑器中的保留用户设置
	if is_new_title or Engine.is_editor_hint():
		_title_label.add_theme_font_size_override("font_size", 20)
		_title_label.add_theme_color_override("font_color", Color.WHITE)
		_title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_title_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		# 编辑器中显示占位文本
		if Engine.is_editor_hint() and _title_label.text.is_empty():
			_title_label.text = "标题"

	# 创建或获取内容标签
	var is_new_text = false
	_text_label = get_node_or_null("ContentContainer/TextLabel")
	if not _text_label:
		is_new_text = true
		_text_label = RichTextLabel.new()
		_text_label.name = "TextLabel"
		_text_label.bbcode_enabled = true
		_text_label.fit_content = false
		_text_label.scroll_active = false
		_content_container.add_child(_text_label)

	# 只对新创建的标签设置默认样式，编辑器中的保留用户设置
	if is_new_text or Engine.is_editor_hint():
		_text_label.add_theme_color_override("default_color", Color(0.9, 0.9, 0.9))
		_text_label.add_theme_font_size_override("font_size", 14)
		# 编辑器中显示占位文本
		if Engine.is_editor_hint() and _text_label.text.is_empty():
			_text_label.text = "对话框内容"

	# 创建或获取按钮容器
	_button_container = get_node_or_null("ContentContainer/ButtonContainer")
	if not _button_container:
		_button_container = HBoxContainer.new()
		_button_container.name = "ButtonContainer"
		_button_container.alignment = BoxContainer.ALIGNMENT_END
		_button_container.add_theme_constant_override("separation", button_gap)
		_content_container.add_child(_button_container)

	# 编辑器模式下同步内容到导出变量
	if Engine.is_editor_hint():
		_sync_from_editor_nodes()

	# 最后更新显示的内容
	_update_title()
	_update_text()
	_update_icon()

## 从编辑器节点同步到导出变量
func _sync_from_editor_nodes() -> void:
	if _title_label and not _title_label.text.is_empty() and _title_label.text != "标题":
		dialog_title = _title_label.text
	if _text_label and not _text_label.text.is_empty() and _text_label.text != "对话框内容":
		dialog_text = _text_label.text
	if _icon_rect and _icon_rect.texture:
		dialog_icon = _icon_rect.texture

func _update_style() -> void:
	if not is_inside_tree():
		return

	# FrostedPanel 使用 shader 渲染，只需要更新 panel 的 content_margin
	# 获取当前的 panel style
	var style = get_theme_stylebox("panel")
	if style:
		var new_style = style.duplicate() as StyleBoxFlat
		# 设置内边距（FrostedPanel 的 shadow_padding 会自动添加）
		new_style.content_margin_left = padding
		new_style.content_margin_right = padding
		new_style.content_margin_top = padding
		new_style.content_margin_bottom = padding
		add_theme_stylebox_override("panel", new_style)

	# 确保内容容器正确布局
	call_deferred("_update_layout")

	# 根据对话框类型设置默认图标和颜色
	if not Engine.is_editor_hint():
		_update_dialog_type_style()

func _update_dialog_type_style() -> void:
	# 根据对话框类型设置 FrostedPanel 的样式
	# 参考 Menu 的配色风格，使用低调的深灰色
	match dialog_type:
		DialogType.INFO:
			# INFO 不带额外颜色，使用深灰色
			tint_color = Color(0.1, 0.1, 0.1, 0.6)
		DialogType.WARNING:
			# WARNING 稍微带一点橙色
			tint_color = Color(0.15, 0.12, 0.08, 0.6)
		DialogType.ERROR:
			# ERROR 稍微带一点红色
			tint_color = Color(0.15, 0.08, 0.08, 0.6)
		DialogType.QUESTION:
			# QUESTION 稍微带一点蓝色
			tint_color = Color(0.08, 0.1, 0.15, 0.6)
		DialogType.CUSTOM:
			# 使用用户设置的颜色
			pass

func _update_size() -> void:
	if not is_inside_tree():
		return

	var size_config = SIZE_MAP.get(dialog_size, SIZE_MAP[DialogSize.MEDIUM])

	# 设置固定宽度，高度自适应内容
	if dialog_size == DialogSize.CUSTOM:
		custom_minimum_size.x = custom_width
		custom_minimum_size.y = 0 if custom_height <= 0 else custom_height
		size.x = custom_width
		if custom_height > 0:
			size.y = custom_height
		else:
			size.y = 0  # 清除场景文件中的硬编码高度
	else:
		custom_minimum_size.x = size_config["width"]
		custom_minimum_size.y = 0  # 允许高度自适应
		size.x = size_config["width"]
		size.y = 0  # 清除场景文件中的硬编码高度

	# 确保对话框不会扩展填充父容器
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _update_layout() -> void:
	if not is_inside_tree() or not _content_container:
		return

	# 确保子节点顺序正确：图标 -> 标题 -> 自定义内容/文本 -> 按钮
	var children = _content_container.get_children()
	var desired_order = []
	if _icon_rect:
		desired_order.append(_icon_rect)
	if _title_label:
		desired_order.append(_title_label)
	# 自定义内容和文本标签互斥，只排列可见的
	if _custom_content and is_instance_valid(_custom_content):
		desired_order.append(_custom_content)
	elif _text_label:
		desired_order.append(_text_label)
	if _button_container:
		desired_order.append(_button_container)

	# 重新排序子节点
	for i in range(desired_order.size()):
		var child = desired_order[i]
		var current_index = children.find(child)
		if current_index >= 0 and current_index != i:
			_content_container.move_child(child, i)

	# 更新图标可见性和布局
	if _icon_rect:
		_icon_rect.visible = dialog_icon != null
		if dialog_icon:
			_icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_icon_rect.size_flags_vertical = 0

	# 更新标题可见性和布局
	if _title_label:
		_title_label.visible = dialog_title != ""
		if dialog_title != "":
			_title_label.size_flags_horizontal = 0  # 不扩展，根据文字宽度
			_title_label.size_flags_vertical = 0  # 不居中，从顶部开始
			# 设置合理的最小高度
			_title_label.custom_minimum_size = Vector2(0, 28)
			_title_label.size.y = 28

	# 更新自定义内容可见性和布局
	if _custom_content and is_instance_valid(_custom_content):
		_custom_content.visible = true
		_custom_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_custom_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	# 更新文字可见性和布局
	if _text_label:
		# 如果有自定义内容节点，隐藏默认的文本标签
		if _custom_content and is_instance_valid(_custom_content):
			_text_label.visible = false
		else:
			_text_label.visible = dialog_text != ""
			if dialog_text != "":
				# 让 RichTextLabel 占据可用宽度，但高度固定
				_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_text_label.size_flags_vertical = 0
				# 计算文本行数，设置合理的最小高度
				var line_count = dialog_text.count("\n") + 1
				var font_height = 24  # 14px 字体 + 行高，增加空间避免被裁剪
				_text_label.custom_minimum_size = Vector2(0, line_count * font_height)

	# 更新按钮容器间距和可见性
	if _button_container:
		_button_container.add_theme_constant_override("separation", button_gap)
		_button_container.visible = _buttons.size() > 0
		# 让按钮容器占据全宽，以便按钮可以右对齐
		_button_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button_container.size_flags_vertical = 0
		# 确保按钮容器右对齐
		_button_container.alignment = BoxContainer.ALIGNMENT_END

	# 动态设置间距
	var separation = 0
	if _icon_rect and _icon_rect.visible and _title_label and _title_label.visible:
		separation = max(separation, title_content_gap)
	# 标题与内容之间的间距
	var has_content = (_custom_content and is_instance_valid(_custom_content)) or (_text_label and _text_label.visible)
	if _title_label and _title_label.visible and has_content:
		separation = max(separation, title_content_gap)
	# 内容与按钮之间的间距
	if has_content and _button_container and _button_container.visible:
		separation = max(separation, content_button_gap)
	if separation == 0:
		separation = 8  # 默认间距
	_content_container.add_theme_constant_override("separation", separation)

func _update_title() -> void:
	if _title_label:
		# 编辑器模式下，如果不是占位文本才更新
		if Engine.is_editor_hint():
			if _title_label.text == "标题" or _title_label.text.is_empty():
				if dialog_title != "":
					_title_label.text = dialog_title
			else:
				# 保留编辑器中的内容
				pass
		else:
			_title_label.text = dialog_title
		_title_label.visible = dialog_title != "" or Engine.is_editor_hint()

func _update_text() -> void:
	if _text_label:
		# 编辑器模式下，如果不是占位文本才更新
		if Engine.is_editor_hint():
			if _text_label.text == "对话框内容" or _text_label.text.is_empty():
				if dialog_text != "":
					_text_label.text = dialog_text
			else:
				# 保留编辑器中的内容
				pass
		else:
			_text_label.text = dialog_text
		# 如果有自定义内容节点，默认文本标签隐藏
		if _custom_content and is_instance_valid(_custom_content):
			_text_label.visible = false
		else:
			_text_label.visible = dialog_text != "" or Engine.is_editor_hint()
		# 强制更新布局以确保文字显示
		if dialog_text != "" and is_inside_tree() and not Engine.is_editor_hint():
			call_deferred("_update_layout")

## 更新自定义内容节点
func _update_custom_content() -> void:
	# 移除旧的自定义内容节点引用
	_custom_content = null

	# 如果没有设置路径，直接返回
	if custom_content_path.is_empty():
		_update_text()
		_update_layout()
		return

	# 解析 NodePath 获取节点
	var node = get_node_or_null(custom_content_path)
	if node and node is Control:
		custom_content_node = node
		_custom_content = node
	else:
		custom_content_node = null
		_update_text()
		_update_layout()
		return

	# 更新布局和文本可见性（布局会自动排序节点）
	_update_text()
	_update_layout()

## 设置自定义内容节点
## content_node: 要显示的自定义内容节点
## returns: 设置成功返回 true
func set_custom_content(content_node: Control) -> bool:
	if not content_node:
		return false

	custom_content_node = content_node
	_custom_content = content_node

	# 确保节点在 _content_container 内
	if _content_container:
		if _custom_content.get_parent() != _content_container:
			if _custom_content.get_parent():
				_custom_content.get_parent().remove_child(_custom_content)
			_content_container.add_child(_custom_content)
	elif not _custom_content.get_parent():
		# 如果内容容器还不存在，添加为临时子节点，稍后会在 _setup_dialog 中重新排列
		add_child(_custom_content)

	_update_text()
	_update_layout()
	return true

func _update_icon() -> void:
	if _icon_rect:
		_icon_rect.texture = dialog_icon
		_icon_rect.visible = dialog_icon != null

# ============ 公共 API ============

## 添加按钮
## text: 按钮文字
## icon: 按钮图标 (可选)
## callback: 按钮点击回调 (可选)
## returns: 创建的 MaterialButton
func add_button(btn_text: String, icon: Texture2D = null, callback: Callable = Callable()) -> MaterialButton:
	if not _button_container:
		_setup_dialog()
	
	var button = MaterialButton.new()
	button.button_size = MaterialButton.ButtonSize.STANDARD36
	button.content_alignment = MaterialButton.ContentAlignment.ALIGN_CENTER
	# 先设置最小尺寸，防止首次显示时尺寸异常
	button.custom_minimum_size = Vector2(64, 36)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	_button_container.add_child(button)
	
	# 添加到树后再设置文字和图标，确保MaterialButton正确初始化
	button.text = btn_text
	button.button_icon = icon
	
	if callback.is_valid():
		var index = _buttons.size()
		button.pressed.connect(func(): 
			button_pressed.emit(index, btn_text)
			callback.call()
		)
	else:
		var index = _buttons.size()
		button.pressed.connect(func(): button_pressed.emit(index, btn_text))
	
	_buttons.append(button)
	
	return button

## 清空所有按钮
func clear_buttons() -> void:
	for button in _buttons:
		if is_instance_valid(button):
			button.queue_free()
	_buttons.clear()

## 显示对话框
func show_dialog() -> void:
	# 创建背景遮罩层（如果启用）
	if show_background_overlay:
		_create_background_blocker()

	# 设置高层级
	z_index = 1000

	# 将对话框移到父节点的最后
	var parent = get_parent()
	if parent:
		parent.move_child(self, parent.get_child_count() - 1)

	# 确保尺寸和布局已更新
	_update_size()
	_update_layout()

	# 等待一帧确保所有子节点完成初始化
	await get_tree().process_frame

	# 强制更新所有按钮的布局（在添加到树之后）
	for button in _buttons:
		if is_instance_valid(button):
			button._update_button_style()
			button._update_layout()

	# 再等一帧
	await get_tree().process_frame

	# 再次确保尺寸正确（防止被父容器影响）
	_update_size()

	# 强制根据内容刷新对话框高度
	await _refresh_dialog_height()

	# 居中显示
	await _center_dialog()

	# 停止之前的动画
	if _show_tween and _show_tween.is_valid():
		_show_tween.kill()
	if _overlay_tween and _overlay_tween.is_valid():
		_overlay_tween.kill()

	# 显示对话框动画
	visible = true
	modulate.a = 0
	scale = Vector2(0.9, 0.9)
	pivot_offset = size / 2

	_show_tween = create_tween()
	_show_tween.set_parallel(true)
	_show_tween.set_ease(Tween.EASE_OUT)
	_show_tween.set_trans(Tween.TRANS_CUBIC)
	_show_tween.tween_property(self, "modulate:a", 1.0, show_animation_duration)
	_show_tween.tween_property(self, "scale", Vector2.ONE, show_animation_duration)

	# 背景遮罩渐变动画
	if _background_blocker and is_instance_valid(_background_blocker):
		_overlay_tween = create_tween()
		_overlay_tween.set_ease(Tween.EASE_OUT)
		_overlay_tween.set_trans(Tween.TRANS_CUBIC)
		_overlay_tween.tween_property(_background_blocker, "modulate:a", 1.0, overlay_fade_duration)

## 隐藏对话框
func hide_dialog() -> void:
	# 停止之前的动画
	if _show_tween and _show_tween.is_valid():
		_show_tween.kill()
	if _overlay_tween and _overlay_tween.is_valid():
		_overlay_tween.kill()

	# 隐藏对话框动画
	_show_tween = create_tween()
	_show_tween.set_parallel(true)
	_show_tween.set_ease(Tween.EASE_IN)
	_show_tween.set_trans(Tween.TRANS_CUBIC)
	_show_tween.tween_property(self, "modulate:a", 0.0, hide_animation_duration)
	_show_tween.tween_property(self, "scale", Vector2(0.9, 0.9), hide_animation_duration)

	# 背景遮罩淡出动画
	if _background_blocker and is_instance_valid(_background_blocker):
		_overlay_tween = create_tween()
		_overlay_tween.set_ease(Tween.EASE_IN)
		_overlay_tween.set_trans(Tween.TRANS_CUBIC)
		_overlay_tween.tween_property(_background_blocker, "modulate:a", 0.0, overlay_fade_duration)
		# 动画结束后移除背景遮罩
		_overlay_tween.tween_callback(_remove_background_blocker)

	_show_tween.tween_callback(func(): visible = false)

	dialog_closed.emit()

## 显示确认对话框 (带"确定"和"取消"按钮)
func show_confirm_dialog(title: String, text: String, icon: Texture2D = null) -> void:
	dialog_title = title
	dialog_text = text
	dialog_icon = icon
	dialog_type = DialogType.QUESTION
	
	clear_buttons()
	
	var confirm_btn = add_button("确定")
	confirm_btn.pressed.connect(_on_confirm_button_pressed)
	
	var cancel_btn = add_button("取消")
	cancel_btn.pressed.connect(_on_cancel_button_pressed)
	
	show_dialog()

## 显示信息对话框 (带"确定"按钮)
func show_info_dialog(title: String, text: String, icon: Texture2D = null) -> void:
	dialog_title = title
	dialog_text = text
	dialog_icon = icon
	dialog_type = DialogType.INFO
	
	clear_buttons()
	
	var ok_btn = add_button("确定")
	ok_btn.pressed.connect(_on_confirm_button_pressed)
	
	show_dialog()

## 显示警告对话框
func show_warning_dialog(title: String, text: String, icon: Texture2D = null) -> void:
	dialog_title = title
	dialog_text = text
	dialog_icon = icon
	dialog_type = DialogType.WARNING
	
	clear_buttons()
	
	var ok_btn = add_button("确定")
	ok_btn.pressed.connect(_on_confirm_button_pressed)
	
	show_dialog()

## 显示错误对话框
func show_error_dialog(title: String, text: String, icon: Texture2D = null) -> void:
	dialog_title = title
	dialog_text = text
	dialog_icon = icon
	dialog_type = DialogType.ERROR
	
	clear_buttons()
	
	var ok_btn = add_button("确定")
	ok_btn.pressed.connect(_on_confirm_button_pressed)
	
	show_dialog()

# ============ 私有方法 ============

## 从检查器配置创建按钮
func _setup_buttons_from_config() -> void:
	# 只在buttons数组不为空时创建
	if buttons.is_empty():
		return

	# 清空现有按钮
	clear_buttons()

	# 根据配置创建按钮
	for button_config in buttons:
		if not button_config:
			continue

		# 根据action_type创建回调函数
		var callback: Callable
		var close_on_click = button_config.close_on_click

		match button_config.action_type:
			DialogButton.ActionType.CONFIRM:
				callback = func():
					if close_on_click:
						hide_dialog()
					dialog_confirmed.emit()
			DialogButton.ActionType.CANCEL:
				callback = func():
					if close_on_click:
						hide_dialog()
					dialog_cancelled.emit()
			DialogButton.ActionType.CUSTOM:
				callback = func():
					if close_on_click:
						hide_dialog()

		# 创建按钮
		var button = add_button(button_config.text, button_config.icon, callback)

		# 设置按钮尺寸
		button.button_size = button_config.button_size

		# 设置背景颜色（如果不是透明）
		if button_config.background_color != Color.TRANSPARENT:
			button.background_color = button_config.background_color

## 强制根据内容刷新对话框高度
func _refresh_dialog_height() -> void:
	if not _content_container or not is_inside_tree():
		return

	# 先强制更新一次布局
	_update_layout()

	# 等待一帧确保布局完成
	await get_tree().process_frame

	# 按顺序收集可见元素：图标 -> 标题 -> 自定义内容/文本 -> 按钮
	var ordered_elements = []
	if _icon_rect and _icon_rect.visible:
		ordered_elements.append(_icon_rect)
	if _title_label and _title_label.visible:
		ordered_elements.append(_title_label)
	# 自定义内容和文本标签互斥显示
	if _custom_content and is_instance_valid(_custom_content) and _custom_content.visible:
		ordered_elements.append(_custom_content)
	elif _text_label and _text_label.visible:
		ordered_elements.append(_text_label)
	if _button_container and _button_container.visible:
		ordered_elements.append(_button_container)

	# 计算内容高度
	var content_height := 0.0

	for i in range(ordered_elements.size()):
		var element = ordered_elements[i]
		# 使用 get_combined_minimum_size 获取最小尺寸
		var elem_height = element.get_combined_minimum_size().y
		# 如果为 0，尝试使用实际 size
		if elem_height <= 0:
			elem_height = element.size.y
		content_height += elem_height

		# 添加当前元素和下一个元素之间的间距
		if i < ordered_elements.size() - 1:
			var next_element = ordered_elements[i + 1]
			var gap := 0

			# 判断相邻元素类型，确定间距
			if element == _icon_rect and next_element == _title_label:
				gap = title_content_gap
			elif element == _title_label and (next_element == _text_label or next_element == _custom_content):
				gap = title_content_gap
			elif (element == _text_label or element == _custom_content) and next_element == _button_container:
				gap = content_button_gap
			else:
				gap = 8  # 默认间距

			content_height += gap

	# 获取 Panel 的 padding
	var style = get_theme_stylebox("panel")
	var padding_top = style.content_margin_top if style else padding
	var padding_bottom = style.content_margin_bottom if style else padding

	# 总高度 = 内容高度 + 上下 padding
	var final_height = content_height + padding_top + padding_bottom

	# 设置对话框的高度
	custom_minimum_size.y = final_height
	size.y = final_height

func _center_dialog() -> void:
	# 等待一帧确保 size 已更新
	await get_tree().process_frame
	
	var viewport_size = get_viewport_rect().size
	global_position = (viewport_size - size) / 2.0

func _on_confirm_button_pressed() -> void:
	hide_dialog()
	dialog_confirmed.emit()

func _on_cancel_button_pressed() -> void:
	hide_dialog()
	dialog_cancelled.emit()

## 创建背景遮罩层
func _create_background_blocker() -> void:
	if _background_blocker:
		return
	
	# 编辑器模式下不创建背景层
	if Engine.is_editor_hint():
		return
	
	# 使用 CanvasLayer 确保背景层覆盖整个屏幕
	_blocker_canvas_layer = CanvasLayer.new()
	_blocker_canvas_layer.name = "DialogBlockerCanvasLayer"
	_blocker_canvas_layer.layer = 99  # 高层级，但低于对话框
	get_tree().root.add_child(_blocker_canvas_layer)
	
	_background_blocker = ColorRect.new()
	_background_blocker.name = "DialogBackgroundBlocker"
	_background_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background_blocker.mouse_filter = Control.MOUSE_FILTER_STOP if modal else Control.MOUSE_FILTER_IGNORE
	var color = background_overlay_color
	color.a = background_overlay_alpha
	_background_blocker.color = color
	# 初始设置为透明，通过 modulate.a 控制渐变
	_background_blocker.modulate.a = 0

	# 点击背景层关闭对话框
	if close_on_background_click:
		_background_blocker.gui_input.connect(_on_background_blocker_input)

	_blocker_canvas_layer.add_child(_background_blocker)
	
	# 将对话框移到更高的 CanvasLayer
	z_index = 0  # 重置 z_index
	if not get_parent() is CanvasLayer or get_parent().layer < 100:
		# 如果对话框不在足够高的 CanvasLayer 中，创建一个
		var dialog_canvas = CanvasLayer.new()
		dialog_canvas.name = "DialogCanvasLayer"
		dialog_canvas.layer = 100
		get_tree().root.add_child(dialog_canvas)

		var old_parent = get_parent()
		old_parent.remove_child(self)
		dialog_canvas.add_child(self)

		# 重置 anchor 为左上角，防止尺寸被 viewport 影响
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		anchor_left = 0
		anchor_top = 0
		anchor_right = 0
		anchor_bottom = 0

		# 立即更新尺寸，确保正确
		_update_size()

		# 保存原始父节点以便恢复
		set_meta("_original_parent", old_parent)

## 移除背景遮罩层
func _remove_background_blocker() -> void:
	# 恢复对话框到原始父节点
	if has_meta("_original_parent"):
		var original_parent = get_meta("_original_parent")
		if is_instance_valid(original_parent):
			var current_canvas = get_parent()
			var old_global_pos = global_position
			current_canvas.remove_child(self)
			original_parent.add_child(self)
			global_position = old_global_pos
			
			# 清理对话框的 CanvasLayer
			if current_canvas is CanvasLayer and current_canvas.name == "DialogCanvasLayer":
				current_canvas.queue_free()
		remove_meta("_original_parent")
	
	if _background_blocker and is_instance_valid(_background_blocker):
		_background_blocker.queue_free()
		_background_blocker = null
	
	if _blocker_canvas_layer and is_instance_valid(_blocker_canvas_layer):
		_blocker_canvas_layer.queue_free()
		_blocker_canvas_layer = null

## 处理背景层的输入事件
func _on_background_blocker_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# 点击背景层关闭对话框
			if close_on_background_click:
				hide_dialog()
				dialog_cancelled.emit()
