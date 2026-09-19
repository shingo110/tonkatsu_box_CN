# PROJECT.md — 项目全景

面向新加入本仓库的开发者。要动手写代码，请先读 [`RULES.md`](RULES.md)（硬约束与坑点）与 [`.claude/CLAUDE.md`](.claude/CLAUDE.md)（最详细的实现规约）；本文回答"这是什么、为什么这样做、东西在哪、接下来做什么"。

---

## 1. 一句话定位

`tonkatsu_box_CN` 是 [`hacan359/tonkatsu_box`](https://github.com/hacan359/tonkatsu_box) 的**国内化分支**：保留上游全部功能，把**数据源**从海外服务替换/补充为国内可直连、带中文元数据的服务。

| | |
|---|---|
| 本仓库 | `https://github.com/shingo110/tonkatsu_box_CN` |
| 上游 | `https://github.com/hacan359/tonkatsu_box`（MIT，接入时基线 **0.44.0+41**，迁移链 **v64**） |
| 本地路径 | `D:\Projects\TonkatsuBoxCN\tonkatsu_box_CN` |
| 技术栈 | Flutter 3.38+ / Dart 3.10+ · Riverpod 2.x · SQLite · Dio · Material 3 |
| 目标平台 | Windows · Android · Web（自托管）—— **三端必须同时可编译** |

## 2. 目标与非目标

**目标**

1. 让中文用户能在应用内搜到、并入库国内作品：动画、电影、剧集、图书、漫画。
2. 数据源的替换是**增量**的：上游源一个不删，国内源作为新增选项与备源并存。
3. 与上游保持可持续的同步能力 —— 每次同步的冲突面尽量小且可预期。

**非目标**

- 不做 UI 重设计、不改数据模型语义、不引入与数据源无关的功能分支。
- 不预置任何需要付费或需注册的数据源密钥。
- 不把上游已有的英文能力（如 AniList 的相似推荐）搬走或改写。

## 3. 上游同步策略

上游更新频繁（`release:` 提交节奏以周计）。本分支的改动面刻意做成**"新增为主、改动为追加"**，以压低同步成本。

```bash
# 一次性配置：让本仓库同时认识上游
git remote add upstream https://github.com/hacan359/tonkatsu_box.git

# 每次同步
git fetch upstream
git merge upstream/main      # 或 rebase，视当时工作区干净程度而定
```

### 冲突热点清单

同步时冲突几乎只会出现在这些位置 —— 上游也在往里加东西，而我们也在同一处追加：

| # | 文件 | 冲突形态 | 处理原则 |
|:-:|------|---------|---------|
| 1 | `packages/core/lib/models/data_source.dart` | 枚举末尾各加值 | 两边都留 |
| 2 | `lib/shared/constants/data_source_ui.dart` | 穷尽 switch 各加分支 | 两边都留 |
| 3 | `lib/shared/constants/source_catalog.dart` | `SourceInfo` 列表各加行 | 两边都留 |
| 4 | `lib/features/search/sources/search_sources.dart` | import + 实例各加行 | **注意列表顺序 = 主源优先级**，勿破坏上游既有次序 |
| 5 | `packages/core/lib/api/proxy_targets.dart` | `ProxyTarget` 枚举各加值 | 两边都留 |
| 6 | `server/lib/src/proxy_handler.dart` | `_authorize` 穷尽 switch | 带密钥的源须进对应分支 |
| 7 | `lib/l10n/app_*.arb` × 6 | 键各加 | 六种语言必须齐平，缺一即 `gen-l10n` 失败 |
| 8 | `test/**` 三处计数护栏 | 硬编码源数量 | 见 [`RULES.md`](RULES.md) 的护栏章节 |

### 让冲突变小的做法

- **新数据源一律建新文件**：`lib/core/api/<源>/`、`lib/features/search/sources/<源>_source.dart`、`lib/features/search/filters/<源>_*_filter.dart`，绝不往既有源的文件里塞逻辑。
- 对上游文件的改动**尽量是单独的追加行或新增方法**（例如 `Anime.fromBangumi` 就是一个独立 factory），避免重排既有代码。
- 本分支自有的文档（`PROJECT.md` / `TASK.md` / `RULES.md`）与 `README.md` 是唯一"重写过"的上游文件 —— 它们的冲突需人工裁决，不要机械两边都留。

## 4. 仓库地图

```
tonkatsu_box_CN/
├── lib/                       # Flutter 应用
│   ├── core/api/              # 每个数据源一个客户端目录 + 一个 facade
│   ├── core/database/         # 仅 database_service.dart（初始化、路径、DAO provider）
│   ├── core/import/           # 导入管线与各源适配器
│   ├── core/services/         # 导出/导入、备份、同步、图片缓存、配置
│   ├── features/              # collections · search · settings · statistics
│   │                          # tier_lists · mood_grids · wishlist · releases
│   │                          # recommendations · genre_cloud · showcase
│   │                          # likes · home · welcome · personalization · splash
│   ├── l10n/                  # 6 语言 ARB 源 + 生成的 AppLocalizations
│   └── shared/                # constants（*_ui 扩展 / 目录 / 平台开关）
│                              # theme · widgets · extensions · navigation …
├── packages/core/             # 纯 Dart 共享层：模型、数据库、迁移链、DAO、RPC
│   └── tool/generate_rpc.dart # 由 DAO 签名生成 RPC 桩与派发表
├── packages/gamepads_windows_stub/   # 覆盖上游崩溃的 gamepads_windows 插件的桩
├── server/                    # 自托管服务端（纯 Dart，shelf），不在应用的构建图内
│   ├── PROTOCOL.md            # /rpc 与 /proxy 的线上契约
│   └── lib/src/proxy_handler.dart    # /proxy 的鉴权与转发
├── test/                      # 应用侧测试（flutter_test + mocktail）
├── docs/                      # 专题文档（架构、代码风格、提交、手柄、导出格式）
├── scripts/                   # 本地关卡脚本
└── .github/workflows/         # CI：四道关卡
```

### 三个包的关系

| 包 | 依赖 | 约束 |
|----|------|------|
| `lib/`（应用） | 依赖 `core` | 所有 HTTP 必须经 `createApiDio` |
| `packages/core` | **不得依赖 Flutter** | 禁 `package:flutter` / `dart:ui` / `dart:ffi`；UI 相关的颜色、图标、本地化文案必须留在应用侧的 `*_ui.dart` |
| `server` | 依赖 `core` | 与应用互不导入；两者共用同一份模型、DAO 与迁移链 |

`packages/core` 用 `package:sqflite_common/sqlite_api.dart`（纯接口），**绝不用 `sqflite_common_ffi`** —— 后者拖入 `dart:ffi`，会让 Web 端无法编译。引擎由调用方注入：应用在 `main.dart` 装 `databaseFactoryFfi`，测试同样。

## 5. 架构要点

### 5.1 搜索源（本分支的改造主场）

```
SearchSource（抽象端口）
  ├── id / dataSource / outputMediaType / icon / supportsBrowse
  ├── filters        → 该源专属的筛选器列表
  ├── sortOptions    → 排序项
  └── fetch(ref, query, filterValues, sortBy, page) → 结果 + hasMore + 总页数
```

`searchSources`（`lib/features/search/sources/search_sources.dart`）是唯一注册表，**列表顺序即同类型源的主源 / 备源优先级** —— 第一个是该媒体的主源，其余为回退。新增源必须注册在此，位置紧邻同 provider 的源。

一个源背后的三段式：

```
<源>_types.dart         常量与异常类型
<源>_http_client.dart   Dio 封装（来自 createApiDio），异常 → 领域异常
<源>_search_api.dart    搜索与详情的请求/解析，返回领域模型
<源>_api.dart           facade + Provider（供 Provider 层注入）
```

### 5.2 数据库与迁移

**迁移链是 schema 的唯一真相**：全新安装与升级走的是同一条链的回放（`openAppDatabase` 的 `onCreate` 回放全链，`onUpgrade` 回放待办段）。目标版本取自 `MigrationRegistry.latestVersion`，**没有任何地方手写版本号**。

> ⚠️ **既有迁移与 `schema.dart` 的 `create*Table` 一律不可修改，只能追加新迁移。** 详见 [`RULES.md`](RULES.md)。

### 5.3 Web 端（自托管）

浏览器内**不持有数据库**：`databaseServiceProvider` 交给生成的 `RemoteDaoSet`，每次 DAO 调用变成一次 `POST /rpc`。外部 API 在浏览器里全部不可达（跨域、User-Agent 被剥离、密钥不能下发），因此 `createApiDio` 在 Web 端安装 `ProxyRewriteInterceptor`：凡命中 `kProxyTargets` 白名单的主机，重写为 `/proxy/<slug>/…`，由服务端补齐 UA 与凭据。

白名单表由前后端**共用同一份**（`packages/core/lib/api/proxy_targets.dart`）—— 复制一份必然漂移，且会把路由变成开放中继。新增数据源若要在 Web 可用，必须在此加一行；带密钥的还要在 `server` 的 `ApiProxy._authorize` 加分支。

## 6. 国内源接入矩阵

| 媒体类型 | 数据源 | 状态 | 关键约束 |
|---------|--------|:----:|---------|
| 动画 | Bangumi | ✅ 已并入 | 免密钥；**必须带自定义 User-Agent**，否则 Cloudflare 403；空关键词浏览须把 sort 从 `match` 换为 `rank` |
| 动画 / 图书 / 影视 | NeoDB | 📋 待实现 | 免密钥，`neodb.social/api/catalog/search` |
| 电影 / 剧集 | 豆瓣 Frodo | 📋 待实现 | HMAC-SHA1 签名；**连打约 10 次即 403、冷却 3–5 分钟** → 须先补 403 退避（现有 `host_rate_limiter` 只做 FIFO，不处理封禁）；签名 path 必须与最终 path 一致 |
| 电影 / 剧集 | 豆瓣免签接口 | 📋 待实现 | `movie.douban.com/j/subject_suggest`，需 Referer；无限流但字段少 |
| 电影 / 剧集 | 优酷 / 爱奇艺 | 📋 待实现 | 搜索接口免密钥；字段偏少 |
| 图书 | 微信读书 | 📋 待实现 | `weread.qq.com/web/search/global`，免密钥 |
| 漫画 | —— | 🔍 待调研 | B 站漫画（code 99）、快看（404）已实测失败 |

已实测**不可用**（勿再尝试）：猫眼（302）· B 站主站（412）· 腾讯视频搜索（仅 HTML）· 芒果 TV（401）· RSSHub 公共实例（403 Cloudflare）· 动漫之家（不可达）。

## 7. 里程碑

| 里程碑 | 内容 | 状态 |
|--------|------|:----:|
| **M0** 开工就绪度核验 | 克隆 fork，跑通四道 CI 关卡，摸清 Windows 环境坑 | ✅ 2026-09-18 |
| **M1** 首个国内源落地 | Bangumi 全链路（搜索 / 浏览 / 详情 / 四类筛选 / 排序 / 解析 / 测试 / 在线验证） | ✅ 2026-09-18 |
| **M2** 影视线 | 豆瓣（先补 403 退避）+ 优酷 / 爱奇艺 | 📋 下一步候选 |
| **M3** 图书线 | 微信读书 + 豆瓣 ISBN 直查 | 📋 |
| **M4** 漫画线 | 待确定可行路径后立项 | 🔍 |
| **M5** 发布 | Windows / Android / Web 打包与分发 | 📋 |

## 8. 关键决策记录

- **ADR-1 · 选择 fork 而非重写。** 上游已积累 22 个搜索源、完整导入器体系与迁移链，重写等于放弃这些资产。fork 的代价是同步成本，用第 3 节的策略压低。
- **ADR-2 · 首个源选 Bangumi。** 免密钥、契约稳定（v0 有正式文档）、元数据中文、Cloudflare 只需一个真实 UA 即可通过 —— 是验证"加源流程"的最低风险样本。豆瓣元数据更全，但签名 + 403 退避会同时引入两个未验证变量，故排在后面。
- **ADR-3 · 免密钥源优先。** 需要注册或付费的源在 MVP 阶段一律不做，避免把用户挡在密钥申请之外。
- **ADR-4 · 文档语言边界。** 面向用户与协作者的文档（`README.md`、`PROJECT.md`、`TASK.md`、`RULES.md`）用中文；代码注释、提交信息、以及与上游逐行同步的专题文档（`docs/`、`server/`）保持英文，以便与上游对照和合并。
- **ADR-5 · `createApiDio` 是唯一 HTTP 出口。** 不为自己接的源自建 `Dio`，否则 Web 端的代理重写会漏掉它。
- **ADR-6 · 不引入配置开关来隐藏国内源。** 国内源与上游源一视同仁地出现在源列表里，用户按需选择；不做"区域自动切换"这类隐式行为。

## 9. 什么算做完了

一个数据源的"完成"不是"能返回结果"，而是以下全部成立：

1. `flutter analyze --fatal-infos --fatal-warnings` 无输出。
2. 四道测试关卡全绿（应用 / `packages/core` / `server`；另加 RPC 生成物无漂移）。
3. 新源有单元测试：解析器（字段映射、缺字段、边界）、API 客户端（分页、筛选参数、错误映射）、源本身（参数转发、排序、页码）。
4. **在线活体验证**：真实网络响应穿过完整链路，且逐项核对过标题、评分标度、日期、分类、外链等关键字段。不允许以"测试通过"代替。
5. 加源引爆的既有护栏已同步更新（见 [`RULES.md`](RULES.md) 护栏章节）。
6. 文档同步：本文件第 6 节的矩阵状态、[`TASK.md`](TASK.md) 的任务状态、[`CHANGELOG.md`](CHANGELOG.md) 的条目。

## 10. 环境要求与已知限制

- **Windows 是本分支的开发环境。** Flutter 命令直接在本机执行，无 WSL 中转。
- **`flutter run -d windows` 当前不可用**：缺 Visual Studio C++ 工作负载，且插件符号链接创建受限。**写码、分析、测试均不受影响**；Android（SDK 36.1.0 / JDK 21）与 Web（Chrome）工具链齐备。
- 四个会把环境问题伪装成代码问题的坑（代理打死测试、子包依赖、桌面构建、并发测试）逐条记在 [`RULES.md`](RULES.md)。
- 上游没有为"新增数据源"预留插件机制，加源必然触碰第 3 节列出的那几处上游文件 —— 这是设计使然，不是可绕过的。
