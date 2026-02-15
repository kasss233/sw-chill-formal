extends MarginContainer

## 番茄钟 UI 组件（纯展示 + 交互）
## 所有业务逻辑由 PomodoroState 单例管理，本组件仅监听信号驱动显示

@onready var hh = %running/VBoxContainer/hh_mm_dd/hh
@onready var mm = %running/VBoxContainer/hh_mm_dd/mm
@onready var ss = %running/VBoxContainer/hh_mm_dd/ss

@onready var work_progress_bar = $FrostedPanel/MaterialProgressIndicator
@onready var rest_progress_bar = $FrostedPanel/MaterialProgressIndicator2
var _active_bar: Control  # 当前活跃的进度条引用
var _pending_swap: StringName = &""   # 待执行的切换: &"work" / &"rest" / &""
var _is_transitioning: bool = false   # 是否正在等待归零动画完成

@onready var loop_info = %idle/VBoxContainer/loop
@onready var work_info = %idle/VBoxContainer/HBoxContainer/work
@onready var rest_info = %idle/VBoxContainer/HBoxContainer/rest

@onready var loop_progress_label = %running/VBoxContainer/numbers
@onready var status_label = %running/VBoxContainer/status

@onready var idle_view = %idle
@onready var running_view = %running


func _ready() -> void:
	_idle_view()
	# 连接 PomodoroState 信号
	PomodoroState.pomodoro_started.connect(_on_pomodoro_started)
	PomodoroState.work_phase_stopped.connect(_on_pomodoro_stopped)
	PomodoroState.rest_phase_stopped.connect(_on_pomodoro_stopped)
	PomodoroState.work_phase_paused.connect(_on_pomodoro_paused)
	PomodoroState.rest_phase_paused.connect(_on_pomodoro_paused)
	PomodoroState.work_phase_continued.connect(_on_pomodoro_continued)
	PomodoroState.rest_phase_continued.connect(_on_pomodoro_continued)
	PomodoroState.tick.connect(_on_tick)
	PomodoroState.work_phase_started.connect(_on_work_phase_started)
	PomodoroState.rest_phase_started.connect(_on_rest_phase_started)
	PomodoroState.loop_completed.connect(_on_loop_completed)
	PomodoroState.all_completed.connect(_on_all_completed)
	PomodoroState.config_changed.connect(_on_config_changed)
	PomodoroState.data_loaded.connect(_on_data_loaded)
	# 防止 State 先启动而 UI 后加载
	_sync_from_state()


# ======================== 视图切换 ========================

func _running_view() -> void:
	idle_view.visible = false
	running_view.visible = true


func _idle_view() -> void:
	idle_view.visible = true
	running_view.visible = false


# ======================== 进度条轮换 ========================

func _swap_to_work() -> void:
	_active_bar = work_progress_bar
	var parent = work_progress_bar.get_parent()
	parent.move_child(work_progress_bar, 1)  # 工作环绘制在上层
	var status = PomodoroState.get_status()
	if status.current_loop >= status.total_loops:
		# 最后一次工作，不显示休息进度条
		rest_progress_bar.visible = false
	else:
		rest_progress_bar.visible = true
		rest_progress_bar.set_progress_value(1.0)  # 休息环满置


func _swap_to_rest() -> void:
	_active_bar = rest_progress_bar
	rest_progress_bar.visible = true
	var parent = rest_progress_bar.get_parent()
	parent.move_child(rest_progress_bar, 1)  # 休息环绘制在上层
	work_progress_bar.set_progress_immediate(1.0)  # 工作环满置


func _reset_progress_bars() -> void:
	work_progress_bar.set_progress_value(0.0)
	rest_progress_bar.set_progress_value(0.0)
	rest_progress_bar.visible = true


# ======================== 进度条切换过渡 ========================

func _begin_swap_transition(target: StringName) -> void:
	if not _active_bar:
		_execute_swap(target)
		return
	var has_running_tween = (_active_bar._progress_tween
			and _active_bar._progress_tween.is_valid()
			and _active_bar._progress_tween.is_running())
	if not has_running_tween:
		_execute_swap(target)
		return
	_pending_swap = target
	_is_transitioning = true
	if not _active_bar.animation_finished.is_connected(_on_active_bar_animation_finished):
		_active_bar.animation_finished.connect(_on_active_bar_animation_finished, CONNECT_ONE_SHOT)


