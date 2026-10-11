#!/usr/bin/env bash
# S01 驱动脚本：在已装好 Docker 的 Linux 主机上跑通「编译 → QEMU → 判分」，并实测耗时。
#
# 用法：
#   COURSE_DIR=~/rv6/xv6-oslabs-hitsz bash scripts/s01/run-s01.sh
#   LAB=syscall COURSE_DIR=~/rv6/xv6-oslabs-hitsz WRONG_BRANCH=util bash scripts/s01/run-s01.sh
#
# 产出：stdout 摘要 + runtime/s01/logs/*.log 原始日志 + runtime/s01/report.md 记录表
#
# 全部课程信息走环境变量，脚本内不硬编码任何课程参数。

set -uo pipefail

IMAGE="${IMAGE:-rv6judge:s01}"
DOCKERFILE="${DOCKERFILE:-infra/xv6/Dockerfile.s01}"
COURSE_DIR="${COURSE_DIR:-$HOME/rv6/xv6-oslabs-hitsz}"
LAB="${LAB:-util}"
BRANCH="${BRANCH:-$LAB}"
GRADE_SCRIPT="${GRADE_SCRIPT:-grade-lab-$LAB}"
GRADEFLAGS="${GRADEFLAGS:--v}"            # 只支持 -v / --color；不要加 --toolprefix，见 runbook 阶段 7
TOOLPREFIX="${TOOLPREFIX:-riscv64-elf-}"  # 以环境变量传给 make，而不是判分脚本的命令行参数
BASELINE_TAG="${BASELINE_TAG:-}"          # 留空则从该分支 Makefile 的 diff: 目标解析
WRONG_BRANCH="${WRONG_BRANCH:-}"          # 错误基线用例的来源分支，留空则跳过该用例
WRONG_BASE_TAG="${WRONG_BASE_TAG:-}"      # 生成错误补丁时用的基线 tag，留空则用 BASELINE_TAG
FAULT_FILE="${FAULT_FILE:-user/sleep.c}"  # 编译错误用例注入的文件
OUT_DIR="${OUT_DIR:-runtime/s01}"
QEMU_SMOKE_TIMEOUT="${QEMU_SMOKE_TIMEOUT:-180}"
SKIP_BUILD_IMAGE="${SKIP_BUILD_IMAGE:-0}"

LOG_DIR="$OUT_DIR/logs"
REPORT="$OUT_DIR/report.md"
RC=0
BUILD_SECONDS=""; GRADE_SECONDS=""; TEST_COUNT=""; PER_TEST=""
GRADE_SCORE=""; GRADE_EXIT=""; QEMU_SMOKE=""; KVM_HOST=""; KVM_CTR=""

mkdir -p "$LOG_DIR"

log()  { printf '\n== %s ==\n' "$*"; }
note() { printf '   %s\n' "$*"; }
die()  { printf 'FATAL: %s\n' "$*" >&2; exit 1; }

# 在容器内、以课程目录为工作区执行命令
in_ctr() { docker run --rm -v "$COURSE_DIR:/mnt" -w /mnt "$IMAGE" bash -lc "$1"; }
# 计时执行：把「秒数 退出码」打到 stdout（命令替换是子 shell，无法回传变量），命令输出写进日志
timed() { # timed <logfile> <shell-command>  →  "<seconds> <rc>"
  local logf="$1" cmd="$2" t0 t1 secs rc
  t0=$(date +%s.%N)
  in_ctr "$cmd" >"$logf" 2>&1; rc=$?
  t1=$(date +%s.%N)
  secs=$(awk -v a="$t0" -v b="$t1" 'BEGIN{printf "%.1f", b-a}')
  printf '%s %s' "$secs" "$rc"
}

[ -d "$COURSE_DIR/.git" ] || die "课程目录不存在或不是 git 仓库：$COURSE_DIR"
command -v docker >/dev/null || die "未找到 docker"
docker info >/dev/null 2>&1 || die "docker 不可用（当前用户是否已在 docker 组？需重新登录）"

# ---------------------------------------------------------------- 1. 构建镜像
if [ "$SKIP_BUILD_IMAGE" = "1" ] && docker image inspect "$IMAGE" >/dev/null 2>&1; then
  log "1. 构建评测镜像（已跳过）"
else
  log "1. 构建评测镜像 $IMAGE"
  T0=$(date +%s)
  docker build -f "$DOCKERFILE" -t "$IMAGE" . >"$LOG_DIR/docker-build.log" 2>&1 \
    || die "镜像构建失败，见 $LOG_DIR/docker-build.log"
  note "构建耗时 $(( $(date +%s) - T0 ))s，日志：$LOG_DIR/docker-build.log"
