# 已完成 (Done)

- [x] 建立 docs 目录，添加 todo.md、done.md、api.md
- [x] 项目内统一日志机制（trace / debug / info / warning / error）
- [x] 外部配置：config/settings.yaml、chat_agent.yaml、reflection_agent.yaml，core/config_loader.py 运行时加载；服务端与 Agent 从配置读取 host/port、prompt、选项
- [x] 公用/独立拆分：主聊天 Agent 放入 agent/chat_agent/，反思 Agent 放入 agent/reflection_agent/；agent 包统一从两子包导出。公用部分（interfaces、models、response）仍在项目顶层，文档中明确为公用
- [x] Agent 模块化：chat_agent 拆为 config、prompt、context、task_intent、task_generation、agent；reflection_agent 拆为 config、prompt_builder、agent。核心 agent 仅拼接各层
- [x] 后端 API 实现：interfaces/real_server_api.py 实现 RealServerAPI，调用 config 中 base_url（默认 http://106.54.18.206:8000/api/v1），支持 GET /tasks、get_task、get_statistics/get_daily_summary 聚合
