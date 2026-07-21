---
name: xhs-minitool-build-copilot-skill
description: 小红书小工具 Copilot。先判断一个点子在小工具容器里能不能做、值不值得做，再生成合规的可上传产物。当用户说「想做一个小红书小工具」「这个功能小工具能实现吗」「帮我做个挂在笔记里的小工具」，或在排查容器能力限制、审核被驳回原因时使用。
version: 1.2.0
---

# 小红书小工具 Copilot

> 对齐小红书官方规范 **v1.2.0**，能力快照日期 **2026-07**。

小工具 = 挂在小红书笔记里的**离线 H5**。读者在笔记里点开直接用，不跳转。
你写标准网页（`index.html` 入口），打包成 zip 上传审核，过审后发笔记时挂载。

**这个 skill 解决的不是「怎么打包」，而是「该不该做、能不能做」。**
打包规范以小红书官方 `minitool-zip-builder` skill 为准；这里做的是它没覆盖的部分：
可行性判定、产品方向、脚手架、踩坑库。

---

## 最重要的一件事

**先判可行性，再动手写代码。**

这个容器砍掉的能力比想象中多，而且**砍法是有产品意图的**（见 [product-fit.md](references/product-fit.md)）。
直接开写的结果通常是：写到一半发现核心功能做不出来，或者做出来了但没人用。

用户描述完想做什么之后，**第一步永远是跑一遍可行性判定**，把结论明确说出来，
不要含糊过去。做不到就说做不到，并给替代方案。

---

## 工作流程

### 第 1 步 · 可行性判定（必做）

读 [feasibility-rubric.md](references/feasibility-rubric.md)，把用户的需求拆成能力项逐条判。

输出必须落到三个结论之一，**不允许模糊**：

| 结论 | 含义 |
|---|---|
| ✅ 可做 | 所需能力全在容器内 |
| ⚠️ 可做但要改 | 核心可行，但某个环节触到红线，需要换实现方式 |
| ❌ 做不到 | 命中硬限制，且没有等价替代 |

判完立刻告诉用户，**每条限制都要给出「为什么」和「替代方案」**，
不要只说「不支持」。

### 第 2 步 · 产品方向（判为可做时）

读 [product-fit.md](references/product-fit.md)。

技术可行 ≠ 值得做。这个容器禁下载、禁剪贴板、禁外链、禁跳转，
**是刻意要把互动和流量留在笔记里**。逆着这个意图设计的工具，即使能跑起来也没人用。

用三条标准过一遍用户的点子，不过关就直说，并给出改造方向。

### 第 3 步 · 生成

- 从 [templates/starter](templates/starter) 起步：已经满足入口、CSP、viewport、安全区的全部硬要求
- 写之前先读 [pitfalls.md](references/pitfalls.md)，那里是实际踩过的坑，不是理论
- 能力边界随时查 [capability-snapshot.md](references/capability-snapshot.md)

### 第 4 步 · 打包

```bash
./scripts/build-minitool.sh <工具目录> [输出.zip]
```

脚本按规范做 7 组校验，**任何一项不过就中止、不产出 zip**；
通过后逐字节比对 zip 与源码（防「改完忘了重新打包」）。

---

## Reference

按需读，不要一次全读进来。

| 文档 | 什么时候读 |
|---|---|
| [feasibility-rubric.md](references/feasibility-rubric.md) | **每次都读**。判断需求能不能做 |
| [product-fit.md](references/product-fit.md) | 判为可做之后，评估值不值得做、该往哪改 |
| [capability-snapshot.md](references/capability-snapshot.md) | 查具体某个 API / 能力是否可用 |
| [pitfalls.md](references/pitfalls.md) | 动手写代码前 |

---

## 版本锚定

**主版本号与次版本号镜像小红书官方规范的版本，修订号是本 skill 自己的迭代。**

| 本 skill 版本 | 含义 |
|---|---|
| `1.2.0` | 对齐官方规范 v1.2.x 的第一版 |
| `1.2.1` `1.2.2` … | 同一份规范下，本 skill 自己的修订 |
| `1.3.0` | 官方发布 v1.3.x 后跟进的第一版 |

这样**从版本号一眼就能看出它对齐的是哪一版规范**。
（SkillHub 只接受三段式 semver，不支持 `+spec.x.y.z` 这类构建元数据，所以用镜像而非后缀。）

[capability-snapshot.md](references/capability-snapshot.md) 是**版本锁定的快照**，
顶部标注了对齐的官方版本与日期。小红书更新规范后：

1. 重新下载官方 skill，比对差异
2. 只更新快照文件，并同步改主/次版本号与快照日期
3. 其余文档（可行性、产品、踩坑）通常不需要动

**如果快照日期距今超过 3 个月，先提示用户去核对官方最新规范再往下做。**
