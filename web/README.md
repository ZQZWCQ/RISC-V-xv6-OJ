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
后端 API 路径前缀由现有 VITE_APP_BASE_API、VITE_APP_PLUGIN_BASE
及代理 rewrite 配置共同处理，本次仅配置目标地址。
