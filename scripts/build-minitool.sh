#!/usr/bin/env bash
#
# 小红书小工具打包脚本
# ---------------------------------------------------------------------------
# 按小红书官方小工具规范（对齐 v1.2.0 / 2026-07）做校验并打包。
#
# 用法：
#   ./build-minitool.sh <工具目录> [输出.zip]
#   ./build-minitool.sh my-tool my-tool.zip
#
# 属于 xhs-minitool-skill：https://github.com/XueshiQiao/xhs-minitool-skill
#
# 校验不通过会直接退出，不会产出一个有问题的包。
# ---------------------------------------------------------------------------
set -euo pipefail

SRC="${1:-}"
if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
  echo "用法: $0 <工具目录> [输出.zip]" >&2
  exit 2
fi
SRC="${SRC%/}"
OUT="${2:-$(basename "$SRC").zip}"
OUT_SHOWN="$OUT"
# 统一成绝对路径：打包时要 cd 进暂存目录，相对路径会指错地方
case "$OUT" in /*) : ;; *) OUT="$PWD/$OUT" ;; esac

# 容器允许的文件类型（zip-artifact-spec §2）
ALLOWED_EXT="html css js png jpg jpeg gif webp svg woff woff2 json"

RED=$'\033[31m'; GRN=$'\033[32m'; YEL=$'\033[33m'; DIM=$'\033[2m'; OFF=$'\033[0m'
FAIL=0
ok()   { printf "  ${GRN}✓${OFF} %s\n" "$1"; }
bad()  { printf "  ${RED}✗${OFF} %s\n" "$1"; FAIL=1; }
warn() { printf "  ${YEL}!${OFF} %s\n" "$1"; }
note() { printf "    ${DIM}%s${OFF}\n" "$1"; }

# 注释行判定：CSS/JS 的 * // /*，HTML 的 <!--，以及中文说明里描述约束的行。
# 命中注释只提示、不算失败；命中非注释一律失败。
is_comment() {
  printf '%s' "$1" | grep -qE '^\s*(\*|//|/\*|<!--)' && return 0
  printf '%s' "$1" | grep -qE '禁|可用但|不要用|绝不能|说明|注意' && return 0
  return 1
}

echo
echo "═══ 小红书小工具打包：$SRC → ${OUT_SHOWN} ═══"

# ── 1. 包结构 ───────────────────────────────────────────────────────────────
echo
echo "【1】包结构"
[ -f "$SRC/index.html" ] && ok "index.html 存在（将位于 zip 根目录）" \
                         || bad "缺少 index.html —— 容器要求它必须在 zip 根目录"

BAD_EXT=0
while IFS= read -r f; do
  base="$(basename "$f")"
  ext="${base##*.}"
  # 无扩展名或扩展名不在白名单
  if [ "$base" = "$ext" ] || ! printf '%s\n' $ALLOWED_EXT | grep -qx "$(printf '%s' "$ext" | tr 'A-Z' 'a-z')"; then
    warn "将被排除（类型不允许）: ${f#$SRC/}"
    BAD_EXT=$((BAD_EXT+1))
  fi
done < <(find "$SRC" -type f -not -path '*/.*')
[ "$BAD_EXT" -eq 0 ] && ok "目录内无不允许的文件类型" \
                     || note "以上文件不会打进 zip（容器只接受: ${ALLOWED_EXT}）"

HTML_COUNT=$(find "$SRC" -maxdepth 1 -name '*.html' -not -name '_*' | wc -l | tr -d ' ')
[ "$HTML_COUNT" -eq 1 ] && ok "只有一个入口 HTML" \
                        || bad "根目录有 $HTML_COUNT 个 HTML —— 容器要求有且只有一个 index.html"

STRAY=$(find "$SRC" -name '_*' -o -name 'node_modules' -o -name '*.map' | head -5)
[ -z "$STRAY" ] && ok "无临时/开发垃圾文件" || { warn "发现临时文件，将被排除:"; echo "$STRAY" | sed 's/^/      /'; }

