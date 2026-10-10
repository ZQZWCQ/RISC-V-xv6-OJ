# 契约 C2：前端 ↔ 业务后端

> 状态：草案 v0.1
> 双方：`web/`（调用方） ↔ `services/api`（实现方）
> 形式：REST + OpenAPI（FastAPI 自动生成，`/docs` 可交互调试）
> 变更前必须先改本文件

---

## 1. 通用约定

- **前缀**：`/api`
- **鉴权**：JWT（沿用若依模板），请求头 `Authorization: Bearer <token>`
- **响应包装**（沿用若依约定）：

```json
{ "code": 200, "msg": "操作成功", "data": {} }
```

- **分页**：请求 `?page_num=1&page_size=10`，响应 `data = { "rows": [], "total": 0 }`
- **时间格式**：ISO 8601，例如 `2026-10-10T23:19:01+08:00`

---

## 2. 错误码

| code | 含义 |
| --- | --- |
| 200 | 成功 |
| 400 | 参数错误 |
| 401 | 未登录 / token 过期 |
| 403 | 无权限 |
| 404 | 资源不存在 |
| 409 | 冲突（如：已有评测在排队） |
| 500 | 服务端错误 |

---

## 3. 提交状态机

```
prechecking → precheck_failed
            → queued → running → done
                                → failed
            → canceled
```

| 状态 | 前端展示 |
| --- | --- |
| `prechecking` | 正在检查补丁… |
| `precheck_failed` | 补丁有问题（展示诊断） |
| `queued` | 排队中（第 N 位） |
| `running` | 评测中… |
| `done` | 完成（展示分数） |
| `failed` | 评测失败（展示原因） |
| `canceled` | 已撤回 |

---

## 4. 学生端接口

### 4.1 登录

```
POST /api/auth/login
Body: { "student_id": "2026xxxx", "password": "..." }
Resp: { "code": 200, "data": { "token": "...", "must_change_password": true } }
```

### 4.2 实验列表

```
GET /api/labs
Resp: data = [{
  "id": 1,
  "code": "syscall",
  "name": "Lab2 进程与系统调用",
  "deadline": "2026-11-01T23:59:59+08:00",
  "guide_url": "https://os-labs.p.cs-lab.top/lab2/part1.html",
  "requirement": "提交 commit.patch（使用 make diff 生成）",
  "possible": 100,
  "my_best_score": 80
}]
```

`my_best_score` 未提交时为 `null`。

### 4.3 提交补丁

```
POST /api/submissions
Content-Type: multipart/form-data
Fields: lab_code=syscall, file=<commit.patch>
Resp: data = { "id": 123, "status": "prechecking" }
错误: 409 = 已有评测在排队或进行中
```

### 4.4 查询提交（含进度与反馈）

```
GET /api/submissions/{id}
Resp: data = {
  "id": 123,
  "lab_code": "syscall",
  "status": "done",
  "submitted_at": "2026-10-10T23:19:01+08:00",
  "score": { "earned": 80, "possible": 100 },
  "queue_position": null,
  "failure_class": null,
  "precheck": { "passed": true, "checks": [] },
  "tests": [
    { "title": "exit test", "points": 40, "earned": 40, "status": "ok", "message": null }
  ],
  "hint": "未通过：wait test",
  "has_raw_log": true
}
```

`precheck` 与 `tests` 的结构与契约 C1 一致，后端只做转发与裁剪。

### 4.5 我的提交历史

```
GET /api/submissions?lab_code=syscall&page_num=1&page_size=10
Resp: data = {
  "rows": [{
    "id": 123,
    "lab_code": "syscall",
    "status": "done",
    "score": { "earned": 80, "possible": 100 },
    "submitted_at": "2026-10-10T23:19:01+08:00"
  }],
  "total": 7
}
```

### 4.6 下载原始日志

```
GET /api/submissions/{id}/log      →  text/plain 附件
```

### 4.7 撤回排队中的提交

```
POST /api/submissions/{id}/cancel
```

### 4.8 实时进度（可选，S05 再定）

```
GET /api/submissions/{id}/events   →  text/event-stream（SSE）
```

---

## 5. 教师端接口

### 5.1 班级成绩总表

```
GET /api/teacher/submissions?lab_code=&class_name=&status=&page_num=1&page_size=20
Resp: data = {
  "rows": [{
    "student_id": "2026xxxx",
    "name": "【姓名】",
    "class_name": "【班级】",
    "lab_code": "syscall",
    "best_score": { "earned": 80, "possible": 100 },
    "attempts": 3,
    "last_submitted_at": "2026-10-10T23:19:01+08:00",
    "status": "done"
  }],
  "total": 128
}
```

### 5.2 导出 Excel（按实验）

```
GET /api/teacher/export?lab_code=syscall
→  application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
```

导出列：学号 / 姓名 / 班级 / 实验 / 最高分 / 满分 / 提交次数 / 首次提交时间 / 最后一次提交时间

### 5.3 人工改分 / 复核

```
POST /api/teacher/submissions/{id}/score
Body: { "earned": 90, "reason": "现场复核" }
```

必须记录审计信息：修改人、修改时间、原始分数、修改原因。

### 5.4 重新评测

```
POST /api/teacher/submissions/{id}/rerun
```

### 5.5 下载学生原始补丁

```
GET /api/teacher/submissions/{id}/patch      →  text/x-patch 附件
```

---

## 6. 前端开发注意事项

- 后端返回值优先，不要自行判断
- 不改动若依模板的鉴权逻辑，只新增页面

---

## 7. 变更规则

接口变更必须先改本文件（或直接改 FastAPI 的 Pydantic 模型，让 `/docs` 自动更新），再改代码。
