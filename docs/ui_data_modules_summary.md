# UI 与 Data 模块总览

本文档基于当前代码实现，汇总 `scenes/main/ui` 主模块与 `scenes/main/autoload/data` 数据单例/数据模型的职责、关键接口与对应关系。

## 1. 总体架构

- 数据流：Data Autoload（State）负责数据与信号，UI 模块负责展示与交互，修改数据统一走 State API。
- 主要协作方式：UI 监听 State 信号刷新界面；UI 操作调用 State 方法；State 持久化并广播变更。
- 竖屏总控：`ui_portrait.gd` 统一处理模块互斥、对话模式、更多菜单、返回键与键盘避让。

## 2. UI 模块与对应 Data 映射

| UI 模块 | 脚本 | 主要对应 Data/Autoload | 核心功能 |
|---|---|---|---|
| UI 主控制器 | `ui.gd` / `ui_portrait.gd` | ChatState、各业务模块 | 全局模块切换、对话模式、快捷入口、输入/返回键处理 |
| 音乐模块（桌面/横屏） | `music_module/music_module.gd` | MusicState（`autoload/audio_player`）、AudioPlayer | 播放控制、歌单管理、导入音乐、播放模式切换 |
| 音乐模块（移动） | `music_module/music_module_mobile.gd` | MusicState、AudioPlayer | 迷你播放器、面板展开、播放进度/时间显示 |
| 任务模块 | `task_module_new/task_module_new.gd` | TaskState | 任务增删改、完成状态、拖拽重排、分隔显示 |
| 便签模块 | `note_module/note_module.gd` | StickyNoteState、LayerManager | 便签创建/关闭、数量限制、图层置顶 |
| 笔记本模块（移动） | `notebook_mobile_module/note_book_mobile.gd` | NoteState | 笔记 CRUD、分类筛选、搜索、编辑与保存、Agent 打开/写入 |
| 输入框 | `input_box/input_box.gd` | ChatState | 单/多行输入、提交与停止、附件管理（最多 2 个） |
| 对话框 | `dialogue_box/dialogue_box.gd` | ChatState | 流式显示、函数执行状态、自动隐藏、按钮交互 |
| 设置模块 | `setting/setting.gd` | SettingState | 时间/天气/雨雪/雾、MSAA/SSAA、摄像头模式 |
| 认证面板 | `setting/auth_panel.gd` | AuthState | 登录/注册/登出、服务端地址保存 |
| 番茄钟模块 | `pomodoro_technique_module/pomodoro_technique_module.gd` | PomodoroState（子节点实际驱动） | 番茄钟面板显示/隐藏与入口控制 |
| 成就模块 | `achievement_module/achievement_module.gd` | AchievementState、LevelState（奖励联动） | 每日任务/成就双标签、完成/领取奖励 |
| 等级条 | `level_bar/level_bar.gd` | LevelState | 等级进度、经验提示与来源展示 |
| 角色交互 | `character_interactor/character_interactor.gd` | CharacterInteractorState | 3 次点击触发交互事件 |
| 日历模块 | `calendar_module/calendar_module.gd` | HabitState（子面板使用）、ChatState | Tab 切换、请求 AI 生成周课表/反思 |
| 房间装饰模块 | `room_decor_module/room_decor_module.gd` | RoomDecorState、LevelState | 装饰物展示、分类分组、选择/取消、解锁态展示 |

## 3. UI 主模块详细说明

### 3.1 `ui.gd`

- 基础 UI 根节点，负责测试面板快捷入口。
- `toggle_test_panel()` / `show_test_panel()` / `hide_test_panel()`：控制测试面板显示。
- `_input(event)` 中处理 `F12` 切换测试面板。

### 3.2 `ui_portrait.gd`

- 竖屏总协调器，继承 `UI`。
- `_register_modules()` + `_register()` 建立模块注册表 `_module_registry`。
- `_on_module_toggle_changed()` / `_close_other_modules()` 实现模块互斥打开。
- 监听 `_music_module_mobile.panel.visibility_changed`，音乐面板展开时关闭其他模块。
- `_enter_dialogue_mode()` / `_exit_dialogue_mode()` 切换对话模式。
- 监听 `ChatState.response_started` 自动进入对话模式。
- `_setup_more_menu()` + `_on_more_menu_item_pressed()` 提供“成就/日历/房间装饰/环境设置”快捷入口。
- `_handle_back()` 和 `_unhandled_input()` 处理返回键、空白点击关闭当前模块。
- `_process()` 中根据 `DisplayServer.virtual_keyboard_get_height()` 做移动端键盘避让。

