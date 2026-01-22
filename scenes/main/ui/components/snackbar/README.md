# MaterialSnackbar 使用说明

Material Design 风格的消息提示条组件，从底部弹出显示消息，支持操作按钮和自动消失。

## 快速开始

### 1. 添加到场景

```gdscript
# 在场景中添加 MaterialSnackbar 节点
var snackbar = MaterialSnackbar.new()
add_child(snackbar)

# 或在 tscn 文件中添加
[node name="MaterialSnackbar" type="Control" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
script = ExtResource("path/to/MaterialSnackbar.gd")
```

### 2. 显示消息

```gdscript
# 最简单的用法
snackbar.show_info("操作成功")

# 带操作按钮
snackbar.show_warning("文件已删除", "撤销")

# 自定义持续时间（秒）
snackbar.show_error("网络连接失败", "", 5.0)
```

## API 方法

### 显示消息

#### `show_info(msg: String, action: String = "", dur: float = -1)`
显示信息类型消息（蓝色，带 ℹ 图标）

```gdscript
snackbar.show_info("这是一条信息")
snackbar.show_info("文件已保存", "查看")
```

#### `show_success(msg: String, action: String = "", dur: float = -1)`
显示成功类型消息（绿色，带 ✓ 图标）

```gdscript
snackbar.show_success("上传完成")
snackbar.show_success("任务完成", "详情", 4.0)
```

#### `show_warning(msg: String, action: String = "", dur: float = -1)`
显示警告类型消息（黄色，带 ⚠ 图标）

```gdscript
snackbar.show_warning("存储空间不足")
snackbar.show_warning("请选择有效的图片文件")
```

#### `show_error(msg: String, action: String = "", dur: float = -1)`
显示错误类型消息（红色，带 ✕ 图标）

```gdscript
snackbar.show_error("连接超时")
snackbar.show_error("保存失败", "重试")
```

#### `show_message(msg: String, action: String = "", dur: float = -1, msg_type: int = TYPE_DEFAULT)`
通用显示方法，可指定消息类型

```gdscript
snackbar.show_message("自定义消息", "", 3.0, MaterialSnackbar.TYPE_INFO)
```

**参数说明：**
- `msg`: 消息文本
- `action`: 操作按钮文字（为空则不显示按钮）
- `dur`: 持续时间（秒），-1 使用默认值（3秒），0 表示不自动消失

#### `dismiss()`
立即关闭当前显示的消息

```gdscript
snackbar.dismiss()
```

## 配置属性

### 显示位置 `display_position`

```gdscript
snackbar.display_position = MaterialSnackbar.POS_BOTTOM_CENTER  # 底部居中（默认）
snackbar.display_position = MaterialSnackbar.POS_TOP_CENTER     # 顶部居中
snackbar.display_position = MaterialSnackbar.POS_CENTER         # 屏幕中央
snackbar.display_position = MaterialSnackbar.POS_TOP_LEFT       # 左上角
snackbar.display_position = MaterialSnackbar.POS_TOP_RIGHT      # 右上角
snackbar.display_position = MaterialSnackbar.POS_BOTTOM_LEFT    # 左下角
snackbar.display_position = MaterialSnackbar.POS_BOTTOM_RIGHT   # 右下角
```

### 自动消失时长 `duration`

```gdscript
snackbar.duration = 3.0  # 默认 3 秒
snackbar.duration = 0.0  # 不自动消失
```

### 颜色配置

```gdscript
snackbar.background_color = Color(0.2, 0.2, 0.2, 0.95)  # 背景色
snackbar.text_color = Color.WHITE                        # 文字色
snackbar.action_color = Color(0.35, 0.65, 0.95)         # 操作按钮色
```

### 圆角半径 `corner_radius`

```gdscript
snackbar.corner_radius = 8  # 默认 8
```

## 信号

### `action_pressed`
操作按钮被点击时触发

```gdscript
snackbar.action_pressed.connect(_on_snackbar_action_pressed)

func _on_snackbar_action_pressed():
    print("用户点击了操作按钮")
```

### `dismissed`
消息关闭时触发

```gdscript
snackbar.dismissed.connect(_on_snackbar_dismissed)

func _on_snackbar_dismissed():
    print("Snackbar 已关闭")
```

## 消息类型常量

```gdscript
MaterialSnackbar.TYPE_DEFAULT   # 默认（无图标）
MaterialSnackbar.TYPE_INFO      # 信息（蓝色，ℹ）
MaterialSnackbar.TYPE_SUCCESS   # 成功（绿色，✓）
MaterialSnackbar.TYPE_WARNING   # 警告（黄色，⚠）
MaterialSnackbar.TYPE_ERROR     # 错误（红色，✕）
```

## 使用示例

### 基础用法

```gdscript
extends Control

@onready var snackbar = $MaterialSnackbar

func _ready():
    # 连接信号
    snackbar.action_pressed.connect(_on_action_pressed)

func _on_save_button_pressed():
    # 保存文件
    if save_file():
        snackbar.show_success("文件保存成功")
    else:
        snackbar.show_error("保存失败", "重试")

func _on_action_pressed():
    print("用户点击了操作按钮")
    # 执行相应操作
```

### 带操作按钮

```gdscript
func delete_item():
    var deleted_item = item.duplicate()
    item.queue_free()

    snackbar.show_warning("项目已删除", "撤销")
    snackbar.action_pressed.connect(func():
        # 恢复删除的项目
        add_child(deleted_item)
        snackbar.show_info("已恢复")
    , CONNECT_ONE_SHOT)
```

### 消息队列

Snackbar 自动管理消息队列，多次调用会依次显示：

```gdscript
snackbar.show_info("消息 1")
snackbar.show_info("消息 2")
snackbar.show_info("消息 3")
# 会依次显示，每条消息显示完毕后自动显示下一条
```

### 自定义位置和样式

```gdscript
func _ready():
    snackbar.display_position = MaterialSnackbar.POS_TOP_CENTER
    snackbar.duration = 5.0
    snackbar.background_color = Color(0.1, 0.1, 0.1, 0.98)
    snackbar.corner_radius = 12
```

## 注意事项

1. **节点层级**：MaterialSnackbar 应该添加为全屏覆盖的节点，通常设置 `anchors_preset = 15`（全屏）
2. **鼠标过滤**：建议设置 `mouse_filter = 2`（MOUSE_FILTER_IGNORE）以避免阻挡下层交互
3. **消息队列**：多条消息会自动排队显示，无需手动管理
4. **持续时间**：`dur = -1` 使用默认值，`dur = 0` 不自动消失，`dur > 0` 指定秒数
5. **操作按钮**：只有提供 `action` 参数时才会显示操作按钮

## 完整示例

```gdscript
extends Control

@onready var snackbar = $MaterialSnackbar

func _ready():
    # 配置 snackbar
    snackbar.display_position = MaterialSnackbar.POS_BOTTOM_CENTER
    snackbar.duration = 3.0

    # 连接信号
    snackbar.action_pressed.connect(_on_snackbar_action)
    snackbar.dismissed.connect(_on_snackbar_dismissed)

func _on_upload_button_pressed():
    # 模拟上传
    await get_tree().create_timer(2.0).timeout
    snackbar.show_success("上传完成", "查看")

func _on_delete_button_pressed():
    snackbar.show_warning("确定要删除吗？", "确定")

func _on_network_error():
    snackbar.show_error("网络连接失败", "重试", 5.0)

func _on_snackbar_action():
    print("用户点击了操作按钮")

func _on_snackbar_dismissed():
    print("Snackbar 已关闭")
```
