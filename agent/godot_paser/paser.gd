class_name Parser
extends Node

# ====== 节点引用 ======
# 这些节点引用在初始化时设置，用于调用实际的功能模块
@export var ui_node: UI = null # UI 主节点引用（包含所有模块）
@export var music_module: MusicModule = null # 音乐管理模块节点引用
@export var note_module: NoteModule = null # 笔记模块节点引用
@export var pomodoro_module: PomodoroTechniqueModule = null # 番茄钟模块节点引用（使用class_name）

# 任务ID生成器（用于将字符串ID转换为整数ID）
var _task_id_counter: int = 1
var _task_id_map: Dictionary = {} # 映射：字符串ID -> 整数ID

# ====== 初始化 ======
func _ready() -> void:
	# 初始化节点引用
	# 通过查找 UI 节点来获取所有模块引用
	_initialize_node_references()

func _initialize_node_references() -> void:
	# 尝试查找 UI 节点（主场景中的 UI 节点）
	# 路径可能因场景结构而异，尝试多个可能的路径
	var ui_paths = [
		"/root/Main/UI",
		"/root/UI",
		"../UI",
		"../../UI"
	]
	if ui_node == null:
		for path in ui_paths:
			if has_node(path):
				ui_node = get_node(path) as UI
				if ui_node:
					print("[Parser] 已找到 UI 节点: ", path)
					break
		
	if ui_node == null:
		# 如果找不到 UI 节点，尝试通过场景树查找
		var scene_tree = get_tree()
		if scene_tree:
			var root = scene_tree.root
			ui_node = _find_ui_node_recursive(root)
			if ui_node:
				print("[Parser] 通过递归查找找到 UI 节点")
	
	if ui_node == null:
		print("[Parser] 警告: 未找到 UI 节点，某些功能可能无法使用")
		return
	
	
## 递归查找 UI 节点
func _find_ui_node_recursive(node: Node) -> UI:
	if node is UI:
		return node as UI
	
	for child in node.get_children():
		var result = _find_ui_node_recursive(child)
		if result:
			return result
	
	return null

# ====== 主要解析接口 ======
"""
解析Agent传递来的JSON文本并执行相应操作

参数:
	json_text: Agent响应的JSON文本（可能包含 "Agent response: " 前缀）

返回:
	Dictionary: 解析结果，包含成功状态和错误信息
"""
func parse_and_execute(json_text: String) -> Dictionary:
	var result = {
		"success": false,
		"error": "",
		"parsed_response": null,
		"executed_operations": 0,
		"text": ""
	}
	
	# 清理JSON文本（移除可能的前缀）
	var cleaned_text = json_text.strip_edges()
	if cleaned_text.begins_with("Agent response: "):
		cleaned_text = cleaned_text.substr("Agent response: ".length()).strip_edges()
	
	# 解析JSON
	var json_parse_result = JSON.parse_string(cleaned_text)
	if json_parse_result == null:
		# 尝试使用 JSON.parse() 获取详细错误信息
		var json_parser = JSON.new()
		var parse_error = json_parser.parse(cleaned_text)
		if parse_error != OK:
			result["error"] = "JSON解析失败: " + str(json_parser.get_error_message())
		else:
			result["error"] = "JSON解析失败: 未知错误"
		print("[Parser] 错误: ", result["error"])
		return result
	
	var response_data = json_parse_result
	
	# 验证响应结构
	if not response_data.has("text"):
		result["error"] = "响应缺少 'text' 字段"
		print("[Parser] 错误: ", result["error"])
		return result
	
	result["parsed_response"] = response_data
	result["text"] = response_data.get("text", "")
	
	# 提取文本响应
	var text = response_data.get("text", "")
	print("[Parser] Agent文本响应: ", text)
	
	# 处理演出脚本序列（如果有）
	if response_data.has("performance_sequence") and response_data["performance_sequence"] != null:
		_handle_performance_sequence(response_data["performance_sequence"])
	
	# 处理操作列表
	var operations = response_data.get("operations", [])
	if operations is Array:
		for operation in operations:
			if operation is Dictionary:
				var op_result = await _execute_operation(operation)
				if op_result.get("success", false):
					result["executed_operations"] += 1
				else:
					print("[Parser] 操作执行失败: ", op_result.get("error", "未知错误"))
	else:
		print("[Parser] 警告: operations 不是数组类型")
	
	result["success"] = true
	print("[Parser] 解析完成，成功执行 %d 个操作" % result["executed_operations"])
	return result

