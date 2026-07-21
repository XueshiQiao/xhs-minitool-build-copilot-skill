# xhs-minitool-copilot

**小红书小工具 Copilot** —— 先判断一个点子在小工具容器里**能不能做、值不值得做**，再生成合规的可上传产物。

> 版本 `1.0.0+spec.1.2.0` · 对齐小红书官方规范 v1.2.0（快照 2026-07）

---

## 这个 skill 解决什么

小红书官方已经有一个 `minitool-zip-builder` skill，讲的是**怎么打包**。
这个 skill 不重复它，补的是它没覆盖的那半边：

| | 官方 skill | 这个 skill |
|---|---|---|
| 怎么打包成合规 zip | ✅ | 引用官方为准 |
| **这个点子能不能做** | — | ✅ 七条硬红线 + 三条黄线逐条判 |
| **值不值得做** | — | ✅ 产品契合度三标准 |
| 起始脚手架 | — | ✅ 已满足全部硬要求 |
| **实战踩坑库** | — | ✅ 21 条，全是真踩出来的 |
| 一键校验 + 打包脚本 | — | ✅ 不过校验就不产出 zip |

### 为什么「能不能做」比「怎么打包」更值钱

这个容器砍掉的能力比想象中多——**禁联网、禁下载、禁剪贴板、禁外链、禁 WASM、禁 Worker、
连申请数据持久化保护的 API 都禁了**。更麻烦的是，砍法是有产品意图的：

> 禁下载、禁剪贴板、禁外链、禁跳转 —— 这不是技术限制，
> 是要**把价值和流量留在笔记里**。

结果就是：很多点子技术上一路绿灯，产品上两头不靠。
**先判可行性再动手，能省掉整轮返工。**

---

## 安装

克隆到你的 agent 的 skills 目录：

```bash
# Claude Code
git clone https://github.com/XueshiQiao/xhs-minitool-copilot.git \
  ~/.claude/skills/xhs-minitool-copilot

# Codex
git clone https://github.com/XueshiQiao/xhs-minitool-copilot.git \
  ~/.codex/skills/xhs-minitool-copilot

# 其他 agent：放进它约定的 skills 目录即可
```

装好后直接问就行：

- 「我想做一个小红书小工具，能不能实现 XXX？」
- 「帮我做个挂在笔记里的小工具，功能是 XXX」
- 「这个小工具审核被驳回了，可能是什么原因？」

---

## 结构

```
SKILL.md                              主入口：工作流程与路由
references/
  ├── feasibility-rubric.md           ⭐ 可行性判定（每次都读）
  ├── product-fit.md                  产品方向：小红书想要什么样的小工具
  ├── capability-snapshot.md          能力快照（版本锁定）
  └── pitfalls.md                     ⭐ 21 条实战踩坑
scripts/
  └── build-minitool.sh               校验 + 打包，不过校验就中止
templates/
  └── starter/                        合规起始脚手架
```

---

## 打包脚本单独用

不装 skill 也能直接用：

```bash
./scripts/build-minitool.sh <工具目录> [输出.zip]
```

它会做 7 组校验——包结构、`index.html` 规范、容器 CSP、35 条禁用能力扫描、
跨端适配、打包、产物自检。**任何一项不过就中止、不产出 zip**；
通过后还会把 zip 内每个文件与源码逐字节比对，防「改完源码忘了重新打包」。

---

## 版本锚定

版本号形如 `1.0.0+spec.1.2.0`：

- `1.0.0` —— 本 skill 自己的迭代
- `+spec.1.2.0` —— 锚定当时对齐的小红书官方规范版本

`references/capability-snapshot.md` 是**版本锁定的快照**，顶部标注了对齐的官方版本与日期。

**小红书更新规范后怎么跟：**

1. 下载官方最新 skill：`https://fe-static.xhscdn.com/mini-tool/<版本>/minitool-zip-builder.zip`
2. 与快照比对差异，只更新 `capability-snapshot.md`
3. 同步改 `SKILL.md` 里的 `version` 与快照日期

其余三份文档（可行性、产品、踩坑）通常不需要动——它们讲的是判断方法和实战经验，不是接口清单。

> 如果快照日期距今超过 3 个月，skill 会先提示去核对官方最新规范。

---

## 来源与免责

能力清单部分整理自小红书公开发布的《小工具容器能力清单》与官方 `minitool-zip-builder` skill，
**均为独立转述，非官方文档原文**。本项目与小红书官方无关联，
一切以官方最新说明为准。

可行性判定、产品方向、踩坑库为原创内容，来自实际做完并提交一个小工具的过程。

## License

MIT
