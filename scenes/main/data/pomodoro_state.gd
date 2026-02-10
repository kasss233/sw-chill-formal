extends Node

signal work_started
signal work_completed
signal work_paused
signal work_stopped
signal work_continued

func notify_work_started() -> void:
	work_started.emit()

func notify_work_completed() -> void:
	work_completed.emit()

func notify_work_paused() -> void:
	work_paused.emit()

func notify_work_stopped() -> void:
	work_stopped.emit()

func notify_work_continued() -> void:
	work_continued.emit()