# ====== 操作执行分发 ======
func _execute_operation(operation: Dictionary) -> Dictionary:
	var result = {
		"success": false,
		"error": ""
	}
	
	if not operation.has("action"):
		result["error"] = "操作缺少 'action' 字段"
		return result
	
	var action = operation.get("action", "")
	
	match action:
		"create_task":
			return _handle_create_task(operation)
		"update_task":
			return _handle_update_task(operation)
		"delete_task":
			return _handle_delete_task(operation)
		"complete_task":
			return _handle_complete_task(operation)
		"create_project":
			return _handle_create_project(operation)
		"update_project":
			return _handle_update_project(operation)
		"delete_project":
			return _handle_delete_project(operation)
		"update_scene_components":
			return _handle_update_scene_components(operation)
		"update_bgm":
			return _handle_update_bgm(operation)
		"update_ambient_noise":
			return _handle_update_ambient_noise(operation)
		"start_focus":
			return _handle_start_focus(operation)
		"end_focus":
			return _handle_end_focus(operation)
		"show_module":
			return _handle_show_module(operation)
		"hide_module":
			return _handle_hide_module(operation)
		_:
			result["error"] = "未知的操作类型: " + action
			print("[Parser] 错误: ", result["error"])
			return result

# ====== 任务相关操作处理 ======
func _handle_create_task(operation: Dictionary) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	if not operation.has("task"):
		result["error"] = "create_task 操作缺少 'task' 字段"
		return result
	
	var task_data = operation.get("task", {})
	
	# 提取任务信息
	var task_info = task_data.get("info", {})
	var description = task_info.get("description", "新任务")
	
	# 处理时间戳
	var due_timestamp = 0
	if task_data.has("deadline") and task_data["deadline"] != null:
		due_timestamp = _parse_datetime_to_timestamp(task_data["deadline"])
	elif task_data.has("start_time") and task_data["start_time"] != null:
		due_timestamp = _parse_datetime_to_timestamp(task_data["start_time"])
	
	# 调用本脚本内的方法（抽象层）
	var task_id = _create_task_internal(description, due_timestamp)
	
	if task_id > 0:
		result["success"] = true
		# 保存ID映射（如果原任务有字符串ID）
		var task_id_str = task_data.get("id", "")
		if task_id_str != null and task_id_str != "":
			_task_id_map[task_id_str] = task_id
		print("[Parser] 成功创建任务: ", description, " (ID: ", task_id, ")")
	else:
		result["error"] = "任务创建失败"
	
	return result

func _create_task_internal(title: String, due_timestamp: int) -> int:
	# 通过 TaskState 单例添加任务
	if TaskState:
		var task = TaskState.add_task(title, due_timestamp)
		return task.id
	else:
		print("[Parser] 警告: TaskState 单例不可用，任务创建功能未实现")
		return 0

func _handle_update_task(operation: Dictionary) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	if not operation.has("task_id") or not operation.has("task"):
		result["error"] = "update_task 操作缺少必要字段"
		return result
	
	var task_id_str = operation.get("task_id", "")
	var task_data = operation.get("task", {})
	
	# 将字符串ID转换为整数ID
	var task_id = _get_or_create_task_id(task_id_str)
	
	# 提取任务信息
	var task_info = task_data.get("info", {})
	var new_title = task_info.get("description", "")
	
	# 处理时间戳
	var due_timestamp = 0
	if task_data.has("deadline") and task_data["deadline"] != null:
		due_timestamp = _parse_datetime_to_timestamp(task_data["deadline"])
	elif task_data.has("start_time") and task_data["start_time"] != null:
		due_timestamp = _parse_datetime_to_timestamp(task_data["start_time"])
	
	# 调用协程函数需要使用 await
	var success = _update_task_internal(task_id, new_title, due_timestamp)
	
	if success:
		result["success"] = true
		print("[Parser] 成功更新任务: ", task_id)
	else:
		result["error"] = "任务更新失败"
	
	return result

func _update_task_internal(task_id: int, new_title: String, due_timestamp: int) -> bool:
	# 通过 TaskState 单例更新任务
	if not TaskState:
		print("[Parser] 警告: TaskState 单例不可用，任务更新功能未实现")
		return false

	# 更新标题
	if new_title != "":
		TaskState.update_task_title(task_id, new_title)

	# 更新截止时间
	if due_timestamp > 0:
		return TaskState.set_task_due_time(task_id, due_timestamp)

	return true

