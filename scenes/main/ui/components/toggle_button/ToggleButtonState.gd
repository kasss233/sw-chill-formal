@tool
class_name ToggleButtonState
extends Resource

## 多状态按钮的单个状态配置
## 定义每个状态的图标、文字、颜色等属性

## 状态名称 (用于标识，可选)
@export var state_name: String = ""

## 状态图标
@export var icon: Texture2D

## 状态文字标签
@export var label: String = ""

## 图标颜色 (默认白色，保持原色)
@export var icon_color: Color = Color.WHITE

## 文字颜色
@export var text_color: Color = Color.WHITE

## 背景颜色 (设为透明则使用按钮默认背景)
@export var background_color: Color = Color.TRANSPARENT

## 工具提示文本
@export var tooltip: String = ""

## 自定义数据 (可用于存储额外信息)
@export var custom_data: Dictionary = {}

## 创建一个简单的图标状态
static func create_icon_state(tex: Texture2D, color: Color = Color.WHITE) -> ToggleButtonState:
	var state = ToggleButtonState.new()
	state.icon = tex
	state.icon_color = color
	return state

## 创建一个文字状态
static func create_text_state(text: String, text_col: Color = Color.WHITE, bg_col: Color = Color.TRANSPARENT) -> ToggleButtonState:
	var state = ToggleButtonState.new()
	state.label = text
	state.text_color = text_col
	state.background_color = bg_col
	return state

## 创建一个完整状态
static func create_full_state(
	tex: Texture2D,
	text: String,
	icon_col: Color = Color.WHITE,
	text_col: Color = Color.WHITE,
	bg_col: Color = Color.TRANSPARENT,
	tip: String = ""
) -> ToggleButtonState:
	var state = ToggleButtonState.new()
	state.icon = tex
	state.label = text
	state.icon_color = icon_col
	state.text_color = text_col
	state.background_color = bg_col
	state.tooltip = tip
	return state
