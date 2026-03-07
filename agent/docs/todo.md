# 待办 (TODO)

- [x] 外部配置：所有可配置项（prompt、选项等）放入 config/*.yaml，运行时通过 core/config_loader 加载
- [x] 公用/独立拆分：chat_agent、reflection_agent 各自独立目录；公用部分（interfaces、models、response）保留顶层，见 done
- [x] Agent 模块化：每层/模块单独文件，核心 agent 只做拼接（chat_agent 与 reflection_agent 均已完成）
- [x] 后端 API 实现：RealServerAPI（config 可配 base_url、access_token、use_real_api）
- [x] 服务端：各 agent 以服务形式运行，config 可调 port 等，API 与 agent 输入对齐
- [x] 测试机制：项目根 run_server、run、test_chat_agent、test_reflection_agent、test
- [x] 完善日志机制：trace / debug / info / warning / error 级别（见 core/logger.py）
- [x] 文档：维护 todo.md、done.md、api.md
