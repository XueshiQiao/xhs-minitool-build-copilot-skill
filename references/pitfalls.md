# 踩坑库

> 这些都是实际做完并提交了一个小工具之后攒下来的，不是从文档推演的。
> 每条按「症状 → 根因 → 修法」写，动手前扫一遍能省掉几轮返工。

---

## 一、容器相关

### 1. `<input type="file">` 挡不住视频

**症状**：用户选了个视频，后面的流程直接崩。

**根因**：系统选择器接管了选择，**`accept` 写什么都无效**，只能选图片和视频两类。

**修法**：拿到 file 后必须自己判：

```js
if (file.type && file.type.indexOf('video/') === 0) {
  toast('这是视频，请选一张图片'); return;
}
```

### 2. 老版本容器会拦 `<img>` 加载 `blob:` / `data:`

**症状**：选图预览在新机器上正常，旧版本上白屏。

**根因**：`<img>` 加载 `blob:` / `data:` 从 9.37 版本起才支持。

**修法**：`onerror` 兜底走 `createImageBitmap` + Canvas：

```js
img.onerror = function () {
  createImageBitmap(file).then(function (bmp) {
    var c = document.createElement('canvas');
    c.width = bmp.width; c.height = bmp.height;
    c.getContext('2d').drawImage(bmp, 0, 0);
    // 用这个 canvas 代替 img 显示
  });
};
```

### 3. 日期必须按本地时区算

**症状**：23:59 打的卡记到了第二天。

**根因**：`new Date('2026-07-21')` 会按 **UTC** 解析。

**修法**：一律用三参数构造 + 本地取值：

```js
function keyOf(d){ return d.getFullYear()+'-'+pad2(d.getMonth()+1)+'-'+pad2(d.getDate()); }
function dateOf(k){ var p=k.split('-'); return new Date(+p[0], +p[1]-1, +p[2]); }
```

### 4. 跨午夜要覆盖两种情况

**症状**：凌晨打卡记到了前一天。

**根因**：只监听了 `visibilitychange`（切后台再回前台），
但**页面一直亮着跨过 0 点**时不会触发。

**修法**：两条都要，再加操作瞬间兜底：

```js
document.addEventListener('visibilitychange', function(){ if(document.visibilityState==='visible') ensureToday(); });
setInterval(function(){ if(document.visibilityState==='visible') ensureToday(); }, 30000);
// 并在真正写数据前再调一次 ensureToday()
```

---

## 二、CSS 相关

### 5. CSS 变量取不到值时，`border-color` 会变黑

**症状**：边框莫名其妙变成黑色。

**根因**：`border-color: var(--x)` 里 `--x` 未定义时，声明失效并回退到
**`currentColor`**（也就是文字的深色）——看起来就是黑框。

**修法**：**永远写 fallback**。

```css
border-color: var(--chip-border, var(--chip-color));
```

### 6. 「环的粗细」不能用固定的中心洞大小来控制

**症状**：手机上环很细，桌面浏览器里粗了三倍。

**根因**：环的直径是格子的**百分比**（会随视口变大），但挖洞用的是**固定 px**，
两者不同步 → 视口越宽环越粗。

**修法**：直接指定粗细，用 `inset` 挖洞：

```css
.ring{ position:relative; border-radius:50%; background:var(--gradient); }
.ring::after{ content:""; position:absolute; inset:var(--ring-w); border-radius:50%; background:var(--paper); }
```

### 7. 子元素全是 `position:absolute` 时，`aspect-ratio` 会塌成 0

**症状**：容器整块空白，什么都不显示。

**根因**：所有子元素都绝对定位 → 容器没有内在尺寸 → 只有
`aspect-ratio` + `max-width/max-height`（两个方向都只有 max 约束）算不出尺寸。

**修法**：用 JS 按父容器算出确定的 px 宽高写上去，别指望 CSS 自己推。

### 8. `min-height` 会顶掉内联的 `height`

**症状**：JS 设了 `style.height` 但元素没变矮。

**根因**：CSS 里的 `min-height` 优先级更高。

**修法**：两个一起设：

```js
el.style.height = h + 'px';
el.style.minHeight = h + 'px';
```

### 9. 主题的配色规则会盖掉状态的配色规则

**症状**：某个主题下，选中项的文字看不清（深字压在深底上）。

**根因**：`[data-theme="x"] .day--l3 .num` 权重是 **0,3,0**，
而 `.day--sel .num` 只有 **0,2,0** —— 主题赢了。

**修法**：把**状态类规则放在样式表最末尾**，并补一条带 `[data-theme]` 的
同权重版本靠顺序取胜：

```css
.day--sel .num,
[data-theme] .day--sel .num{ background:var(--ink); color:#fff; }
```

### 10. emoji 会戳出格子

**症状**：日历格子里的图标溢到相邻日期上。