### 3.3 `music_module/music_module.gd`

- 桌面/横屏音乐主模块，核心流程：初始化管理器、连接 MusicState、加载首曲。
- ` _setup_initial_music()`：导入内置音乐与用户导入音乐。
- `_setup_list_menu()` / `_setup_add_menu()`：歌单切换与新增入口。
- `_setup_delete_dialog()` / `_setup_add_playlist_dialog()`：删除/新增歌单对话框。
- `_on_state_playlist_created/deleted/track_added/track_removed/...`：响应 MusicState 信号刷新列表。
- `_on_last_button_pressed()` / `_on_next_button_pressed()` / `_on_mode_button_pressed()`：上一首/下一首/播放模式。
- `_on_music_options_requested()` / `_on_music_option_changed()` / `_on_music_category_changed()`：曲目选项与分类变更。
- `show_module()` / `hide_module()`：模块面板显示控制。

### 3.4 `music_module/music_module_mobile.gd`

- 移动音乐模块，包含迷你播放器和展开面板。
- `_setup_mini_panel()` / `_toggle_panel()`：迷你面板交互。
- `_update_time()` / `_update_progress()`：更新时间与进度显示。
- `_connect_music_state()`：监听 MusicState 播放状态、曲目、播放列表变化。
- `_setup_initial_music()`、`_setup_list_menu()`、`_setup_add_menu()`：与桌面模块同类能力。
- `show_module()` / `hide_module()`：展开面板显示控制。

### 3.5 `task_module_new/task_module_new.gd`

- 任务 UI 主模块，对接 TaskState 的全量任务生命周期。
- `signal task_completed(task_id, task_title)`：向外广播任务完成事件。
- `_on_state_task_added/removed/updated/state_changed/tasks_reordered/data_loaded()`：响应状态变更。
- `_create_task_item()` / `_connect_task_item_signals()`：创建并绑定任务条目事件。
- `_on_task_item_completed_changed()` / `_on_task_item_content_changed()` / `_on_task_item_due_time_changed()`：写回 TaskState。
- `_on_v_box_container_reordered()` + `reorder_by_drag(...)` 协同实现拖拽排序。
- `_update_separator_position()` / `_on_separator_toggled()`：已完成分组与可见性。

### 3.6 `note_module/note_module.gd`

- 便签（Sticky Note）模块。
- 监听 `StickyNoteState.sticky_note_requested`，调用 `_create_note_with_text()` 创建便签。
- `_create_note_internal()`：实例化 Note 节点并绑定关闭回调。
- 通过 `StickyNoteState.can_create()` 限制上限；创建/关闭时通知 `notify_created()` / `notify_closed()`。
- `take_note(text)` 提供外部调用入口。
- 使用 `LayerManager.bring_to_front(canvas_layer)` 保证便签在顶层。

### 3.7 `notebook_mobile_module/note_book_mobile.gd`

- 移动端笔记本模块，包含列表页与编辑页。
- `_get_filtered_notes()`：按搜索词 + 分类过滤。
- `_refresh_note_list()` / `_refresh_categories()`：刷新笔记列表与分类标签。
- `_open_page(note_id)` / `_close_page()` / `_save_current_page()`：打开编辑页、关闭与保存。
- `_setup_category_submenu()` / `_setup_delete_category_submenu()` / `_setup_dialogs()`：分类和删除相关菜单/对话框。
- `_create_new_note()` / `_on_note_item_pressed()`：新建与打开笔记。
- 响应 `NoteState` 信号：`note_added/removed/updated/data_loaded/category_added/category_removed`。
- 响应 Agent 信号：`_on_agent_note_created()`、`_on_agent_content_written()`、`_on_agent_open_note_requested()`、`_on_agent_close_note_requested()`。

### 3.8 `input_box/input_box.gd`

