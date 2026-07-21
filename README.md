# xhs-minitool-build-copilot-skill

**小红书小工具 Copilot** —— 先判断一个点子在小工具容器里**能不能做、值不值得做**，再生成合规的可上传产物。

> 版本 `1.2.0` · 对齐小红书官方规范 **v1.2.0**（快照 2026-07）

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
git clone https://github.com/XueshiQiao/xhs-minitool-build-copilot-skill.git \
  ~/.claude/skills/xhs-minitool-build-copilot-skill

# Codex
git clone https://github.com/XueshiQiao/xhs-minitool-build-copilot-skill.git \
  ~/.codex/skills/xhs-minitool-build-copilot-skill

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

**主版本号与次版本号镜像小红书官方规范的版本，修订号是本 skill 自己的迭代。**

| 本 skill 版本 | 含义 |
|---|---|
| `1.2.0` | 对齐官方规范 v1.2.x 的第一版 |
| `1.2.1` `1.2.2` … | 同一份规范下，本 skill 自己的修订 |
| `1.3.0` | 官方发布 v1.3.x 后跟进的第一版 |

从版本号一眼就能看出它对齐的是哪一版规范。

`references/capability-snapshot.md` 是**版本锁定的快照**，顶部标注了对齐的官方版本与日期。

**小红书更新规范后怎么跟：**

1. 下载官方最新 skill：`https://fe-static.xhscdn.com/mini-tool/<版本>/minitool-zip-builder.zip`
2. 与快照比对差异，只更新 `capability-snapshot.md`
3. 同步改 `SKILL.md` 里的 `version`（主/次版本跟随官方）与快照日期

其余三份文档（可行性、产品、踩坑）通常不需要动——它们讲的是判断方法和实战经验，不是接口清单。

> 如果快照日期距今超过 3 个月，skill 会先提示去核对官方最新规范。

---

## 发布到小红书 SkillHub

```bash
npm install -g "https://fe-video-qc.xhscdn.com/fe-platform-file/104101b83221qt9bu7k0653u0hejenq0004pf88k9rpr6a.tgz"
CLI="$(npm root -g)/@xhs/skillhub-upload/cli/index.mjs"

node "$CLI" whoami                       # 检查授权
node "$CLI" login --agent                # 未授权时

printf 'submit\n' | node "$CLI" publish "$(pwd)" --agent \
  --source original --tag 编程开发,效率工具 \
  --name "小红书小工具 Copilot" \
  --identifier xhs-minitool-build-copilot-skill
```

三个必须知道的点：

1. **`skillhub-upload` 命令直接跑会静默退出**。它的入口判断 `import.meta.url === file://${process.argv[1]}`，
   而 npm 全局安装的是软链接，两个路径不相等，`main()` 根本不执行。必须 `node <真实入口路径>` 调用。
2. **版本号只接受三段式 semver**，`1.0.0+spec.1.2.0` 这类构建元数据会被拒
   （`semver must have 3 parts`）。这也是本 skill 采用「主次版本镜像官方规范」方案的原因。
3. **展示名有长度上限**，`xhs-minitool-build-copilot-skill`（32 字符）会被拒
   （`名称长度不符合要求`）。用 `--name` 传短展示名，用 `--identifier` 单独锁定 Skill ID。

包内文件类型白名单也比较窄：`LICENSE`、`.gitignore` 这类**无扩展名文件会被判为二进制拒收**，
所以本仓库用的是 `LICENSE.md` 且不带 `.gitignore`。

---

## 来源与免责

能力清单部分整理自小红书公开发布的《小工具容器能力清单》与官方 `minitool-zip-builder` skill，
**均为独立转述，非官方文档原文**。本项目与小红书官方无关联，
一切以官方最新说明为准。

可行性判定、产品方向、踩坑库为原创内容，来自实际做完并提交一个小工具的过程。

## License

MIT