fi

log "2. 工具链探测"
in_ctr 'qemu-system-riscv64 --version | head -1; '"${TOOLPREFIX}"'gcc --version | head -1' \
  | tee "$LOG_DIR/toolchain.log"

log "3. KVM 探测"
if [ -e /dev/kvm ]; then KVM_HOST="是"; else KVM_HOST="否"; fi
KVM_CTR=$(in_ctr '[ -e /dev/kvm ] && echo 是 || echo 否' | tr -d '\r')
note "宿主 /dev/kvm：$KVM_HOST    容器内 /dev/kvm：$KVM_CTR（本脚本不加 --privileged）"

# ---------------------------------------------------------------- 4. 切分支
log "4. 检出分支 $BRANCH"
git -C "$COURSE_DIR" checkout "$BRANCH" >"$LOG_DIR/git-checkout.log" 2>&1 \
  || die "git checkout $BRANCH 失败，见 $LOG_DIR/git-checkout.log"
if [ -z "$BASELINE_TAG" ]; then
  BASELINE_TAG=$(git -C "$COURSE_DIR" show HEAD:Makefile \
    | awk '/^diff:/{f=1;next} f&&/git diff/{print $3; exit}')
fi
[ -n "$BASELINE_TAG" ] || die "无法从 Makefile 的 diff: 目标解析出基线 tag，请显式传 BASELINE_TAG"
note "基线 tag：$BASELINE_TAG（取自 Makefile 的 diff: 目标，各分支不统一）"
git -C "$COURSE_DIR" status --short | head -5

# ---------------------------------------------------------------- 5. 全量编译
log "5. 全量编译耗时"
in_ctr 'make clean' >"$LOG_DIR/make-clean.log" 2>&1
read -r BUILD_SECONDS RC <<<"$(timed "$LOG_DIR/make.log" "make TOOLPREFIX=$TOOLPREFIX")"
note "全量编译：${BUILD_SECONDS}s（exit=$RC）"
[ "$RC" -eq 0 ] || die "编译失败，见 $LOG_DIR/make.log"

# ---------------------------------------------------------------- 6. QEMU 冒烟
log "6. QEMU 冒烟测试（找 'init: starting sh'）"
timeout -k 5 "$QEMU_SMOKE_TIMEOUT" docker run --rm -v "$COURSE_DIR:/mnt" -w /mnt "$IMAGE" \
  bash -lc "make TOOLPREFIX=$TOOLPREFIX qemu" >"$LOG_DIR/qemu-smoke.log" 2>&1
if grep -q 'init: starting sh' "$LOG_DIR/qemu-smoke.log"; then
  QEMU_SMOKE="通过"
else
  QEMU_SMOKE="未看到 init: starting sh（见 $LOG_DIR/qemu-smoke.log）"
fi
note "$QEMU_SMOKE"
# timeout 杀掉的是 docker CLI，残留容器需清掉，否则下一次冒烟会因镜像占用/串口冲突失败
docker ps -q --filter "ancestor=$IMAGE" 2>/dev/null | xargs -r docker kill >/dev/null 2>&1

# ---------------------------------------------------------------- 7. 判分实测
log "7. 判分实测：$GRADE_SCRIPT $GRADEFLAGS"
# 注意：gradelib.run_tests() 自己会先跑一次 make（增量），所以这里不需要 make clean
read -r GRADE_SECONDS GRADE_EXIT <<<"$(timed "$LOG_DIR/grade.log" "TOOLPREFIX=$TOOLPREFIX ./$GRADE_SCRIPT $GRADEFLAGS")"
GRADE_CLEAN=$(mktemp)
sed -e 's/\x1b\[[0-9;]*m//g' "$LOG_DIR/grade.log" >"$GRADE_CLEAN"
GRADE_SCORE=$(grep -E '^Score: ' "$GRADE_CLEAN" | tail -1)
TEST_COUNT=$(grep -cE '^== Test .* ==$' "$GRADE_CLEAN")
if [ -n "$GRADE_SECONDS" ] && [ -n "$TEST_COUNT" ] && [ "$TEST_COUNT" -gt 0 ]; then
  PER_TEST=$(awk -v s="$GRADE_SECONDS" -v n="$TEST_COUNT" 'BEGIN{printf "%.1f", s/n}')
