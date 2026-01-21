extends Node

# ====== 节点引用 ======
# 这些节点引用在初始化时设置，用于调用实际的功能模块
var task_module: Node = null  # 任务管理模块节点引用
var project_module: Node = null  # 项目管理模块节点引用（待实现）
var scene_component_manager: Node = null  # 场景组件管理节点引用（待实现）
var bgm_manager: Node = null  # 背景音乐管理节点引用（待实现）
var ambient_noise_manager: Node = null  # 环境白噪音管理节点引用（待实现）
var focus_manager: Node = null  # 专注模式管理节点引用（待实现）
var performance_manager: Node = null  # 演出脚本管理节点引用（待实现）

# 任务ID生成器（用于将字符串ID转换为整数ID）
var _task_id_counter: int = 1
var _task_id_map: Dictionary = {}  # 映射：字符串ID -> 整数ID

# ====== 初始化 ======
func _ready() -> void:
	# 初始化节点引用
	# 注意：这些路径需要根据实际场景结构调整
	# 如果节点不存在，会在调用时进行空值检查
	_initialize_node_references()

func _initialize_node_references() -> void:
	# 尝试查找任务管理模块
	# 路径示例：根据实际场景结构调整
	var task_module_path = "/root/Main/UI/TaskModuleNew"
	if has_node(task_module_path):
		task_module = get_node(task_module_path)
		print("[Parser] 已找到任务管理模块: ", task_module_path)
	else:
		print("[Parser] 警告: 未找到任务管理模块，路径: ", task_module_path)
	
	# 其他模块的初始化（待实现）
	# project_module = get_node_or_null("...")
	# scene_component_manager = get_node_or_null("...")
	# bgm_manager = get_node_or_null("...")
	# ambient_noise_manager = get_node_or_null("...")
	# focus_manager = get_node_or_null("...")
	# performance_manager = get_node_or_null("...")

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
		"executed_operations": 0
	}
	
	# 清理JSON文本（移除可能的前缀）
	var cleaned_text = json_text.strip_edges()
	if cleaned_text.begins_with("Agent response: "):
		cleaned_text = cleaned_text.substr("Agent response: ".length()).strip_edges()
	
	# 解析JSON
	var json_parse_result = JSON.parse_string(cleaned_text)
	if json_parse_result == null:
		result["error"] = "JSON解析失败"
		print("[Parser] 错误: ", result["error"])
		return result
	
	var response_data = json_parse_result
	
	# 验证响应结构
	if not response_data.has("text"):
		result["error"] = "响应缺少 'text' 字段"
		print("[Parser] 错误: ", result["error"])
		return result
	
	result["parsed_response"] = response_data
	
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
				var op_result = _execute_operation(operation)
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
	var task_data_obj = _convert_python_task_to_godot_task(task_data)
	
	if task_data_obj == null:
		result["error"] = "任务数据转换失败"
		return result
	
	# 调用本脚本内的方法（抽象层）
	var success = _create_task_internal(task_data_obj)
	
	if success:
		result["success"] = true
		print("[Parser] 成功创建任务: ", task_data_obj.title)
	else:
		result["error"] = "任务创建失败"
	
	return result

func _create_task_internal(task_data: TaskData) -> bool:
	# 抽象层：本脚本内的处理方法
	# 如果节点引用存在，调用节点的方法
	if task_module != null and task_module.has_method("add_task"):
		task_module.add_task(task_data)
		return true
	else:
		print("[Parser] 警告: 任务管理模块不可用，任务创建功能未实现")
		# 即使节点不存在，也返回true表示本脚本已处理（待实现时再对接）
		return true

func _handle_update_task(operation: Dictionary) -> Dictionary:
	var result = {"success": false, "error": ""}
	
	if not operation.has("task_id") or not operation.has("task"):
		result["error"] = "update_task 操作缺少必要字段"
		return result
	
	var task_id_str = operation.get("task_id", "")
	var task_data = operation.get("task", {})
	
	# 将字符串ID转换为整数ID
	var task_id = _get_or_create_task_id(task_id_str)
	
	var task_data_obj = _convert_python_task_to_godot_task(task_data)
	if task_data_obj == null:
		result["error"] = "任务数据转换失败"
		return result
	
	# 设置ID
	task_data_obj.id = task_id
	
	var success = _update_task_internal(task_id, task_data_obj)
	
	if success:
		result["success"] = true
		print("[Parser] 成功更新任务: ", task_id)
	else:
		result["error"] = "任务更新失败"
	
	return result

