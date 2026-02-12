extends Control

## InputBox测试页 - 通过 ChatState 测试聊天相关 API

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

	# 监听 ChatState 信号
	ChatState.text_submitted.connect(_on_chat_state_text_submitted)
	ChatState.generation_stop_requested.connect(_on_chat_state_generation_stop_requested)

	_log_info("InputBox测试面板已就绪")

# --- 对话控制测试 ---

## 测试: 发送消息（通过 ChatState 信号触发）
func _on_send_message_pressed() -> void:
	var text = message_input.text
	var attachments = []

	# 收集附件
	if not attachment1_input.text.is_empty():
		attachments.append(attachment1_input.text)
	if not attachment2_input.text.is_empty():
		attachments.append(attachment2_input.text)

	_log_info("通过 ChatState.submit_text 发送消息(text='%s', attachments=%d个)" % [text, attachments.size()])
	ChatState.submit_text(text, attachments)
	_log_success("✓ 消息已发送")

## 测试: 停止生成
func _on_stop_generation_pressed() -> void:
	_log_info("调用 ChatState.set_status(IDLE)")
	ChatState.set_status(ChatState.Status.IDLE)
	_log_success("✓ 已设置为 IDLE 状态")

## 测试: 重置到就绪
func _on_reset_to_ready_pressed() -> void:
	_log_info("调用 ChatState.set_status(IDLE)")
	ChatState.set_status(ChatState.Status.IDLE)
	_log_success("✓ 已重置到就绪状态")

# --- 状态查询测试 ---

## 测试: 获取状态
func _on_get_status_pressed() -> void:
	_log_info("调用 ChatState.agent_get_chat_status()")
	var status = ChatState.agent_get_chat_status()

	_log_success("✓ 当前状态:")
	_log_data("  status: %s" % status.status)
	_log_data("  is_generating: %s" % status.is_generating)
	_log_data("  is_idle: %s" % status.is_idle)
	_log_data("  current_response_length: %d" % status.current_response_length)

## 测试: 检查是否正在生成
func _on_is_generating_pressed() -> void:
	_log_info("检查 ChatState.status == GENERATING")
	var is_generating = ChatState.status == ChatState.Status.GENERATING

	if is_generating:
		_log_success("✓ 当前正在生成")
	else:
		_log_success("✓ 当前未在生成")

## 测试: 检查是否就绪
func _on_is_ready_pressed() -> void:
	_log_info("检查 ChatState.status == IDLE")
	var is_idle = ChatState.status == ChatState.Status.IDLE

	if is_idle:
		_log_success("✓ 当前已就绪")
	else:
		_log_success("✓ 当前未就绪 (状态: %s)" % ChatState.Status.keys()[ChatState.status])

# --- 辅助功能测试 ---

## 测试: 设置文本
func _on_set_text_pressed() -> void:
	var text = message_input.text
	_log_info("调用 ChatState.agent_set_input_text(text='%s')" % text)
	var success = ChatState.agent_set_input_text(text)

	if success:
		_log_success("✓ 文本已设置")
	else:
		_log_error("✗ 设置失败")

## 测试: 清空输入
func _on_clear_input_pressed() -> void:
	_log_info("调用 ChatState.agent_clear_input()")
	var success = ChatState.agent_clear_input()

	if success:
		_log_success("✓ 输入已清空")
	else:
		_log_error("✗ 清空失败")

# --- 信号监听 ---

## 信号监听: ChatState.text_submitted
func _on_chat_state_text_submitted(text: String, attachments: Array) -> void:
	_log_success("收到 ChatState.text_submitted 信号:")
	_log_data("  文本: \"%s\"" % text)
	_log_data("  附件数量: %d" % attachments.size())
	for i in range(attachments.size()):
		_log_data("    [%d] %s" % [i, attachments[i]])

## 信号监听: ChatState.generation_stop_requested
func _on_chat_state_generation_stop_requested() -> void:
	_log_success("收到 ChatState.generation_stop_requested 信号")

# --- 辅助方法 ---

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
