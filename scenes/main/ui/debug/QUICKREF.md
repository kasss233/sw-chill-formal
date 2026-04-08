# 测试面板快速参考

## 快捷键
- **F12** - 打开/关闭测试面板
- **ESC** - 关闭测试面板

## 代码调用
```gdscript
# 在可以访问UI实例的地方
ui.toggle_test_panel()  # 切换
ui.show_test_panel()    # 显示
ui.hide_test_panel()    # 隐藏
```

## 当前功能
- ✅ TaskModule Agent API 测试
  - 添加任务
  - 更新标题(带打字效果)
  - 标记完成/未完成
  - 删除任务
  - 获取任务信息
  - 获取所有任务
- ✅ Memory 调试
  - 显示/隐藏 Memory 模块（LayerManager 路由）
  - 添加/更新/删除节点（MemoryState Agent API）
  - 连接节点（agent_connect_memory_nodes）
  - 切换节点连 Hub 状态（connected 字段）
  - 读取 editor/immutable 图数据

## 集成位置
测试面板已集成到 `scenes/main/ui/ui.tscn` 中，默认隐藏。

## 拓展新模块测试
1. 创建测试页脚本和场景
2. 添加到 `test_panel.tscn` 的 TabContainer
3. 在 `test_panel.gd` 的 `_initialize_test_panels()` 中添加初始化代码

详细说明请查看 README.md
