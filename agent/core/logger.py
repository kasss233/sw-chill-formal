"""
统一日志机制
支持级别：trace < debug < info < warning < error
"""
from __future__ import annotations

import logging
import sys
from typing import Optional

# 自定义 TRACE 级别（低于 DEBUG）
TRACE_LEVEL = 5
logging.addLevelName(TRACE_LEVEL, "TRACE")


def trace(self, message: str, *args, **kwargs) -> None:
    if self.isEnabledFor(TRACE_LEVEL):
        self._log(TRACE_LEVEL, message, args, **kwargs)


logging.Logger.trace = trace  # type: ignore[attr-defined]

# 默认格式
_DEFAULT_FORMAT = (
    "%(asctime)s | %(levelname)-7s | %(name)s | %(message)s"
)
_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

# 全局默认级别（可通过 setup_logging 覆盖）
_default_level = logging.INFO


def setup_logging(
    level: str = "INFO",
    format_string: Optional[str] = None,
    stream=None,
) -> None:
    """
    配置根 logger，影响所有通过 get_logger 得到的 logger。

    Args:
        level: "trace" | "debug" | "info" | "warning" | "error"
        format_string: 日志格式，默认带时间、级别、name、消息
        stream: 输出流，默认 sys.stderr
    """
    global _default_level
    level_map = {
        "trace": TRACE_LEVEL,
        "debug": logging.DEBUG,
        "info": logging.INFO,
        "warning": logging.WARNING,
        "error": logging.ERROR,
    }
    _default_level = level_map.get(level.lower(), logging.INFO)
    fmt = format_string or _DEFAULT_FORMAT
    stream = stream or sys.stderr

    root = logging.getLogger()
    root.setLevel(_default_level)
    if not root.handlers:
        handler = logging.StreamHandler(stream)
        handler.setFormatter(logging.Formatter(fmt, datefmt=_DATE_FORMAT))
        root.addHandler(handler)
    else:
        for h in root.handlers:
            h.setFormatter(logging.Formatter(fmt, datefmt=_DATE_FORMAT))
            h.setLevel(_default_level)


def get_logger(name: str) -> logging.Logger:
    """
    获取具名 logger。名称通常使用 __name__。

    使用方式：
        from core.logger import get_logger
        log = get_logger(__name__)
        log.trace("...")
        log.debug("...")
        log.info("...")
        log.warning("...")
        log.error("...")
    """
    logger = logging.getLogger(name)
    if logger.level == logging.NOTSET:
        logger.setLevel(_default_level)
    return logger
