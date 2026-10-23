## 一、功能划定

`patchcheck` 是评测链路中的**纯文本静态预检器**：仅凭一个 `commit.patch`，判断补丁的格式与改动范围是否合法，并给出可执行的中文建议。

对于 C1 返回的 JSON，`patchcheck` 负责 `precheck` 和 `patch` 字段，二者信息可直接复制。其他概不负责。

## 二、环境

需要在可执行文件同级目录中有 `rules` 文件夹，内部通过存放各个实验白名单、资产等内容来消除 `patchcheck` 内部的硬编码。

## 三、调用方式

采用命令行调用的方式。

```bash
patchcheck --patch <file> --lab <lab> --out <json>
```

|参数     |是否必填|意义        |
|:-----:|:--:|:--------:|
|--patch|是   |补丁文件绝对路径|
|--lab  |是   |实验名称（目前仅有）      |
|--out  |否   |输出目标 json 文件绝对路径，没有时打印到控制台|

## 四、输出

退出码：

|码  |意义  |
|:-:|:--:|
|0  |正常跑通|
|1  |patchcheck 程序内部错误|
|2  |传参有误|

json 结构与 C1 第三部分的 `precheck` 和 `patch` 字段**完全一致** 。

```json
{
  "precheck": {
    "passed": true,
    "checks": [
      {
        "code": "patch.missing_new_files",
        "level": "error",
        "message": "未包含新增文件",
        "hint": "疑似未进行 git add 操作"
      }
    ]
  },

  "patch": {
    "files": [ { "path": "kernel/proc.c", "added": 12, "removed": 3 } ],
    "binary": false,
    "touches_protected": ["gradelib.py"]
  }
}
```

其中部分具体值作如下规定：

`passed`：存在 `error` 即是 `false`，否则都是 `true`

`checks[].code`与 `checks[].level`：

| code |  level |
| --- | --- |
| `patch.empty` | `error` |
| `patch.unparsable` | `error` |
| `patch.binary` | `error` |
| `patch.too_large` | `error` |
| `patch.path_not_allowed` | `error` |
| `patch.touches_protected` | **`warn`** |
| `patch.missing_new_files` | `error` |
| `patch.wrong_base` | `error` |