# ── 2. index.html 规范（zip-artifact-spec §5）─────────────────────────────
echo
echo "【2】index.html 规范"
H="$SRC/index.html"
grep -qi '<!doctype html>' "$H"            && ok "有 <!DOCTYPE html>"        || bad "缺 <!DOCTYPE html>"
grep -qi 'lang="zh-CN"' "$H"               && ok 'html lang="zh-CN"'        || bad '缺 lang="zh-CN"'
grep -qi 'charset="\?UTF-8"\?' "$H"        && ok "charset=UTF-8"            || bad "charset 需为 UTF-8"
for tok in 'width=device-width' 'initial-scale=1' 'viewport-fit=cover'; do
  grep -q "$tok" "$H" && ok "viewport 含 $tok" || bad "viewport 缺 $tok"
done
grep -qi '<base ' "$H"                     && bad "存在 <base href> —— 会破坏真机路径" || ok "无 <base href>"
grep -qiE '<iframe|<object' "$H"           && bad "存在 iframe/object —— 容器全部禁止"  || ok "无 iframe / object"
grep -qi 'http-equiv="content-security-policy"' "$H" && bad "自建了 CSP meta —— 安全策略由容器统一管理" || ok "无自建 CSP meta"

# ── 3. CSP：脚本与资源（zip-artifact-spec §3）────────────────────────────
echo
echo "【3】容器 CSP"
# 内联 <script>：有内容的 script 标签（<script src=...> 是允许的）
if grep -nE '<script[^>]*>[^<[:space:]]' "$H" | grep -v 'src=' | grep -q .; then
  bad "存在内联 <script> —— script-src 不含 unsafe-inline"
  grep -nE '<script[^>]*>[^<[:space:]]' "$H" | grep -v 'src=' | head -3 | sed 's/^/      /'
else
  ok "脚本全部外置（<script src>）"
fi

if grep -oE ' on[a-z]+="' "$H" >/dev/null 2>&1; then
  bad "存在行内事件属性（onclick= 等）—— 必须改用 addEventListener"
  grep -noE ' on[a-z]+="' "$H" | head -3 | sed 's/^/      /'
else
  ok "无行内事件属性"
fi

# 运行时外部引用（注释里的网址不算）
EXT_HITS=0
while IFS= read -r line; do
  content="${line#*:}"
  is_comment "$content" && continue
  bad "外部资源引用: $line"
  EXT_HITS=$((EXT_HITS+1))
