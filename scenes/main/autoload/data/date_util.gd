class_name DateUtil
extends RefCounted

## 统一日期工具类（纯静态方法）
## 所有日期计算集中于此，统一按中国时区（UTC+8）显示与解析，消除各模块重复实现和时区不一致


const CHINA_TIMEZONE_OFFSET_SEC := 8 * 3600


## 中国时区(UTC+8) datetime_dict → UTC Unix 时间戳
## 说明：Godot 的 get_unix_time_from_datetime_dict 不做时区换算，这里手动减去 +8 小时。
static func datetime_dict_cn_to_utc_unix(datetime: Dictionary) -> int:
	if datetime.is_empty():
		return 0
	return int(Time.get_unix_time_from_datetime_dict(datetime)) - CHINA_TIMEZONE_OFFSET_SEC


## UTC Unix 时间戳 → 中国时区(UTC+8) datetime_dict（用于显示）
static func utc_unix_to_datetime_dict_cn(unix_time: int) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(unix_time + CHINA_TIMEZONE_OFFSET_SEC)


# ======================== 基础日期 ========================

## 获取今天的日期 "YYYY-MM-DD"（系统本地时间）
static func get_today_key() -> String:
	var now := utc_unix_to_datetime_dict_cn(int(Time.get_unix_time_from_system()))
	return "%04d-%02d-%02d" % [now["year"], now["month"], now["day"]]


## Unix 时间戳 → "YYYY-MM-DD"（系统本地时间）
static func get_day_key_from_unix(unix_time: int) -> String:
	var dt := utc_unix_to_datetime_dict_cn(unix_time)
	return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]


## "YYYY-MM-DD" → Unix 时间戳（当天 12:00:00，避免夏令时边界问题）
static func date_str_to_unix(date_str: String) -> int:
	var parts := date_str.split("-")
	if parts.size() < 3:
		return 0
	var dt := {
		"year": int(parts[0]),
		"month": int(parts[1]),
		"day": int(parts[2]),
		"hour": 12,
		"minute": 0,
		"second": 0,
	}
	return datetime_dict_cn_to_utc_unix(dt)


## 日期偏移 N 天，返回新日期 "YYYY-MM-DD"
static func offset_date(date_str: String, days: int) -> String:
	var unix := date_str_to_unix(date_str)
	if unix == 0:
		return date_str
	var result_unix := unix + days * 86400
	var dt := Time.get_datetime_dict_from_unix_time(result_unix)
	return "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]


## 获取某月天数（含闰年判断）
static func get_days_in_month(year: int, month: int) -> int:
	if month == 2:
		if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0):
			return 29
		return 28
	if month in [4, 6, 9, 11]:
		return 30
	return 31


## 当前月偏移 N 个月，返回 {"year": int, "month": int}
static func get_month_for_offset(offset: int) -> Dictionary:
	var now := Time.get_datetime_dict_from_system()
	var year: int = now["year"]
	var month: int = int(now["month"]) + offset
	while month < 1:
		year -= 1
		month += 12
	while month > 12:
		year += 1
		month -= 12
	return {"year": year, "month": month}


# ======================== ISO 周 ========================

## 获取当前 ISO 周 "YYYY-Wnn"
static func get_current_week_key() -> String:
	var now := Time.get_datetime_dict_from_system()
	var date_str := "%04d-%02d-%02d" % [now["year"], now["month"], now["day"]]
	return date_to_week_key(date_str)


## "YYYY-MM-DD" → "YYYY-Wnn"（ISO 8601 周算法）
static func date_to_week_key(date_key: String) -> String:
	var unix := Time.get_unix_time_from_datetime_string(date_key + "T12:00:00")
	var dict := Time.get_datetime_dict_from_unix_time(unix)
	var weekday: int = dict["weekday"] # 0=Sunday, 1=Monday...6=Saturday
	var iso_weekday: int = weekday if weekday != 0 else 7 # 1=Mon...7=Sun
	# ISO 规则：本周的周四决定了该周属于哪一年、第几周
	var thursday_unix: int = unix + (4 - iso_weekday) * 86400
	var thursday_dict := Time.get_datetime_dict_from_unix_time(thursday_unix)
	var year: int = thursday_dict["year"]
	var jan1_str := "%04d-01-01T12:00:00" % year
	var jan1_unix: int = Time.get_unix_time_from_datetime_string(jan1_str)
	var day_of_year: int = int((thursday_unix - jan1_unix) / 86400) + 1
	var week_num: int = int((day_of_year - 1) / 7) + 1
	return "%04d-W%02d" % [year, week_num]


## "YYYY-Wnn" + day_of_week(0=Mon..6=Sun) → "YYYY-MM-DD"
static func week_key_to_date(week_key: String, day_of_week: int) -> String:
	var parts := week_key.split("-W")
	if parts.size() != 2:
		return ""
	var year: int = int(parts[0])
	var week: int = int(parts[1])
	# 该年 1 月 1 日
	var jan1_str := "%04d-01-01T12:00:00" % year
	var jan1_unix: int = Time.get_unix_time_from_datetime_string(jan1_str)
	var jan1_dict := Time.get_datetime_dict_from_unix_time(jan1_unix)
	var jan1_weekday: int = jan1_dict["weekday"] # 0=Sunday
	var jan1_iso: int = jan1_weekday if jan1_weekday != 0 else 7 # 1=Mon
	# ISO 第 1 周的周一
	var week1_monday_unix: int
	if jan1_iso <= 4:
		week1_monday_unix = jan1_unix - (jan1_iso - 1) * 86400
	else:
		week1_monday_unix = jan1_unix + (8 - jan1_iso) * 86400
	# 目标日期
	var target_unix: int = week1_monday_unix + ((week - 1) * 7 + day_of_week) * 86400
	var target_dict := Time.get_datetime_dict_from_unix_time(target_unix)
	return "%04d-%02d-%02d" % [target_dict["year"], target_dict["month"], target_dict["day"]]


## 返回某周的周一日期 "YYYY-MM-DD"
static func get_monday_for_week(week_key: String) -> String:
	return week_key_to_date(week_key, 0)


## 周偏移，正确处理跨年
static func offset_week(week_key: String, offset: int) -> String:
	# 先取当前周的周一，偏移 N*7 天，再转回 week_key
	var monday := get_monday_for_week(week_key)
	if monday.is_empty():
		return week_key
	var new_monday := offset_date(monday, offset * 7)
	return date_to_week_key(new_monday)


# ======================== 星期几 ========================

## "YYYY-MM-DD" → 0=Mon..6=Sun
static func get_day_of_week(date_key: String) -> int:
	var unix := Time.get_unix_time_from_datetime_string(date_key + "T12:00:00")
	var dict := Time.get_datetime_dict_from_unix_time(unix)
	var weekday: int = dict["weekday"] # 0=Sunday
	if weekday == 0:
		return 6
	return weekday - 1


## 今天是周几 0=Mon..6=Sun
static func get_today_day_of_week() -> int:
	var dict := Time.get_datetime_dict_from_system()
	var weekday: int = dict["weekday"]
	if weekday == 0:
		return 6
	return weekday - 1


# ======================== 格式化 ========================

## 秒 → "Xh Ym" 或 "Ym"
static func format_duration(seconds: int) -> String:
	var hours: int = seconds / 3600
	var minutes: int = (seconds % 3600) / 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	return "%dm" % minutes
