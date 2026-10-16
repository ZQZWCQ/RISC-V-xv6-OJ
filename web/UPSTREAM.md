# 前端模板来源

- 上游仓库：https://github.com/insistence/ruoyi-vue3-fastapi
- 使用目录：ruoyi-fastapi-frontend/vue3/web
- 上游提交：025b0822df11e95b19960a015494fed9a75c8de7
- 引入日期：2026-10-15

保留前端目录自带的 LICENSE。
上游仓库根许可证另存为 LICENSE-RuoYi-FastAPI。

本项目前端基于上述版本继续开发。

## 补充引入的测试文件

以下文件取自上述同一上游提交的 ruoyi-fastapi-test/time-contract/：

- contract.mjs → tests/time/contract.mjs
- fixtures.json → tests/time/fixtures.json

用于独立运行前端时间工具测试，避免依赖项目外的上游目录。
