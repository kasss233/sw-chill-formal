@tool
class_name MaterialMenuItemConfig
extends Resource

## Material Menu 菜单项配置资源
## 用于在编辑器中配置菜单项

enum ItemType {
	NORMAL,      ## 普通菜单项
	CHECKABLE,   ## 可选中的菜单项
	SEPARATOR    ## 分隔线
}

## 菜单项类型
@export var type: ItemType = ItemType.NORMAL

## 菜单项文字
@export var text: String = ""

## 菜单项图标
@export var icon: Texture2D

## 快捷键文字（如 "Ctrl+C"）
@export var shortcut: String = ""

## 是否选中（仅对 CHECKABLE 类型有效）
@export var is_checked: bool = false

## 是否禁用
@export var is_disabled: bool = false