fi
note "耗时：${GRADE_SECONDS}s    测试项：${TEST_COUNT}    单测试均值：${PER_TEST}s"
note "退出码：$GRADE_EXIT（未满分时 gradelib.py 执行 sys.exit(1)，退出码不代表成绩）"
note "解析结果：${GRADE_SCORE:-未找到 Score: 行}"
[ -n "$GRADE_SCORE" ] || note "警告：没有 Score: 行，说明判分脚本本身报错了"
cp "$GRADE_CLEAN" "$LOG_DIR/grade.clean.log"; rm -f "$GRADE_CLEAN"

# ---------------------------------------------------------------- 8. 失败路径
log "8. 失败路径实测"
: >"$OUT_DIR/empty.patch"
git -C "$COURSE_DIR" apply --check "$(pwd)/$OUT_DIR/empty.patch" 2>"$LOG_DIR/empty-patch.log"
note "① 空补丁 git apply --check 退出码：$?（空补丁能应用，但等于没改代码 → 仍是基线分）"

if [ -n "$WRONG_BRANCH" ]; then
  [ -n "$WRONG_BASE_TAG" ] || WRONG_BASE_TAG="$BASELINE_TAG"
  git -C "$COURSE_DIR" diff "$WRONG_BASE_TAG" "$WRONG_BRANCH" >"$OUT_DIR/wrong-base.patch" 2>"$LOG_DIR/wrong-base.log"
  git -C "$COURSE_DIR" apply --check "$(pwd)/$OUT_DIR/wrong-base.patch" 2>>"$LOG_DIR/wrong-base.log"
  note "② 错误基线补丁（$WRONG_BRANCH 相对 $WRONG_BASE_TAG）apply --check 退出码：$?"
  sed -n '1,3p' "$LOG_DIR/wrong-base.log"
else
  note "② 错误基线用例已跳过（未设置 WRONG_BRANCH）"
fi

if git -C "$COURSE_DIR" diff --quiet -- "$FAULT_FILE"; then
  printf '\nthis is not valid c;\n' >>"$COURSE_DIR/$FAULT_FILE"
  in_ctr "make TOOLPREFIX=$TOOLPREFIX" >"$LOG_DIR/compile-error.log" 2>&1
  note "③ 编译错误（$FAULT_FILE 注入语法错误）make 退出码：$?（非 0 即预期）"
  grep -m2 -E 'error:|Error' "$LOG_DIR/compile-error.log" | sed 's/^/     /'
  git -C "$COURSE_DIR" checkout -- "$FAULT_FILE"
  in_ctr "make TOOLPREFIX=$TOOLPREFIX" >/dev/null 2>&1
  note "   已还原 $FAULT_FILE 并重新编译"
else
  note "③ 跳过：$FAULT_FILE 在运行前就不干净"
fi

# ---------------------------------------------------------------- 9. 报告
log "9. 写入 $REPORT"
cat >"$REPORT" <<EOF
# S01 实测记录（脚本生成，硬件信息需人工补齐）

- 生成时间：$(date '+%Y-%m-%d %H:%M:%S')
- 镜像：$IMAGE（$DOCKERFILE）
- 课程仓库：$COURSE_DIR
- 实验 / 分支 / 基线：$LAB / $BRANCH / $BASELINE_TAG

| 项目 | 实测值 |
|---|---|
| 宿主 /dev/kvm | $KVM_HOST |
| 容器内 /dev/kvm（未加 --privileged） | $KVM_CTR |
| QEMU 是否需要 --privileged | 冒烟结果「$QEMU_SMOKE」 |
| 全量编译耗时 | ${BUILD_SECONDS}s |
| 单次完整 grade 耗时 | ${GRADE_SECONDS}s |
| 测试项数 / 单测试均值 | ${TEST_COUNT} / ${PER_TEST}s |
| 判分脚本输出 | ${GRADE_SCORE:-无 Score 行} |
| 判分脚本退出码 | $GRADE_EXIT |

## 失败路径

| 用例 | 实测表现 |
|---|---|
| 空补丁 | 见 logs/empty-patch.log |
| 错误基线 | 见 logs/wrong-base.log |
| 编译错误 | 见 logs/compile-error.log |

## 原始日志

logs/docker-build.log · toolchain.log · make.log · qemu-smoke.log · grade.clean.log
EOF

log "完成"
printf '全量编译 %ss ｜ 单次 grade %ss ｜ 单测试均值 %ss ｜ %s\n' \
  "$BUILD_SECONDS" "$GRADE_SECONDS" "$PER_TEST" "${GRADE_SCORE:-无 Score 行}"
