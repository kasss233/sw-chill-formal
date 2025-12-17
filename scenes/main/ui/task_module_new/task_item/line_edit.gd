extends LineEdit

var is_completed = false : set = set_completed

func set_completed(value):
	is_completed = value
	if is_completed:
		var current_col = get_theme_color("font_color")
		current_col.a = 0.5
		add_theme_color_override("font_color", current_col)
	else:
		remove_theme_color_override("font_color")
	queue_redraw() # 触发重绘

func _draw():
	if is_completed:
		# 获取字体和文字大小来计算线的长度
		var font = get_theme_font("font")
		var font_size = get_theme_font_size("font_size")
		
		# 计算文字占用的像素宽度
		var text_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		
		# 线的垂直位置（高度的一半）
		var line_y = size.y / 2.0
		var col = Color.WHITE
		col.a = 0.5
		# 画线 (起点, 终点, 颜色, 线宽)
		draw_line(Vector2(0, line_y), Vector2(text_width, line_y), col, 2.0)
