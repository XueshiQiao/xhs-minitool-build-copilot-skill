# 能力快照

> **对齐版本**：小红书官方规范 v1.2.0 · 快照日期 **2026-07**
> **来源**：小红书《小工具容器能力清单》与官方 `minitool-zip-builder` skill v1.2.0。
> 本文为独立整理与转述，非官方文档原文；**以官方最新说明为准**。
>
> ⚠️ 如果当前日期距快照已超过 3 个月，先去核对官方是否更新了规范。
> 官方 skill 下载地址：`https://fe-static.xhscdn.com/mini-tool/<版本>/minitool-zip-builder.zip`

---

## 一句话概括运行环境

一个**受限沙箱里的纯 Web 页面**：标准 HTML/CSS/JS，`index.html` 为唯一入口，
**完全离线、不联网**，所有资源必须打包在 zip 内，每个小工具的存储互相隔离。

---

## 可用

### 页面与渲染
标准 HTML / CSS / JS 全套（Flexbox、Grid、动画、媒体查询、渐变等）。
Canvas 2D 完整可用。WebGL 可用于纯渲染，纹理须来自包内资源或内存对象。

### 存储
`localStorage` / `sessionStorage` / `IndexedDB` / `Cookie` / `Cache API`，
按小工具独立隔离，外部与其他小工具都访问不到。
**但官方明示：请勿假设数据永久持久化。**
Cookie 因为不联网，不会随请求发出，不能用于登录态。

### 媒体
- 摄像头 / 麦克风：`getUserMedia`，需用户手势触发 + 系统授权
- 选图 / 拍照：`<input type="file">`，**系统选择器接管，只能选图片和视频，`accept` 写什么都无效**
- 音视频：`<video>` / `<audio>` 内联播放，文件须打包在内

### 交互
`alert()` / `confirm()` 可用（原生 UI 展示）。触摸与 Pointer 事件正常。

### 资源
- 样式：内联 `<style>`、行内 `style="..."`、包内样式表都可以
- 图片：包内文件、`data:` URI、`blob:`（`createObjectURL`，如选图预览）
- 字体：`@font-face` 引用**包内** `.woff` / `.woff2`
- 内联 SVG：作为标记写在 HTML 里，不算外部请求

---

## 不可用

### 被禁的 Web API

| 分类 | 具体 |
|---|---|
| 网络 | `fetch`、`XMLHttpRequest`、`WebSocket`、`EventSource`、`RTCPeerConnection` |
| 定位 | `navigator.geolocation.*` |
| 剪贴板 | `navigator.clipboard.*`、`document.execCommand('copy'/'cut'/'paste')` |
| 硬件 | `navigator.bluetooth` / `usb` / `hid` / `serial` |
| 传感器 | 加速度计、陀螺仪、磁力计、环境光、`DeviceMotionEvent`、`DeviceOrientationEvent` |
| 后台 | Web Worker、SharedWorker、Service Worker |
| 屏幕 | `getDisplayMedia`（屏幕共享）、`requestFullscreen`（全屏由容器管） |
| 设备信息 | `getBattery`、`connection`、`enumerateDevices` |
| 存储进阶 | **`navigator.storage.persist`**（申请持久化）、跨域存储访问 |
| 凭据 | WebAuthn（`navigator.credentials`）、`navigator.locks` |
| 窗口 | `window.open`、`window.prompt` |

移动端 WebView 本身也不支持：`PaymentRequest`、系统通知/推送、NFC、MIDI、
XR/AR/VR、后台同步与下载、PWA 安装、窗口管理、指针/键盘锁定。

### 被禁的行为

| 行为 | 说明 |
|---|---|
| 一切联网请求 | 含加载外部图片 / 字体 / 媒体 |
| 动态执行代码 | `eval()`、`new Function()` |
| WebAssembly | 依赖 WASM 的库全部跑不了 |
| iframe / object | 内嵌与被嵌都禁 |
| 表单跳转提交 | `<form>` 提交跳转 |
| **文件下载** | `a[download]`、blob 下载 |
| 打开外链 / 新窗口 | `target="_blank"`、跳转站外 |
| 跳转其他小工具 | 小工具之间互跳 |
| **长按菜单** | 系统长按菜单已禁用（所以「长按保存图片」这条路也没了） |

---

## CSP：最容易踩的一条

**脚本必须外置。** 容器 CSP 的 `script-src` 不含 `unsafe-inline`，
所以下面这些全都不行：

```html
<script>...</script>          <!-- 内联脚本 -->
<button onclick="fn()">       <!-- 行内事件 -->
<a href="javascript:...">     <!-- javascript: URI -->
```

正确写法：JS 放进包内 `.js`，用 `<script src="./app.js"></script>` 引入，
事件一律 `addEventListener`。

**样式反而可以内联** —— `<style>` 和 `style="..."` 都能用，无需外置。

---

## 打包

| 项 | 要求 |
|---|---|
| 入口 | `index.html` **必须在 zip 根目录**，不可改名、不可放子目录 |
| 打包方式 | 进入目录压缩**目录内容**，不是压缩目录本身（否则解压后多一层，容器加载不了） |
| 允许的文件类型 | `.html` `.css` `.js` `.png` `.jpg` `.jpeg` `.gif` `.webp` `.svg` `.woff` `.woff2` `.json` |
| 路径 | 一律相对路径 `./xxx`，不用绝对路径，不用 `<base href>` |
| viewport | 须含 `width=device-width, initial-scale=1.0, viewport-fit=cover` |
| CSP meta | **不要自建**，安全策略由容器统一管理 |
| 体积 | 推荐总包 < 2MB，单图 < 500KB |

```bash
# ✅ 正确
cd dist && zip -r ../tool.zip . -x '*.DS_Store'
# ❌ 错误：解压后 index.html 变成 dist/index.html
zip -r tool.zip dist
```

---

## 跨端

同一份 H5 同时跑在 PC 模拟器和真机 WebView：

- 交互优先用 Pointer 事件统一鼠标与触摸
- 布局用 `%` / `flex` / `vw`，**不要写死像素宽**
- 安全区**始终写 `env(safe-area-inset-*, 0px)` 带 fallback**（PC 模拟器下 inset 为 0，真机为真实值）
- 真机有软键盘会遮挡输入框，必要时监听 `visualViewport`

---

## 提交流程

1. PC 端登录小红书创作者服务中心
2. 左侧菜单 → Builder Hub → 小工具
3. 新建小工具 → 填名称 / 简介 / 图标（png·jpg·jpeg，≤5M，推荐 1:1）
4. 上传 zip → 提交审核
5. 过审后：移动端发笔记 → 编辑页 → 挂件/组件 → 小工具 → 挂载

小工具**一次上传、多次复用**——同一个工具可以挂到多篇笔记上，
所以它必须是**通用的**，没法给每篇笔记定制内容。