- AI 输入模块。
- 公开信号：`text_submitted`、`text_changed`、`generation_stopped`。
- `_on_line_edit_text_changed()` 与 `_on_text_edit_text_changed()`：文本变化驱动状态。
- `_should_switch_to_multiline()` / `_switch_to_multiline_mode()` / `_switch_to_singleline_mode()`：单行与多行模式切换。
- `_handle_submit()` / `_handle_stop()`：提交文本与停止生成。
- 附件流程：`_open_image_picker()`、`_on_file_selected()`、`_on_chip1_deleted()`、`_on_chip2_deleted()`、`clear_attachments()`。
- 监听 `ChatState.chat_status_changed/input_text_requested/input_clear_requested` 实现联动。

### 3.9 `dialogue_box/dialogue_box.gd`

- AI 输出展示模块。
- 公开信号：`dialogue_started`、`dialogue_finished`、`dialogue_stopped`、`button_pressed`。
- `show_module()` / `hide_module()`：对话区域显示控制。
- `start_dialogue()` / `append_text()` / `set_text()` / `skip_to_end()` / `stop_dialogue()`：文本显示控制。
- `_on_response_started()` / `_on_response_text_delta()` / `_on_response_completed()` / `_on_response_error()`：监听 ChatState 响应生命周期。
- `_on_function_call_started()` / `_on_function_call_completed()`：函数执行状态展示。
- `_start_auto_hide_timer()` / `_on_auto_hide_timeout()`：自动隐藏。
- `_on_frosted_panel_gui_input()` + `_on_long_press_triggered()`：长按交互。

### 3.10 `setting/setting.gd`（EnvSetter）

- 环境设置模块。
- `_connect_state_signals()`：监听 SettingState 信号，实现状态回填。
- `_sync_all_controls_from_state()` / `_init_dropdowns_from_state()`：初始化 UI 控件状态。
- `_on_time_button_state_changed()` / `_on_weather_button_state_changed()`：时间、天气写回。
- `_on_rain_material_slider_value_changed()` / `_on_snow_material_slider_value_changed()`：雨雪参数写回。
- `_on_msaa_changed()` / `_on_ssaa_changed()`：抗锯齿参数设置。
- `_on_camera_drop_down_selection_changed()` / `_on_fog_button_state_changed()`：摄像头与雾效设置。
- `show_module()` / `hide_module()` 通过 `GuiTransitions` 控制面板显示。

### 3.11 `setting/auth_panel.gd`

- 认证 UI。
- `_create_login_dialog()` / `_create_register_dialog()` / `_create_logout_dialog()`：构建认证相关对话框。
- `_on_login_confirm()` / `_on_register_confirm()` / `_on_logout_confirmed()`：调用 AuthState。
- `_on_login_succeeded/failed()`、`_on_register_succeeded/failed()`、`_on_logout_completed()`：结果处理。
- `_on_server_url_focus_exited()` / `_save_server_url()`：服务地址持久化。

### 3.12 `pomodoro_technique_module/pomodoro_technique_module.gd`

- 番茄钟模块外层容器。
- `_on_pomodoro_button_state_changed()`：切换模块显示。
- `show_module()` / `hide_module()`：调用 `GuiTransitions` 并同步按钮状态。
- 具体计时逻辑由子节点与 PomodoroState 信号驱动。

### 3.13 `achievement_module/achievement_module.gd`

- 每日任务/成就模块。
- `signal tab_changed(tab_name)`：Tab 切换通知。
- `show_daily_task_tab()` / `show_achievement_tab()` / `_switch_tab()`：双 Tab 展示。
- `_create_item_node()` / `_remove_item_node()` / `_update_item()`：条目增删改。
- `_on_item_completed_changed()` / `_on_item_delete_requested()` / `_on_item_claim_requested()`：转发到 AchievementState。
- 监听 AchievementState 全部信号（daily/achievement added/removed/state_updated/completed/reward_claimed + data_loaded）。
- `show_module()` / `hide_module()`：模块开关。

### 3.14 `level_bar/level_bar.gd`

- 等级与经验展示模块。
- `_on_level_state_changed(data)`：接收状态更新。
- `update_bar()`：更新等级、经验、进度条。
- `_handle_xp_gain_message()` / `_show_xp_message()`：经验变动提示文本与动画。

### 3.15 `character_interactor/character_interactor.gd`

- 简洁交互模块。
- `_on_button_pressed()`：累计点击次数，达到阈值后触发 `CharacterInteractorState.notify_interacted()`。

