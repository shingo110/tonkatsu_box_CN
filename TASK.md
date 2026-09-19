# TASK.md — 任务清单

活的待办清单。条目随状态变化更新：完成的移到「✅ 已完成」，开始做的标"进行中"，未立项的留在「📋 候选」。**"完成"的定义见 [`PROJECT.md`](PROJECT.md) 第 9 节** —— 测试通过不算数，必须在线验证过关键字段才算。

## 状态

- **已完成**：M0 开工就绪度核验 · M1 Bangumi 全链路接入
- **进行中**：文档补齐（本轮）
- **进行中（阻塞）**：Windows 桌面构建可用性（缺 VS C++ 工作负载）

---

## ✅ 已完成

### D1 · 开工就绪度核验（2026-09-18）

克隆 fork → 跑通四道 CI 关卡 → 摸清 Windows 环境坑。产出：`fork开工就绪度评估.md`、技能 `flutter-fork-onboarding`。

验收：analyze / flutter test / dart test（core） / dart test（server）全绿；四类环境坑找到根因并有规避命令。

### D2 · Bangumi 全链路接入（2026-09-18，首个国内源样板）

动画数据源，免密钥，中文标题与标签。

**改动面（新增为主，7 处大块）**：

- 模型：`DataSource` 枚举 + `Anime.fromBangumi` 解析器（`packages/core/lib/models/`）
- 注册面：`data_source_ui.dart`（图标 switch）· `source_catalog.dart`（SourceInfo）· `search_sources.dart`（实例，注册在 AniList 之后）
- API 三件套 + facade：`lib/core/api/bangumi/{types,http_client,search_api}.dart` + `bangumi_api.dart`
- 源实现：`lib/features/search/sources/bangumi_anime_source.dart`（id `bangumi_anime`）
- 专属筛选器：`bangumi_meta_tag_filter.dart` · `bangumi_rank_filter.dart`
- Web：`packages/core/lib/api/proxy_targets.dart` 加 `bangumi('api.bgm.tv')`；`server/lib/src/proxy_handler.dart` `_authorize` 加免密钥分支
- 本地化：6 语言 ARB × 3 键（`welcomeSourceDescBangumi` / `browseFilterCategory` / `browseFilterMaxRank`），各语言 1743 键齐平

**连带必修（漏了会串源）**：

- `lib/features/collections/helpers/collection_actions.dart` —— anime 刷新 switch 须分流 Bangumi id 到 `getAnimeById`
- `lib/features/collections/widgets/anime_similars_section.dart` —— 穷尽 switch，非 anilist/kitsu 源返回 null（Bangumi 无相似推荐端点）

**验收记录**：

- [x] `flutter analyze --fatal-infos --fatal-warnings`：No issues found
- [x] `flutter test`：5513 通过 / 3 跳过 / 0 失败
- [x] `dart test`（packages/core）：2224 通过（基线 2189 + 35 解析器用例）
- [x] `dart test`（server）：98 通过
- [x] RPC 生成物 `git diff --exit-code`：字节一致
- [x] **在线活体验证**：关键词「巨人」→ 20 条 / 4 页；`metaTags:[TV] + 2013 + ≥8.0 + rank≤500 + sort=rank` → 7 条全中；详情解析出 `studios=[東京ムービー]`
- [x] 既有护栏同步：`source_badge_test` 19→20 · `browse_provider_test` anime 可浏览源 2→3 · `search_sources_test` id 表补 `bangumi_anime`
- [x] 新护栏：源层测试按名捕获 API 参数（规避 mocktail `captured` 顺序无保证），并校验命名参数超集
- [ ] **未做**：Web 端 `/proxy/bangumi/**` 在线验证（需自托管环境）；Bangumi 频控上限摸查（连打 30 次全 200，未探到上限）

---

## 🔄 进行中

### D3 · 项目文档补齐（当前）

新增/重写：`README.md`（fork 中文门面）、`PROJECT.md`（全景）、`TASK.md`（本文件）、`RULES.md`（规约 + 坑点）、`CHANGELOG.md`（fork 条目）；修正 `docs/CONTRIBUTING.md` 与 `.claude/CLAUDE.md` 残留的 WSL 壳与过时计数。

验收：全部文档引用路径经 `git ls-files` 核验存在；analyze 仍全绿；无上游内容被误删。

---

## 📋 候选（下一步从这里挑）

> 接入优先序共识：**Bangumi > NeoDB > 微信读书 > 优酷/爱奇艺 > 豆瓣**。豆瓣元数据最全但引入签名 + 403 两个新变量，建议在低风险源（NeoDB / 微信读书）验证过流程后最后碰。

### T1 · 豆瓣 403 退避（可推迟，见 T2）

> **2026-09-19 更新**：NeoDB 已是豆瓣数据的免密钥代理（见 T2），本任务不再是任何工作的前置，仅在需要豆瓣**独有数据**（短评、想看人数、精确剧集排期）时才值得做。

