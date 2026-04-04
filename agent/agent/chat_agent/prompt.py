"""系统提示词层：根据配置生成系统提示"""
from .config import AgentConfig

OUTPUT_PROTOCOL = """
## 输出协议（必须遵守）

你必须在每一轮助手回复末尾输出一段 **机器可读** 的结构化 JSON，且用下列围栏紧贴包围（前面可先写给用户看的正文）：

<agent_json>
{
  "text": "与本轮对用户展示的正文一致或略精炼，用于会话记录；若无特殊情况可与上文自然语言段落相同。",
  "function_calls": [
    { "id": "fc_001", "name": "工具名（须与工具列表中的 name 完全一致）", "arguments": { } }
  ],
  "environment": {
    "time_mode": null,
    "weather_mode": null,
    "camera_mode": null,
    "rain_amount": null,
    "snow_amount": null
  },
  "action": {
    "pose": null,
    "emotion": null
  }
}

说明：
1. **function_calls**：无工具调用时使用 `[]`。每个对象的 `arguments` 必须是 JSON 对象（键名、类型须符合对应工具 schema）。
2. **environment**：不需要改环境时各键可省略或设为 null。`time_mode`：0=白天, 1=黄昏, 2=晚上, 3=同步系统；`weather_mode`：0=晴天, 1=雨天, 2=雪天, 3=同步；`camera_mode`：0/1 与设置一致；`rain_amount`/`snow_amount`：可选整数强度。
3. **action**：演出用。`pose` 可选：`idle`,`typing`,`clap`,`think`,`cheer`,`watch`,`greet`,`surprised`,`disbelief`,`stretch`,`stretch2`,`talk`；`emotion` 可选：`neutral`,`happy`,`sad`,`surprised`,`angry`,`saying`,`blinking`。
4. 围栏标签必须原样使用：起始行 `<agent_json>`，结束行 `</agent_json>`，中间为 **唯一一个** JSON 对象。
5. 全文必须使用中文（JSON 内的字符串值也使用中文，除工具参数要求的枚举/ID 外）。
"""


def get_system_prompt(config: AgentConfig) -> str:
    """角色与基础能力说明（不含工具目录与输出协议）。"""
    return config.system_prompt_template.format(
        character_name=config.character_name,
        character_personality=config.character_personality,
    )


def build_full_system_prompt(config: AgentConfig, tools_markdown: str) -> str:
    """完整 system 消息：角色设定 + 工具目录 + 输出协议。"""
    return (
        get_system_prompt(config).strip()
        + "\n\n"
        + tools_markdown.strip()
        + "\n\n"
        + OUTPUT_PROTOCOL.strip()
    )