### 3.16 `calendar_module/calendar_module.gd`

- 日历容器模块，主职责是视图切换与 AI 请求转发。
- `_on_tab_changed(index)`：切换 Calendar/WeekSchedule/HabitLibrary/Summary 视图。
- `_on_date_selected(year, month, day)`：日期选择回调（当前用于日志输出）。
- `_on_ai_schedule_requested(week_key)`：调用 `ChatState.agent_set_input_text(...)` 请求生成课表。
- `_on_generate_reflection(week_key)`：调用 `ChatState.agent_set_input_text(...)` 请求生成反思。

### 3.17 `room_decor_module/room_decor_module.gd`

- 房间装饰模块。
- `signal item_selected(item_id, item_data)`：对外通知选中项。
- `add_decor_item()` / `select_decor_item()`：外部调用入口。
- `_render_all()` / `_create_item_node()`：按分类构建 UI。
- `_on_item_select_requested()` / `_on_item_deselect_requested()`：操作转发到 RoomDecorState。
- `_on_state_item_added/removed/updated()` / `_on_state_data_loaded()`：响应数据更新。
- `_refresh_header()` / `_refresh_category_count()` / `_try_remove_empty_category_section()`：统计与空分类维护。
- `show_module()` / `hide_module()`：模块显隐。

## 4. Data 模块详细说明

> 说明：本节包含 `scenes/main/autoload/data` 下所有脚本，分为“状态单例”“数据模型/工具”。

### 4.1 状态单例（Node）

#### `achievement_state.gd`
- 负责每日任务与成就数据。
- 核心信号：
  - 每日任务：`daily_task_added/removed/state_updated/completed/reward_claimed`
  - 成就：`achievement_added/removed/state_updated/completed/reward_claimed`
  - `data_loaded`
- 核心方法：
  - 查询：`get_daily_tasks()`、`get_achievements()`、`get_daily_task_count()`、`get_achievement_count()`
  - 操作：`add_daily_task*`、`add_achievement*`、`set_*_progress()`、`set_*_completed()`、`claim_*()`
  - 持久化/同步：`load_data()`、`export_data()`、`import_data()`、`import_sync_data()`
  - 自动逻辑：`_setup_daily_check_timer()`、`_refresh_daily_tasks()`、`_ensure_builtin_*()`

#### `api_client.gd`
- 统一 API 请求客户端。
- 核心信号：`auth_required`。
- 核心方法：`api_get/post/put/delete()`、`_request()`、`_ensure_valid_token()`、`_parse_response()`。

#### `auth_state.gd`
- 用户认证状态。
- 核心信号：`login_succeeded/failed`、`register_succeeded/failed`、`logout_completed`、`token_refreshed/token_refresh_failed`、`auth_state_changed`。
- 核心方法：`register()`、`login()`、`logout()`、`refresh_access_token()`、`set_base_url()`，以及 `is_logged_in()`/`get_*()` 查询。
- 负责本地认证信息保存与刷新定时。

#### `character_interactor_state.gd`
- 角色交互事件中枢。
- 核心信号：`character_interacted`。
- 核心方法：`notify_interacted()`。

#### `chat_state.gd`
- 聊天状态中枢。
- 核心信号：
  - 状态：`chat_status_changed`
  - 响应：`response_started/response_text_delta/response_text_set/response_completed/response_cleared/response_error`
  - 函数调用：`function_call_started/function_call_completed`
  - 输入：`text_submitted`、`generation_stop_requested`、`input_text_requested`、`input_clear_requested`
- 核心方法：`start_response()`、`append_response_text()`、`complete_response()`、`fail_response()`、`submit_text()`、`request_stop_generation()`。
- Agent 相关方法：`agent_get_chat_status()`、`agent_set_input_text()`、`agent_clear_input()`。

#### `event_tracker.gd`
- 行为事件追踪与上报。
- 核心方法：`track_task_start()`、`track_task_pause()`、`track_ai_suggestion_rejected()`、`flush()`。
- 通过 `_connect_signals()` 订阅多模块事件，`_enqueue()` 入队，`_do_flush()` 发送。