- 现状：`lib/core/api/host_rate_limiter.dart` 只做「按主机 FIFO + 最小间隔」，**不处理 403 封禁**；表内仅 `musicbrainz.org`、`coverartarchive.org` 两项。
- 要做的：为豆瓣主机加「连打 N 次 → 冷却 M 分钟」的退避策略；接在「FIFO 间隔」之后，402/429/403 触发冷却；冷却期内请求直接失败并给出用户可读提示。
- 验收：模拟 10 连击后第 11 次被冷却；冷却期间请求不发出网；冷却结束自动恢复。带单测。

### T2. NeoDB 图书 + 影视（**推荐下一个开工**，2026-09-19 已实测）

已二轮真接口探测（`probe/neodb_catalog_probe.py` / `neodb_localization_probe.py`），结论如下：

- **六大类目全通**：book / movie / tv / music / game / podcast 全部 200；UA 必填（Cloudflare 前置）。一个源覆盖六种媒体，边际收益远高于单一媒体源。
- **它本质是豆瓣数据的免密钥代理**：`external_resources` 挂 `book.douban.com` / `movie.douban.com`，中文简介与 tags（「中国电影」「中国当代文学」）带豆瓣血统。→ **T1（豆瓣签名 + 403 退避）可整体推迟**。
- **rating 0–10**，与 Bangumi 一致，×10 映射到模型。
- **头号陷阱**：`localized_title` / `localized_description` 是 **`[{lang, text}]` 数组**，须挑 `zh-cn`（fallback `zh-hans → zh → zh-tw`）。且 `display_title` 对**影视/游戏是英文名**（`The Wandering Earth`），中文原名在 `orig_title` —— 不可直接拿 `display_title` 充标题。
- **无限流**：25 连打全 200、0 非 200；延迟中位数 770ms → 加 200–300ms 礼貌节流即可，无需退避。
- 详情 37–40 字段：剧集带 `episode_count` / `episode_uuids`（可做剧集列表）；全类目带 `tags` / `rating_count` / `rating_distribution`。

**实施建议（分批，勿一次做 6 个类目）**：

1. 先做 **图书**（缺口最大，现有 OpenLibrary 是弱覆盖；本地化数组解析的新逻辑先在此跑通）
2. 跑通后扩 **电影 / 剧集**（复用同一套客户端，仅模型与筛选器不同）
3. music / game / podcast 视需求再上

验收：标准七步 + 本地化数组解析单测（含 zh-cn 缺失时的 fallback）+ 在线活体验证（中文标题务必是真中文，不得是英文 `display_title`）。

### T3. 图书线：微信读书 + 豆瓣 ISBN

- 微信读书：`weread.qq.com/web/search/global`（已实测可用，中文书目覆盖好，免密钥）。
- 豆瓣 ISBN：以 ISBN 直查，无需签名；与微信读书互为补充（豆瓣有评分/页数，微信读书有阅读条目）。
- 候选面：新增 `Book` 模型解析 + 两个源（或一个源双后端）。
- 验收：ISBN 精确命中返回对应中文图书；关键词搜索中文书名无乱码；在线验证。

### T4. 影视线：优酷 / 爱奇艺

- 均已实测搜索接口可用、免密钥，但字段偏少（无演员/简介级别元数据）—— 适合做「列表 + 海报 + 链接」，不适合做详情主源。
- 验收：关键词搜索返回中文标题与海报；详情缺失字段时无异常、字段留空。

### T5. 漫画线调研

- 已实测失败：B 站漫画（code 99）· 快看（404）· 动漫之家（不可达）。
- 候选路径：NeoDB 覆盖漫画条目；或爬自有公开 API 的中文漫画库（如 `ggzy` 系开源代理，需先验合规与稳定性）。
- 验收：找到免密钥可直连 5 秒内响应的候选再立项。

---

## 🔧 阻塞与长期债

| # | 事项 | 现状 | 影响 |
|:-:|------|------|------|
| B1 | Windows 桌面运行 | 缺 Visual Studio C++ 工作负载 + 插件符号链接受限 → `flutter run -d windows` 不可用 | 无法桌面预览；写码/分析/测试不受影响 |
| B2 | Web 端 /proxy 全链路验证 | 白名单已加 `api.bgm.tv`，但未在真实自托管 + 浏览器链路验证 | 发布 Web 前必须补 |
| B3 | 上游同步 | fork 基线 0.44.0；上游以周为节奏发版 | 每次同步人造裁决冲突清单见 PROJECT.md §3 |
| B4 | 中文数据源覆盖 | 动画 ✅；电影/剧集/图书候选排期中；漫画未定 | 尽快先取 T3/T4 之一缩小空白 |

## 护栏速查（改代码前看一眼，防炸）

1. `test/shared/widgets/source_badge_test.dart` —— `DataSource.values.length` 硬编码，加枚举即炸。
2. `test/features/search/providers/browse_provider_test.dart` —— 该媒体可浏览源数硬编码，加源即炸。
3. `test/features/search/sources/search_sources_test.dart` —— 注册表 id 顺序表，加源须补序。
4. RPC：改 DAO/模型 → `dart run tool/generate_rpc.dart` → 提交生成物，否则 `dart test` 必挂，无幸免。
5. mocktail 断言命名参数：**不要用 `verify(...).captured` 按位取**（顺序无保证），在 `thenAnswer` 里按 `Symbol('x')` 取。