func _handle_delete_task(operation: Dictionary) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	if not operation.has("task_id"):
		result["error"] = "delete_task 操作缺少 'task_id' 字段"
		return result
	
	var task_id_str = operation.get("task_id", "")
	var task_id = _get_or_create_task_id(task_id_str)
	
	var success = _delete_task_internal(task_id)
	
	if success:
		result["success"] = true
		print("[Parser] 成功删除任务: ", task_id)
		# 清理ID映射
		_task_id_map.erase(task_id_str)
	else:
		result["error"] = "任务删除失败"
	
	return result

func _delete_task_internal(task_id: int) -> bool:
	# 通过 TaskState 单例删除任务
	if TaskState:
		return TaskState.remove_task(task_id)
	else:
		print("[Parser] 警告: TaskState 单例不可用，任务删除功能未实现")
		return false

func _handle_complete_task(operation: Dictionary) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	if not operation.has("task_id"):
		result["error"] = "complete_task 操作缺少 'task_id' 字段"
		return result
	
	var task_id_str = operation.get("task_id", "")
	var task_id = _get_or_create_task_id(task_id_str)
	
	var success = _complete_task_internal(task_id)
	
	if success:
		result["success"] = true
		print("[Parser] 成功完成任务: ", task_id)
	else:
		result["error"] = "任务完成操作失败"
	
	return result

func _complete_task_internal(task_id: int) -> bool:
	# 通过 TaskState 单例完成任务
	if TaskState:
		return TaskState.set_task_completed(task_id, true)
	else:
		print("[Parser] 警告: TaskState 单例不可用，任务完成功能未实现")
		return false

# ====== 项目相关操作处理 ======
func _handle_create_project(operation: Dictionary) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	if not operation.has("project"):
		result["error"] = "create_project 操作缺少 'project' 字段"
		return result
	
	var project_data = operation.get("project", {})
	var success = _create_project_internal(project_data)
	
	if success:
		result["success"] = true
		print("[Parser] 成功创建项目: ", project_data.get("name", ""))
	else:
		result["error"] = "项目创建失败"
	
	return result

func _create_project_internal(project_data: Dictionary) -> bool:
	# 抽象层：本脚本内的处理方法
	# 项目功能待实现
	print("[Parser] 警告: 项目管理功能未实现")
	return true # 待实现

func _handle_update_project(operation: Dictionary) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	if not operation.has("project_id") or not operation.has("project"):
		result["error"] = "update_project 操作缺少必要字段"
		return result
	
	var project_id = operation.get("project_id", "")
	var project_data = operation.get("project", {})
	
	var success = _update_project_internal(project_id, project_data)
	
	if success:
		result["success"] = true
		print("[Parser] 成功更新项目: ", project_id)
	else:
		result["error"] = "项目更新失败"
	
	return result

func _update_project_internal(project_id: String, project_data: Dictionary) -> bool:
	# 抽象层：本脚本内的处理方法
	# 项目功能待实现
	print("[Parser] 警告: 项目管理功能未实现")
	return true # 待实现

func _handle_delete_project(operation: Dictionary) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	if not operation.has("project_id"):
		result["error"] = "delete_project 操作缺少 'project_id' 字段"
		return result
	
	var project_id = operation.get("project_id", "")
	var success = _delete_project_internal(project_id)
	
	if success:
		result["success"] = true
		print("[Parser] 成功删除项目: ", project_id)
	else:
		result["error"] = "项目删除失败"
	
	return result

func _delete_project_internal(project_id: String) -> bool:
	# 抽象层：本脚本内的处理方法
	# 项目功能待实现
	print("[Parser] 警告: 项目管理功能未实现")
	return true # 待实现

# ====== 场景组件操作处理 ======
func _handle_update_scene_components(operation: Dictionary) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	if not operation.has("components"):
		result["error"] = "update_scene_components 操作缺少 'components' 字段"
		return result
	
	var components = operation.get("components", {})
	var success = _update_scene_components_internal(components)
	
	if success:
		result["success"] = true
		print("[Parser] 成功更新场景组件")
	else:
		result["error"] = "场景组件更新失败"
	
	return result

func _update_scene_components_internal(components: Dictionary) -> bool:
	# 抽象层：本脚本内的处理方法
	# 场景组件功能待实现
	print("[Parser] 警告: 场景组件管理功能未实现")
	return true # 待实现