done < <(grep -nE 'src="https?://|href="https?://|url\(https?://' "$SRC"/*.html "$SRC"/*.js "$SRC"/*.css 2>/dev/null || true)
[ "$EXT_HITS" -eq 0 ] && ok "无运行时外部资源引用（外部 CDN 一律加载不到）"

grep -nE 'src="/|href="/' "$H" | grep -q . && bad "存在绝对路径引用 —— 离线包必须用 ./ 相对路径" \
                                           || ok "资源均为相对路径"

# ── 4. 禁用能力扫描（device-capabilities §6）──────────────────────────────
echo
echo "【4】禁用能力扫描"
# 用 grep -F 固定字符串，避免正则里的括号需要转义 —— 转义写错会让 grep 静默报错、
# 把「没扫到」当成「没问题」。这个坑踩过一次。
PATS=$(mktemp)
cat > "$PATS" <<'PATTERNS'
fetch(
XMLHttpRequest
new WebSocket(
new EventSource(
new RTCPeerConnection(
navigator.geolocation
navigator.clipboard
execCommand(
navigator.bluetooth
navigator.usb
navigator.hid
navigator.serial
navigator.getBattery
navigator.connection
navigator.credentials
navigator.locks
enumerateDevices
getDisplayMedia
navigator.storage.persist
serviceWorker.register
new Worker(
new SharedWorker(
new Accelerometer
new Gyroscope
new Magnetometer
DeviceMotionEvent
DeviceOrientationEvent
requestFullscreen
eval(
new Function(
WebAssembly.
window.open(
window.prompt(
location.assign(
target="_blank"
PATTERNS
API_HITS=0; API_COMMENTS=0
while IFS= read -r line; do
  content="${line#*:}"; content="${content#*:}"
  if is_comment "$content"; then API_COMMENTS=$((API_COMMENTS+1)); continue; fi
  bad "禁用能力: $line"
  API_HITS=$((API_HITS+1))
done < <(grep -nF -f "$PATS" "$SRC"/*.html "$SRC"/*.js 2>/dev/null || true)
rm -f "$PATS"
[ "$API_HITS" -eq 0 ] && ok "35 条禁用能力扫描通过"
[ "$API_COMMENTS" -gt 0 ] && note "另有 $API_COMMENTS 处命中在注释中（描述约束，非调用），已忽略"

# ── 5. 跨端（cross-platform-h5 §6）───────────────────────────────────────
echo
echo "【5】跨端适配"
# grep 无匹配时返回 1，而「无匹配」正是通过的情况；
# 配合 set -o pipefail 会误判为失败并终止脚本，所以必须 || true
NOFB=$( { grep -oE 'env\(safe-area-inset-[a-z]+\)' "$H" || true; } | wc -l | tr -d ' ')
[ "$NOFB" -eq 0 ] && ok "env(safe-area-inset-*) 均带 fallback" \
                  || bad "$NOFB 处 env(safe-area-inset-*) 缺 fallback —— 跨端文档要求始终写 env() + fallback"

# ── 6. 打包 ─────────────────────────────────────────────────────────────
echo
echo "【6】打包"
if [ "$FAIL" -ne 0 ]; then
  echo
  printf "${RED}校验未通过，已中止打包。修完上面标 ✗ 的项再跑一次。${OFF}\n\n"
  exit 1
fi

STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
while IFS= read -r f; do
  base="$(basename "$f")"; ext="$(printf '%s' "${base##*.}" | tr 'A-Z' 'a-z')"
  case "$base" in _*) continue ;; esac
  printf '%s\n' $ALLOWED_EXT | grep -qx "$ext" || continue
  rel="${f#$SRC/}"
  mkdir -p "$STAGE/$(dirname "$rel")"
  cp "$f" "$STAGE/$rel"
done < <(find "$SRC" -type f -not -path '*/.*')

rm -f "$OUT"
# 关键：进入目录压缩「内容」，不是压缩目录本身，否则解压后 index.html 不在根
( cd "$STAGE" && zip -rq "$OUT" . -x '*.DS_Store' )
ok "已生成 ${OUT_SHOWN}"

# ── 7. 产物自检 ─────────────────────────────────────────────────────────
echo
echo "【7】产物自检"
TOP=$( { unzip -Z1 "$OUT" | awk -F/ 'NF==1' || true; } | head -1)
unzip -Z1 "$OUT" | grep -qx 'index.html' && ok "index.html 在 zip 根目录（未多套一层目录）" \
                                         || bad "index.html 不在根目录，顶层是: $TOP"

# 逐文件比对 —— 防的是「改完源码忘了重新打包」
VERIFY="$(mktemp -d)"; unzip -q "$OUT" -d "$VERIFY"
MISMATCH=0
while IFS= read -r zf; do
  rel="${zf#$VERIFY/}"
  if ! cmp -s "$zf" "$SRC/$rel"; then bad "zip 内 $rel 与源码不一致"; MISMATCH=1; fi
done < <(find "$VERIFY" -type f)
rm -rf "$VERIFY"
[ "$MISMATCH" -eq 0 ] && ok "zip 内容与源码逐字节一致"

BYTES=$(wc -c < "$OUT" | tr -d ' ')
KB=$((BYTES/1024))
[ "$BYTES" -lt 2097152 ] && ok "体积 ${KB}KB（上限 2MB）" || bad "体积 ${KB}KB 超过 2MB"

echo
if [ "$FAIL" -eq 0 ]; then
  printf "${GRN}全部通过${OFF} —— %s 可以上传\n" "${OUT_SHOWN}"
  echo
  unzip -l "$OUT" | sed 's/^/  /'
  echo
  exit 0
else
  printf "${RED}产物自检未通过${OFF}\n\n"
  exit 1
fi