#### `habit_state.gd`
- 习惯系统主状态。
- 核心信号：`habit_added/removed/updated`、`time_slot_template_changed`、`schedule_entry_added/removed/updated/cleared`、`execution_updated`、`agent_schedule_generated`、`data_loaded`。
- 核心方法：
  - 查询：`get_all_habits()`、`get_week_schedule()`、`get_day_schedule()`、`get_week_stats()` 等
  - 习惯管理：`add_habit()`、`update_habit()`、`remove_habit()`、`set_habit_active()`
  - 时间段模板：`add/update/remove/reorder_time_slot_template*`
  - 排期：`add/remove/clear/copy/apply_schedule_batch`
  - 执行：`set_execution_status()`、`ensure_daily_records()`
  - Agent：`agent_add_habit()`、`agent_generate_schedule()`、`agent_get_habit_stats()` 等
  - 持久化/同步：`load_data()`、`export_data()`、`import_data()`、`import_sync_data()`

#### `layer_manager.gd`
- UI 图层管理。
- 核心方法：`register()`、`bring_to_front()`、`_compact()`。

#### `level_state.gd`
- 等级与经验状态。
- 核心信号：`level_up`、`level_state_changed`、`data_loaded`。
- 核心方法：`add_xp()`、`reset_level_and_xp()`、`get_xp_for_next_level()`、`get_progress()`、`save_data()`、`load_data()`、`export_data()`、`import_sync_data()`。

#### `note_state.gd`
- 笔记主状态。
- 核心信号：`note_added/removed/updated`、`category_added/removed`、`data_loaded`。
- Agent 相关信号：`agent_note_created`、`agent_content_written`、`agent_open_note_requested`、`agent_close_note_requested`。
- 核心方法：
  - 查询：`get_all_notes()`、`get_note_by_id()`、`get_notes_by_category()`、`search_notes()`
  - 操作：`add_note()`、`remove_note()`、`update_note*()`、`toggle_note_category()`、`set_note_category()`
  - Agent：`agent_create_note()`、`agent_write_content()`、`agent_open_note()`、`agent_close_note()`
  - 分类：`add_category()`、`remove_category()`、`has_category()`
  - 同步：`sync_create_note()`、`sync_update_note()`、`sync_remove_note()`、`sync_replace_all()`

#### `pomodoro_state.gd`
- 番茄钟状态机。
- 核心信号：`pomodoro_started`、`work_phase_*`、`rest_phase_*`、`tick`、`loop_completed`、`all_completed`、`config_changed`、`data_loaded`。
- 核心方法：`start_pomodoro()`、`toggle_pause()`、`stop()`、`set_work_duration()`、`set_rest_duration()`、`get_status()`、`get_progress()`。
- Agent 方法：`agent_start_pomodoro()`、`agent_stop()`、`agent_toggle_pause()`、`agent_get_status()` 等。

#### `room_decor_state.gd`
- 房间装饰数据状态。
- 核心信号：`room_decor_added/removed/updated/state_changed`、`room_decor_selected`、`room_decor_category_unselected`、`data_loaded`。
- 核心方法：
  - 查询：`get_all_items()`、`get_selected_item_ids_by_category()`
  - 操作：`add_item()`、`remove_item()`、`select_item()`、`deselect_item()`、`clear_all_items()`、`clear_all_categories()`
  - Agent：`agent_add_room_decor_item()`、`agent_select_room_decor_item()`、`agent_load_room_decor_from_resource()`
  - 持久化/同步：`load_data()`、`export_data()`、`import_sync_data()`

#### `setting_state.gd`
- 环境/渲染设置状态。
- 核心信号：`env_time_changed`、`env_weather_changed`、`rain_changed`、`snow_changed`、`camera_changed`、`fog_changed`。
- 核心方法：
  - 设置：`set_time()`、`set_weather()`、`set_rain_amount()`、`set_snow_amount()`、`set_msaa()`、`set_ssaa()`、`set_camera()`、`set_fog()`
  - 查询：`get_time_mode()`、`get_weather_mode()`、`get_rain_amount()`、`get_snow_amount()`、`get_camera_mode()`、`get_msaa()`、`get_ssaa()`、`get_fog_state()`
  - 持久化：`_save_settings()`、`_queue_save_settings()`、`_load_settings()`