# ====== 背景音乐操作处理 ======
func _handle_update_bgm(operation: Dictionary) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	if not operation.has("operation_type"):
		result["error"] = "update_bgm 操作缺少 'operation_type' 字段"
		return result
	
	var op_type = operation.get("operation_type", "")
	var success = false
	
	match op_type:
		"volume":
			# 音量调整功能待实现（MusicState 单例管理）
			var volume = operation.get("volume", 0.5)
			success = _update_bgm_volume_internal(volume)
		"switch":
			var track_id = operation.get("track_id", "")
			success = _switch_bgm_track_internal(track_id)
		"toggle":
			var play = operation.get("play", true)
			success = _toggle_bgm_playback_internal(play)
		_:
			result["error"] = "未知的BGM操作类型: " + op_type
			return result
	
	if success:
		result["success"] = true
		print("[Parser] 成功执行BGM操作: ", op_type)
	else:
		result["error"] = "BGM操作失败"
	
	return result

func _update_bgm_volume_internal(volume: float) -> bool:
	# 抽象层：本脚本内的处理方法
	# 音量调整功能待实现（需要通过 MusicState 单例）
	print("[Parser] 警告: BGM音量调整功能未实现")
	return true # 待实现

func _switch_bgm_track_internal(track_id: String) -> bool:
	# 通过 MusicState 单例切换曲目
	if MusicState:
		MusicState.set_track(track_id)
		MusicState.set_playing(true)
		return true
	else:
		print("[Parser] 警告: MusicState 单例不可用，切换歌曲功能未实现")
		return false

func _toggle_bgm_playback_internal(play: bool) -> bool:
	# 通过 MusicState 单例控制播放
	if MusicState:
		MusicState.set_playing(play)
		return true
	else:
		print("[Parser] 警告: MusicState 单例不可用，播放控制功能未实现")
		return false

# ====== 环境白噪音操作处理 ======
func _handle_update_ambient_noise(operation: Dictionary) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	if not operation.has("enabled"):
		result["error"] = "update_ambient_noise 操作缺少 'enabled' 字段"
		return result
	
	var enabled = operation.get("enabled", false)
	var volume = operation.get("volume", 0.5)
	
	var success = _update_ambient_noise_internal(enabled, volume)
	
	if success:
		result["success"] = true
		print("[Parser] 成功更新环境白噪音")
	else:
		result["error"] = "环境白噪音更新失败"
	
	return result

func _update_ambient_noise_internal(enabled: bool, volume: float) -> bool:
	# 抽象层：本脚本内的处理方法
	# 环境白噪音功能待实现
	print("[Parser] 警告: 环境白噪音管理功能未实现")
	return true # 待实现

# ====== 专注模式操作处理 ======
func _handle_start_focus(operation: Dictionary) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	if not operation.has("focus_type"):
		result["error"] = "start_focus 操作缺少 'focus_type' 字段"
		return result
	
	var focus_type = operation.get("focus_type", "")
	var task_id_str = operation.get("task_id", null)
	
	var task_id = null
	if task_id_str != null:
		task_id = _get_or_create_task_id(task_id_str)
	
	var success = _start_focus_internal(focus_type, task_id)
	
	if success:
		result["success"] = true
		print("[Parser] 成功开始专注模式: ", focus_type)
	else:
		result["error"] = "开始专注模式失败"
	
	return result

func _start_focus_internal(focus_type: String, task_id: Variant) -> bool:
	# 抽象层：本脚本内的处理方法
	match focus_type:
		"tomato":
			# 番茄钟专注模式
			if pomodoro_module:
				pomodoro_module.show_module()
			var success = PomodoroState.agent_start_pomodoro(25, 5, 1)
			if success:
				print("[Parser] 成功启动番茄钟专注模式")
				return true
			else:
				print("[Parser] 启动番茄钟专注模式失败")
				return false
		"free":
			# 自由专注模式（待实现）
			print("[Parser] 警告: 自由专注模式未实现")
			return true
		"task_triggered":
			# 任务触发的专注模式（待实现）
			print("[Parser] 警告: 任务触发专注模式未实现")
			return true
	
	print("[Parser] 警告: 未知的专注类型: ", focus_type)
	return false

