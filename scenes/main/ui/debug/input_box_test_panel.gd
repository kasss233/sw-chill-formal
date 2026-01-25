extends Control

## InputBox测试页 - 测试InputBox的Agent API

# UI节点引用
var input_box: InputBox = null  # 需要从外部设置

@onready var info_label: RichTextLabel = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InfoLabel
@onready var message_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/MessageInput
@onready var attachment1_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/Attachment1Input
@onready var attachment2_input: LineEdit = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/InputSection/Attachment2Input

# 测试按钮 - 对话控制
@onready var send_message_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/DialogSection/SendMessageBtn
@onready var stop_generation_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/DialogSection/StopGenerationBtn
@onready var reset_to_ready_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/DialogSection/ResetToReadyBtn

# 测试按钮 - 状态查询
@onready var get_status_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/QuerySection/GetStatusBtn
@onready var is_generating_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/QuerySection/IsGeneratingBtn
@onready var is_ready_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/QuerySection/IsReadyBtn

# 测试按钮 - 辅助功能
@onready var set_text_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/HelperSection/SetTextBtn
@onready var clear_input_btn: Button = $MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer/HelperSection/ClearInputBtn

func _ready() -> void:
	# 连接对话控制按钮
	send_message_btn.pressed.connect(_on_send_message_pressed)
	stop_generation_btn.pressed.connect(_on_stop_generation_pressed)
	reset_to_ready_btn.pressed.connect(_on_reset_to_ready_pressed)

	# 连接状态查询按钮
	get_status_btn.pressed.connect(_on_get_status_pressed)
	is_generating_btn.pressed.connect(_on_is_generating_pressed)
	is_ready_btn.pressed.connect(_on_is_ready_pressed)

	# 连接辅助功能按钮
	set_text_btn.pressed.connect(_on_set_text_pressed)
	clear_input_btn.pressed.connect(_on_clear_input_pressed)

	_log_info("InputBox测试面板已就绪")
	_log_info("请先设置input_box引用")

## 设置要测试的InputBox实例
func set_input_box(module: InputBox) -> void:
	input_box = module
	_log_info("已连接到InputBox: %s" % module.name)

	# 连接InputBox信号以监听事件
	input_box.text_submitted.connect(_on_input_box_text_submitted)
	input_box.generation_stopped.connect(_on_input_box_generation_stopped)

# --- 对话控制测试 ---

## 测试: 发送消息
func _on_send_message_pressed() -> void:
	if not _check_module():
		return

	var text = message_input.text
	var attachments = []

	# 收集附件
	if not attachment1_input.text.is_empty():
		attachments.append(attachment1_input.text)
	if not attachment2_input.text.is_empty():
		attachments.append(attachment2_input.text)

	_log_info("调用 agent_send_message(text='%s', attachments=%d个)" % [text, attachments.size()])
	var success = input_box.agent_send_message(text, attachments)

	if success:
		_log_success("✓ 消息已发送")
	else:
		_log_error("✗ 发送失败")

## 测试: 停止生成
func _on_stop_generation_pressed() -> void:
	if not _check_module():
		return

	_log_info("调用 agent_stop_generation()")
	var success = input_box.agent_stop_generation()

	if success:
		_log_success("✓ 生成已停止")
	else:
		_log_error("✗ 停止失败")

## 测试: 重置到就绪
func _on_reset_to_ready_pressed() -> void:
	if not _check_module():
		return

	_log_info("调用 agent_reset_to_ready()")
	var success = input_box.agent_reset_to_ready()

	if success:
		_log_success("✓ 已重置到就绪状态")
	else:
		_log_error("✗ 重置失败")

# --- 状态查询测试 ---

## 测试: 获取状态
func _on_get_status_pressed() -> void:
	if not _check_module():
		return

	_log_info("调用 agent_get_status()")
	var status = input_box.agent_get_status()

	_log_success("✓ 当前状态:")
	_log_data("  is_generating: %s" % status.is_generating)
	_log_data("  current_text: \"%s\"" % status.current_text)
	_log_data("  text_length: %d" % status.text_length)
	_log_data("  attachment_count: %d" % status.attachment_count)
	_log_data("  mode: %s" % status.mode)
	_log_data("  has_focus: %s" % status.has_focus)
	_log_data("  is_empty: %s" % status.is_empty)
	if status.attachments.size() > 0:
		_log_data("  attachments:")
		for i in range(status.attachments.size()):
			_log_data("    [%d] %s" % [i, status.attachments[i]])

## 测试: 检查是否正在生成
func _on_is_generating_pressed() -> void:
	if not _check_module():
		return

	_log_info("调用 agent_is_generating()")
	var is_generating = input_box.agent_is_generating()

	if is_generating:
		_log_success("✓ 当前正在生成")
	else:
		_log_success("✓ 当前未在生成")

## 测试: 检查是否就绪
func _on_is_ready_pressed() -> void:
	if not _check_module():
		return

	_log_info("调用 agent_is_ready()")
	var is_ready = input_box.agent_is_ready()

	if is_ready:
		_log_success("✓ 当前已就绪")
	else:
		_log_success("✓ 当前未就绪")

# --- 辅助功能测试 ---

## 测试: 设置文本
func _on_set_text_pressed() -> void:
	if not _check_module():
		return

	var text = message_input.text
	_log_info("调用 agent_set_text(text='%s')" % text)
	var success = input_box.agent_set_text(text)

	if success:
		_log_success("✓ 文本已设置")
	else:
		_log_error("✗ 设置失败")

## 测试: 清空输入
func _on_clear_input_pressed() -> void:
	if not _check_module():
		return

	_log_info("调用 agent_clear_input()")
	var success = input_box.agent_clear_input()

	if success:
		_log_success("✓ 输入已清空")
	else:
		_log_error("✗ 清空失败")

# --- 信号监听 ---

## 信号监听: text_submitted
func _on_input_box_text_submitted(text: String, attachments: Array) -> void:
	_log_success("📤 收到 text_submitted 信号:")
	_log_data("  文本: \"%s\"" % text)
	_log_data("  附件数量: %d" % attachments.size())
	for i in range(attachments.size()):
		_log_data("    [%d] %s" % [i, attachments[i]])

## 信号监听: generation_stopped
func _on_input_box_generation_stopped() -> void:
	_log_success("🛑 收到 generation_stopped 信号")

# --- 辅助方法 ---

## 检查InputBox是否已设置
func _check_module() -> bool:
	if input_box == null:
		_log_error("✗ InputBox未设置，请先调用set_input_box()")
		return false
	return true

## 日志输出 - 普通信息
func _log_info(message: String) -> void:
	info_label.append_text("[color=white]%s[/color]\n" % message)
	print("[InputBoxTest] %s" % message)

## 日志输出 - 成功信息
func _log_success(message: String) -> void:
	info_label.append_text("[color=green]%s[/color]\n" % message)
	print("[InputBoxTest] %s" % message)

## 日志输出 - 错误信息
func _log_error(message: String) -> void:
	info_label.append_text("[color=red]%s[/color]\n" % message)
	print("[InputBoxTest] ERROR: %s" % message)

## 日志输出 - 数据信息
func _log_data(message: String) -> void:
	info_label.append_text("[color=cyan]%s[/color]\n" % message)
	print("[InputBoxTest] %s" % message)
