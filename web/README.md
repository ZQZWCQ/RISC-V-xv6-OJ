# 前端开发说明

前端基于 RuoYi-FastAPI 的 Vue3 Web 工程，来源与版本见 UPSTREAM.md。

## 安装与启动

在 web 目录执行：

```bash
npm install
npm run dev -- --port 5173
```

访问终端显示的 Local 地址。登录和数据功能需要配套后端运行。

## 本机后端代理配置

Vite 使用 VITE_DEV_PROXY_TARGET 设置开发代理目标。
未配置时，默认连接 http://127.0.0.1:9099。

如需覆盖，在 web 目录创建 .env.development.local：

```dotenv
VITE_DEV_PROXY_TARGET=http://127.0.0.1:19099
```

常见情况：

- 后端直接运行在本机 9099：使用默认值即可。
- Docker 将后端端口映射为 19099:9099：配置为 http://127.0.0.1:19099。
- 后端运行在其他电脑：填写那台电脑可访问的地址与端口。

127.0.0.1 指运行 Vite 的电脑。
修改环境配置后，需要重启 Vite。

.env.development.local 是个人配置，不提交到 Git。
VITE_ 前缀的变量可能暴露给浏览器，不要填写密码、令牌等秘密。

此变量只控制 Vite 开发代理，不配置生产环境的 Nginx 转发。
后端 API 路径前缀由 VITE_APP_BASE_API 和 Vite 代理的 rewrite 配置处理。
VITE_DEV_PROXY_TARGET 只指定开发代理的目标地址。

## 测试范围

本工程以独立 Vue3 Web 前端为维护范围。以下测试调整用于解除对上游完整仓库目录结构的依赖。

- 业务插件系统已移除，对应的插件专用测试一并删除。
- JSON 编辑器及 Monaco 已移除，对应构建适配、公共脚本和专用测试一并删除。
- 保留 tests/frontend/transportPath.test.js，验证普通 API 请求的路径标准化逻辑。
- 认证中心专用功能及测试已移除，普通登录能力保留。

`APP_ROOT_PATH` 的跨仓库断言。前后端部署前缀一致性需在实际联调部署中验证。
- 保留 `tests/time/time.test.js`：将其依赖的 `contract.mjs` 和 `fixtures.json` 从上游共享测试目录引入 `tests/time/`，改用同目录导入。来源及提交版本见 `UPSTREAM.md`。
- 随定时任务管理界面一并移除 `tests/job/job-form.test.js`、`src/utils/job.js` 和 `test:job` 脚本入口。

在 `web/` 目录运行：

```bash
npm test
npm run build:prod
```

`npm test` 执行当前保留的前端测试；生产构建验证发布文件能否生成。二者不替代真实登录、页面操作及前后端权限联调。