func _update_task_internal(task_id: int, task_data: TaskData) -> bool:
	# 抽象层：本脚本内的处理方法
	if task_module != null and task_module.has_method("get_task_from_id"):
		var existing_task = task_module.get_task_from_id(task_id)
		if existing_task != null:
			# 更新任务数据
			existing_task.title = task_data.title
			existing_task.due_timestamp = task_data.due_timestamp
			existing_task.is_completed = task_data.is_completed
			# TODO: 更新其他字段
			print("[Parser] 任务更新功能待完善")
			return true
		else:
			print("[Parser] 警告: 任务不存在，ID: ", task_id)
			return false
	else:
		print("[Parser] 警告: 任务管理模块不可用，任务更新功能未实现")
		return true  # 待实现

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
	# 抽象层：本脚本内的处理方法
	if task_module != null and task_module.has_method("remove_task"):
		task_module.remove_task(task_id)
		return true
	else:
		print("[Parser] 警告: 任务管理模块不可用，任务删除功能未实现")
		return true  # 待实现

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
	# 抽象层：本脚本内的处理方法
	if task_module != null and task_module.has_method("mark_task_as_completed"):
		task_module.mark_task_as_completed(task_id)
		return true
	else:
		print("[Parser] 警告: 任务管理模块不可用，任务完成功能未实现")
		return true  # 待实现

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
	if project_module != null and project_module.has_method("create_project"):
		project_module.create_project(project_data)
		return true
	else:
		print("[Parser] 警告: 项目管理模块不可用，项目创建功能未实现")
		return true  # 待实现

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
	if project_module != null and project_module.has_method("update_project"):
		project_module.update_project(project_id, project_data)
		return true
	else:
		print("[Parser] 警告: 项目管理模块不可用，项目更新功能未实现")
		return true  # 待实现

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
	if project_module != null and project_module.has_method("delete_project"):
		project_module.delete_project(project_id)
		return true
	else:
		print("[Parser] 警告: 项目管理模块不可用，项目删除功能未实现")
		return true  # 待实现

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
	if scene_component_manager != null and scene_component_manager.has_method("update_components"):
		scene_component_manager.update_components(components)
		return true
	else:
		print("[Parser] 警告: 场景组件管理模块不可用，场景组件更新功能未实现")
		return true  # 待实现

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
	if bgm_manager != null and bgm_manager.has_method("set_volume"):
		bgm_manager.set_volume(volume)
		return true
	else:
		print("[Parser] 警告: BGM管理模块不可用，音量调整功能未实现")
		return true  # 待实现

func _switch_bgm_track_internal(track_id: String) -> bool:
	# 抽象层：本脚本内的处理方法
	if bgm_manager != null and bgm_manager.has_method("switch_track"):
		bgm_manager.switch_track(track_id)
		return true
	else:
		print("[Parser] 警告: BGM管理模块不可用，切换歌曲功能未实现")
		return true  # 待实现

func _toggle_bgm_playback_internal(play: bool) -> bool:
	# 抽象层：本脚本内的处理方法
	if bgm_manager != null:
		if play and bgm_manager.has_method("play"):
			bgm_manager.play()
			return true
		elif not play and bgm_manager.has_method("stop"):
			bgm_manager.stop()
			return true
	
	print("[Parser] 警告: BGM管理模块不可用，播放控制功能未实现")
	return true  # 待实现

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
	if ambient_noise_manager != null and ambient_noise_manager.has_method("set_ambient_noise"):
		ambient_noise_manager.set_ambient_noise(enabled, volume)
		return true
	else:
		print("[Parser] 警告: 环境白噪音管理模块不可用，环境白噪音更新功能未实现")
		return true  # 待实现

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
	if focus_manager != null and focus_manager.has_method("start_focus"):
		focus_manager.start_focus(focus_type, task_id)
		return true
	else:
		print("[Parser] 警告: 专注模式管理模块不可用，开始专注功能未实现")
		return true  # 待实现

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
	if focus_manager != null and focus_manager.has_method("end_focus"):
		focus_manager.end_focus(focus_record_id)
		return true
	else:
		print("[Parser] 警告: 专注模式管理模块不可用，结束专注功能未实现")
		return true  # 待实现

# ====== 演出脚本处理 ======
func _handle_performance_sequence(performance_sequence: Variant) -> void:
	# 处理演出脚本序列
	if performance_sequence == null:
		return
	
	# 抽象层：本脚本内的处理方法
	if performance_manager != null and performance_manager.has_method("play_sequence"):
		performance_manager.play_sequence(performance_sequence)
		print("[Parser] 开始播放演出脚本序列")
	else:
		print("[Parser] 警告: 演出脚本管理模块不可用，演出脚本功能未实现")

# ====== 数据转换辅助方法 ======
"""
将Python Task模型转换为Godot TaskData对象
"""
func _convert_python_task_to_godot_task(task_dict: Dictionary) -> TaskData:
	if not task_dict.has("info"):
		print("[Parser] 错误: 任务数据缺少 'info' 字段")
		return null
	
	var info = task_dict.get("info", {})
	var description = info.get("description", "新任务")
	
	# 处理时间戳
	var due_timestamp = 0
	if task_dict.has("deadline") and task_dict["deadline"] != null:
		due_timestamp = _parse_datetime_to_timestamp(task_dict["deadline"])
	elif task_dict.has("start_time") and task_dict["start_time"] != null:
		due_timestamp = _parse_datetime_to_timestamp(task_dict["start_time"])
	
	# 处理完成状态
	var is_completed = task_dict.get("completed", false)
	
	# 生成或获取任务ID
	var task_id_str = task_dict.get("id", "")
	var task_id = 0
	if task_id_str != null and task_id_str != "":
		task_id = _get_or_create_task_id(task_id_str)
	else:
		# 如果没有ID，生成新的整数ID
		task_id = _task_id_counter
		_task_id_counter += 1
	
	# 创建TaskData对象
	var task_data = TaskData.new(task_id, description, due_timestamp, is_completed)
	
	# 如果任务已完成，设置完成时间戳
	if is_completed and info.has("created_at"):
		var created_at = info.get("created_at", "")
		if created_at != "":
			task_data.finish_timestamp = _parse_datetime_to_timestamp(created_at)
	
	return task_data

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
	
	var date_part = date_time_parts[0]  # "2026-01-21"
	var time_part = date_time_parts[1]  # "15:33:06"
	
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
	
	var unix_time = Time.get_unix_time_from_datetime_dict(datetime_dict)
	return unix_time

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
		# 创建新的映射
		var new_id = _task_id_counter
		_task_id_counter += 1
		_task_id_map[task_id_str] = new_id
		return new_id