func _handle_end_focus(operation: Dictionary) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	if not operation.has("focus_record_id"):
		result["error"] = "end_focus 操作缺少 'focus_record_id' 字段"
		return result
	
	var focus_record_id = operation.get("focus_record_id", "")
	var success = _end_focus_internal(focus_record_id)
	
	if success:
		result["success"] = true
		print("[Parser] 成功结束专注模式: ", focus_record_id)
	else:
		result["error"] = "结束专注模式失败"
	
	return result

func _end_focus_internal(focus_record_id: String) -> bool:
	# 抽象层：本脚本内的处理方法
	# 如果番茄钟正在运行，停止它
	if PomodoroState.agent_is_running():
		return PomodoroState.agent_stop()
	
	# 专注模式结束功能待实现
	print("[Parser] 警告: 结束专注模式功能未完全实现")
	return true # 待实现

# ====== 模块显示/隐藏操作处理 ======
func _handle_show_module(operation: Dictionary) -> Dictionary:
	var result = {"success": false, "error": ""}

	if not operation.has("module_name"):
		result["error"] = "show_module 操作缺少 'module_name' 字段"
		return result

	var module_name = operation.get("module_name", "")
	LayerManager.agent_show_module(module_name)
	result["success"] = true
	print("[Parser] 成功显示模块: ", module_name)
	return result

func _handle_hide_module(operation: Dictionary) -> Dictionary:
	var result = {"success": false, "error": ""}

	if not operation.has("module_name"):
		result["error"] = "hide_module 操作缺少 'module_name' 字段"
		return result

	var module_name = operation.get("module_name", "")
	LayerManager.agent_hide_module(module_name)
	result["success"] = true
	print("[Parser] 成功隐藏模块: ", module_name)
	return result

# ====== 演出脚本处理 ======
func _handle_performance_sequence(performance_sequence: Variant) -> void:
	# 处理演出脚本序列
	if performance_sequence == null:
		return
	
	# 抽象层：本脚本内的处理方法
	# 演出脚本功能待实现
	print("[Parser] 警告: 演出脚本功能未实现")

# ====== 数据转换辅助方法 ======
"""
解析ISO格式的日期时间字符串为Unix时间戳
格式示例: "2026-01-21T15:33:06.706338"
"""
func _parse_datetime_to_timestamp(datetime_str: String) -> int:
	if datetime_str == null or datetime_str == "":
		return 0
	
	# 移除微秒部分（如果有）
	var parts = datetime_str.split(".")
	var date_time_part = parts[0]
	
	# 解析日期时间
	# 格式: "2026-01-21T15:33:06"
	var date_time_parts = date_time_part.split("T")
	if date_time_parts.size() != 2:
		return 0
	
	var date_part = date_time_parts[0] # "2026-01-21"
	var time_part = date_time_parts[1] # "15:33:06"
	
	var date_parts = date_part.split("-")
	var time_parts = time_part.split(":")
	
	if date_parts.size() != 3 or time_parts.size() != 3:
		return 0
	
	var year = date_parts[0].to_int()
	var month = date_parts[1].to_int()
	var day = date_parts[2].to_int()
	var hour = time_parts[0].to_int()
	var minute = time_parts[1].to_int()
	var second = time_parts[2].to_int()
	
	# 使用Godot的Time类创建字典并转换为时间戳
	var datetime_dict = {
		"year": year,
		"month": month,
		"day": day,
		"hour": hour,
		"minute": minute,
		"second": second
	}
	
	# 约定：输入字符串按中国时区(UTC+8)理解，统一转换为 UTC Unix 时间戳
	return DateUtil.datetime_dict_cn_to_utc_unix(datetime_dict)

"""
获取或创建任务ID映射（将字符串ID转换为整数ID）
"""
func _get_or_create_task_id(task_id_str: String) -> int:
	if task_id_str == null or task_id_str == "":
		# 如果没有字符串ID，生成新的整数ID
		var new_id = _task_id_counter
		_task_id_counter += 1
		return new_id
	
	if _task_id_map.has(task_id_str):
		return _task_id_map[task_id_str]
	else:
		# 如果 TaskState 可用，尝试查找现有任务
		if TaskState:
			var all_tasks = TaskState.get_all_tasks()
			# 这里可以根据其他信息匹配任务（如标题）
			# 暂时生成新ID
			pass

		# 创建新的映射
		var new_id = _task_id_counter
		_task_id_counter += 1
		_task_id_map[task_id_str] = new_id
		return new_id
