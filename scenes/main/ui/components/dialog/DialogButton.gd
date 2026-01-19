@tool
class_name DialogButton
extends Resource

## 对话框按钮配置资源
## 用于在检查器中配置对话框按钮

enum ActionType {
	CUSTOM,      ## 自定义按钮（触发 button_pressed 信号）
	CONFIRM,     ## 确认按钮（触发 dialog_confirmed 信号）
	CANCEL       ## 取消按钮（触发 dialog_cancelled 信号）
}

## 按钮文本
@export var text: String = "按钮"

## 按钮图标（可选）
@export var icon: Texture2D

## 按钮操作类型
@export var action_type: ActionType = ActionType.CUSTOM

## 点击后是否关闭对话框
@export var close_on_click: bool = true

## 按钮背景颜色（可选，留空使用默认）
@export var background_color: Color = Color.TRANSPARENT

## 按钮尺寸
@export_enum("SMALL32", "STANDARD36", "MEDIUM40", "LARGE48", "EXTRA_LARGE56") var button_size: int = 1  # STANDARD36
