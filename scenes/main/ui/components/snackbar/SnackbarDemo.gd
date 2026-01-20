extends Control

## MaterialSnackbar 演示场景脚本

@onready var snackbar: MaterialSnackbar = $MaterialSnackbar
@onready var show_simple_btn: Button = $VBoxContainer/ShowSimpleBtn
@onready var show_info_btn: Button = $VBoxContainer/ShowInfoBtn
@onready var show_success_btn: Button = $VBoxContainer/ShowSuccessBtn
@onready var show_warning_btn: Button = $VBoxContainer/ShowWarningBtn
@onready var show_error_btn: Button = $VBoxContainer/ShowErrorBtn
@onready var position_option: OptionButton = $VBoxContainer/PositionHBox/PositionOption
@onready var status_label: Label = $VBoxContainer/StatusLabel

var _action_count: int = 0

# 位置名称映射
const POSITION_NAMES: Array[String] = [
	"底部居中",
	"顶部居中",
	"屏幕中央",
	"左上角",
	"右上角",
	"左下角",
	"右下角"
]

func _ready() -> void:
	# 初始化位置选项
	for pos_name in POSITION_NAMES:
		position_option.add_item(pos_name)
	position_option.selected = 0
	position_option.item_selected.connect(_on_position_changed)

	# 连接按钮信号
	show_simple_btn.pressed.connect(_on_show_simple)
	show_info_btn.pressed.connect(_on_show_info)
	show_success_btn.pressed.connect(_on_show_success)
	show_warning_btn.pressed.connect(_on_show_warning)
	show_error_btn.pressed.connect(_on_show_error)

	# 连接 snackbar 信号
	snackbar.action_pressed.connect(_on_snackbar_action)
	snackbar.dismissed.connect(_on_snackbar_dismissed)

func _on_position_changed(index: int) -> void:
	snackbar.display_position = index
	status_label.text = "位置已切换: %s" % POSITION_NAMES[index]

func _on_show_simple() -> void:
	snackbar.show_message("这是一条普通消息")
	status_label.text = "状态: 显示普通消息"

func _on_show_info() -> void:
	snackbar.show_info("提示：点击按钮查看效果", "了解")
	status_label.text = "状态: 显示信息消息"

func _on_show_success() -> void:
	snackbar.show_success("操作成功完成！")
	status_label.text = "状态: 显示成功消息"

func _on_show_warning() -> void:
	snackbar.show_warning("警告：此操作不可撤销", "继续")
	status_label.text = "状态: 显示警告消息"

func _on_show_error() -> void:
	snackbar.show_error("错误：网络连接失败", "重试")
	status_label.text = "状态: 显示错误消息"

func _on_snackbar_action() -> void:
	_action_count += 1
	status_label.text = "状态: 操作按钮被点击 (共 %d 次)" % _action_count

func _on_snackbar_dismissed() -> void:
	status_label.text = "状态: 消息已关闭"