**修法**：`overflow:hidden` 兜底，并且算清楚宽度——
「3 个图标 + `+N`」通常比「3 个图标」宽得多，要给 `+N` 留位置。

---

## 三、状态管理相关

### 11. 状态切换的重绘不能只写在 `if (on)` 里 ⭐

**症状**：进入某个模式正常，**退出后残留**该模式的文案 / 排序 / 样式。

**根因**：

```js
function setMode(on){
  mode = on;
  if (on) { render(); }   // ← 退出时不重绘，残留
}
```

**修法**：进和出都要重绘，把它移出分支：

```js
function setMode(on){
  mode = on;
  if (on) { /* 只放进入时的一次性动作 */ }
  render();   // ← 无条件
}
```

### 12. `textContent` 会把按钮里的内联 SVG 清空 ⭐

**症状**：图标按钮切换一次状态后，图标消失了。

**根因**：用 `btn.textContent = '✓'` 换图标，会**删掉按钮的所有子节点**，
包括你放进去的 `<svg>`。

**修法**：两个图标都常驻 DOM，只切 class：

```html
<button id="b"><svg class="ico ico--a">…</svg><svg class="ico ico--b">…</svg></button>
```
```css
.ico--b{display:none;}
#b.is-on .ico--a{display:none;}
#b.is-on .ico--b{display:block;}
```

### 13. 关闭动画的定时器会把「刚重新打开」的面板藏掉

**症状**：快速关掉再打开同一个弹层，只剩一层点不掉的蒙层。

**根因**：`hideSheet()` 里 `setTimeout(280ms)` 设 `hidden=true`，
若期间又打开了同一个元素，这个迟到的定时器会把它藏了。

**修法**：保存定时器句柄，`showSheet()` 里先 `clearTimeout`；
回调里再判一次 `if (openSheet !== el)`。

---

## 四、按钮与命中区

### 14. 图标按钮容易做成椭圆

**症状**：一排圆形按钮里，某一个是椭圆。

**根因**：给了左右 `padding` 却没定 `width`，内容宽度不同 → 形状不同。

**修法**：图标按钮统一 `padding:0; width:34px; min-width:34px`。

### 15. 整个可见控件都要能点

不能只有图标/文字能点、四周 padding 是死的。命中区至少 44px。
拖拽类的把手更要给足（视觉 38px、命中区 56px 这种）。

---

## 五、验证方法（比代码更重要）

### 16. 状态切换必须测**双向往返** ⭐⭐

只截「进入」那一张**等于没验证**。正确做法：

1. 截初始状态
2. 进入 → 截图
3. 退出 → 截图
4. **第 3 张与第 1 张做校验和比对，必须逐字节一致**

```bash
shasum -a256 base.png roundtrip.png | awk '{print $1}' | uniq -c   # 计数为 2 才算通过
```

坑 11、12、13 全是这么抓出来的。

### 17. 无头浏览器的布局视口可能不是你以为的宽度

**症状**：截图右侧被切，误以为页面横向溢出。

**根因**：Chrome `--headless=new` 会忽略 `--window-size` 对布局视口的影响
（macOS 上窗口最小宽度还被钳到 500px），结果按 500px 排版却只截 390px。

**修法**：想要真实移动端宽度，**用一个 390px 的 iframe 包一层**再截。
另外，判断是否真溢出要**量** `documentElement.scrollWidth` vs `clientWidth`，
不要靠肉眼看截图。

### 18. grep 正则里的括号不转义会**静默失败**

**症状**：扫描脚本报告「0 命中」，看着像通过，其实压根没扫。

**根因**：`fetch(` 这类模式里的 `(` 在正则里是分组符，写错会让 grep 直接报错退出，
而管道里的 `wc -l` 照样输出 0。

**修法**：扫固定字符串一律用 `grep -F -f patterns.txt`。

### 19. `set -o pipefail` 会把「grep 没找到」当成失败

**症状**：校验脚本跑到一半无声退出，什么都不打印。

**根因**：grep 无匹配时返回 1，而「无匹配」恰恰是通过的意思；
`pipefail` + `set -e` 会直接终止脚本。

**修法**：

```bash
COUNT=$( { grep -oE 'pattern' "$f" || true; } | wc -l | tr -d ' ')
```

### 20. 改完源码一定要重新打包，并**逐字节比对**

**症状**：上传的还是旧版本。

**修法**：打包脚本里把 zip 解开和源码 `cmp` 一遍。
`scripts/build-minitool.sh` 已经内置这一步。

---

## 六、bash 小坑

### 21. 变量名后面紧跟中文，会被当成变量名的一部分

```bash
echo "只接受: $ALLOWED_EXT）"    # ✗ bash 认为变量叫 ALLOWED_EXT）
echo "只接受: ${ALLOWED_EXT}）"  # ✓
```

配合 `set -u` 会直接报 `unbound variable`。**输出里带中文标点时一律加花括号。**
