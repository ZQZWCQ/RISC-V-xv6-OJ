## 一、调用方式

采用命令行调用的方式。

```bash
patchcheck --patch <file> --lab <lab> --out <json>
```

|参数     |是否必填|意义        |
|:-----:|:--:|:--------:|
|--patch|是   |补丁文件路径（只读）|
|--lab  |是   |实验名称      |
|--out  |否   |输出目标 json 文件，没有时打印到控制台|

## 二、输出

退出码：

|码  |意义  |
|:-:|:--:|
|0  |正常跑通|
|1  |解析失败|
|2  |传参有误|

json：

```json
{
  "passed": false,
  "checks": [
    {
      "code": "patch.empty",
      "level": "error",
      "hint": "提交 patch 文件为空",
      "info": "error: No valid patches in input (allow with \"--allow-empty\")"
    }
  ]
}
```

`passed` 字段：`true` 表示通过预检。

`checks[].code`：同 C1。

`checks[].level`：

| code |  `level` |
| --- | --- |
| `patch.empty` | `error` |
| `patch.unparsable` | `error` |
| `patch.binary` | `error` |
| `patch.too_large` | `error` |
| `patch.path_not_allowed` | `error` |
| `patch.touches_protected` | **`warn`** |
| `patch.missing_new_files` | `error` |
| `patch.wrong_base` | `error` |

`checks[].info`：所有控制台信息（包括 git 的和自身程序）。

`checks[].hint`：直接给学生看的信息 .