func _on_active_bar_animation_finished() -> void:
	if not _is_transitioning or _pending_swap == &"":
		return
	var target = _pending_swap
	_pending_swap = &""
	_is_transitioning = false
	_execute_swap(target)


func _execute_swap(target: StringName) -> void:
	match target:
		&"work": _swap_to_work()
		&"rest": _swap_to_rest()
	if _active_bar and PomodoroState.is_active():
		_active_bar.set_progress_value(PomodoroState.get_status().progress)


func _cancel_swap_transition() -> void:
	if _is_transitioning and _active_bar:
		if _active_bar.animation_finished.is_connected(_on_active_bar_animation_finished):
			_active_bar.animation_finished.disconnect(_on_active_bar_animation_finished)
	_pending_swap = &""
	_is_transitioning = false


# ======================== 显示更新 ========================

func _update_display(remaining: int) -> void:
	var hours = remaining / 3600
	var minutes = (remaining % 3600) / 60
	var seconds = remaining % 60
	hh.text = "%02d" % hours
	mm.text = "%02d" % minutes
	ss.text = "%02d" % seconds


func _update_loop_display(current: int, total: int) -> void:
	if loop_progress_label:
		loop_progress_label.text = "%d/%d" % [current, total]


func _update_status_display(is_work: bool) -> void:
	if status_label:
		status_label.text = "工作中" if is_work else "休息中"


# ======================== PomodoroState 信号处理 ========================

func _on_pomodoro_started(_data: Dictionary) -> void:
	_running_view()
	# 启动时同步一次循环显示，避免等待 loop_completed 才刷新
	var status = PomodoroState.get_status()
	_update_loop_display(status.current_loop, status.total_loops)


func _on_pomodoro_stopped() -> void:
	_cancel_swap_transition()
	_idle_view()
	_reset_progress_bars()


func _on_tick(remaining: int, total: int, progress: float, is_work: bool) -> void:
	_update_display(remaining)
	_update_status_display(is_work)
	if _is_transitioning:
		return
	if _active_bar:
		_active_bar.set_progress_value(progress)


func _on_work_phase_started() -> void:
	_update_status_display(true)
	_begin_swap_transition(&"work")


func _on_rest_phase_started() -> void:
	_update_status_display(false)
	_begin_swap_transition(&"rest")


func _on_loop_completed(current: int, total: int) -> void:
	_update_loop_display(current, total)


func _on_all_completed() -> void:
	_cancel_swap_transition()
	_idle_view()
	_reset_progress_bars()


func _on_pomodoro_paused() -> void:
	pass


func _on_pomodoro_continued() -> void:
	pass


func _on_config_changed(work_dur: int, rest_dur: int) -> void:
	if not PomodoroState.is_active():
		work_info.times = work_dur
		work_info.flush_times_text()
		rest_info.times = rest_dur
		rest_info.flush_times_text()


func _on_data_loaded() -> void:
	_sync_from_state()


# ======================== 状态同步 ========================

func _sync_from_state() -> void:
	if PomodoroState.is_active():
		_running_view()
		var status = PomodoroState.get_status()
		_update_display(status.remaining_seconds)
		_update_loop_display(status.current_loop, status.total_loops)
		_update_status_display(status.is_work_mode)
		if status.is_work_mode:
			_swap_to_work()
		else:
			_swap_to_rest()
		_active_bar.set_progress_value(status.progress)
	else:
		_idle_view()
		_reset_progress_bars()
		work_info.times = PomodoroState.work_duration
		work_info.flush_times_text()
		rest_info.times = PomodoroState.rest_duration
		rest_info.flush_times_text()


# ======================== 按钮回调（调用 PomodoroState）========================

func _on_start_button_pressed() -> void:
	PomodoroState.start_pomodoro(work_info.times, rest_info.times, loop_info.times)


func _on_pause_button_state_changed(_old_state: int, _new_state: int) -> void:
	PomodoroState.toggle_pause()


func _on_stop_button_pressed() -> void:
	PomodoroState.stop()
