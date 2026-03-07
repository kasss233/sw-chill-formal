# 待办 (TODO)

- [x] 外部配置：所有可配置项（prompt、选项等）放入 config/*.yaml，运行时通过 core/config_loader 加载
- [x] 公用/独立拆分：chat_agent、reflection_agent 各自独立目录；公用部分（interfaces、models、response）保留顶层，见 done
- [x] Agent 模块化：每层/模块单独文件，核心 agent 只做拼接（chat_agent 与 reflection_agent 均已完成）
- [ ] 后端 API 实现：为需调用后端的接口实现 RealServerAPI（Base URL: http://106.54.18.206:8000/api/v1）
- [ ] 服务端：各 agent 以服务形式运行，配置文件可调 port 等，API 与 agent 输入对齐
- [ ] 测试机制：项目根目录 run server / test 脚本，tests 独立文件夹，run_xx_agent / test_xx_agent 及统一 run / test
- [x] 完善日志机制：trace / debug / info / warning / error 级别（见 core/logger.py）
- [x] 文档：维护 todo.md、done.md、api.md