#### `stats_state.gd`
- 统计记录状态。
- 核心信号：`record_added`、`record_removed`、`data_loaded`。
- 核心方法：`add_record()`、`remove_record()`、`get_records()`、`get_records_in_range()`。
- 统计辅助：`get_day_total()`、`get_week_daily_totals()`、`get_month_daily_totals()`、`get_year_monthly_totals()`。
- 聚焦番茄钟统计：`get_today_focus_seconds()`、`get_week_focus_totals()`。

#### `sticky_note_state.gd`
- 便签计数与请求状态。
- 核心信号：`sticky_note_requested(text)`、`count_changed(count)`。
- 核心方法：`get_count()`、`can_create()`、`notify_created()`、`notify_closed()`、`agent_take_note(text)`。

#### `sync_state.gd`
- 数据同步状态。
- 核心信号：`sync_started`、`sync_completed(success, summary)`、`sync_error(message)`、`device_registered(device_id)`。
- 核心方法：
  - 同步流程：`register_device()`、`_do_push()`、`_do_pull()`、`do_full_sync()`、`_do_sync_cycle()`、`trigger_sync()`
  - 变更处理：`_record_change()`、`_merge_change()`、`_apply_remote_changes()`
  - 定时/失败：`_start_auto_sync()`、`_stop_auto_sync()`、`_handle_sync_failure()`
  - 持久化：`_save_sync_data()`、`_load_sync_data()`、`_save_change_queue()`、`_load_change_queue()`

#### `task_state.gd`
- 任务主状态。
- 核心信号：`task_added/removed/updated/state_changed`、`task_completed`、`tasks_reordered`、`task_deadline_reached`、`task_deadline_warning`、`data_loaded`。
- 核心方法：
  - 查询：`get_all_tasks()`、`get_incomplete_tasks()`、`get_completed_tasks()`、`get_overdue_tasks()`
  - 操作：`add_task()`、`remove_task()`、`update_task_title()`、`set_task_completed()`、`set_task_due_time()`
  - 排序：`reorder_task()`、`reorder_by_drag()`、`_update_orders()`
  - 同步：`sync_create_task()`、`sync_update_task()`、`sync_remove_task()`、`sync_replace_all()`
  - 持久化：`load_data()`、`export_data()`、`import_data()`

### 4.2 数据模型/工具类（RefCounted）

#### `date_util.gd`
- `class_name DateUtil`，日期工具类。

#### `habit_data.gd`
- `class_name HabitData`，习惯数据模型。
- 核心方法：`to_dict()`、`get_period_name()`、`get_frequency_name()`。

#### `id_mapping.gd`
- `class_name IdMapping`，本地/服务端 ID 映射。
- 核心方法：`set_mapping()`、`get_server_id()`、`get_local_key()`、`to_dict()`、`load_from_dict()`、`save_to_file()`、`load_from_file()`。

#### `note_data.gd`
- `class_name NoteData`，笔记数据模型。
- 核心方法：`get_display_title()`、`get_content_preview()`、`get_formatted_time()`、`get_word_count()`、`to_dict()`。

#### `room_decor_data.gd`
- `class_name RoomDecorData`，房间装饰项数据模型。
- 核心方法：`to_dict()`。

#### `stats_record.gd`
- `class_name StatsRecord`，统计记录模型。
- 核心方法：`to_dict()`。

#### `task_data.gd`
- `class_name TaskData`，任务数据模型。
- 核心方法：`get_formatted_due_time()`、`to_dict()`。

## 5. 模块关系补充说明

- 音乐相关状态 `MusicState` 不在 `autoload/data` 目录，而在 `autoload/audio_player` 体系中；UI 音乐模块依然遵循“State 驱动 UI”的模式。
- `calendar_module.gd` 主要做容器与事件转发；课表/习惯库/统计的具体业务在其子面板中（对应 HabitState）。
- `note_module.gd`（便签）与 `notebook_mobile_module`（笔记本）分别对应 `StickyNoteState` 与 `NoteState`，是两套用途不同的笔记形态。

## 6. 建议的文档维护方式

- 新增 UI 模块时，在“2. 映射表”和“3. UI 模块详细说明”同步增加条目。
- 新增 State 信号/API 时，在“4.1 状态单例”同步补充，避免 UI 调用出现文档漂移。
- 若模块迁移目录（例如从 `autoload/data` 移至其他 autoload 子目录），在“5. 模块关系补充说明”记录特殊位置。
