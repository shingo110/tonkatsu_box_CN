# TASK.md — 任务清单

活的待办清单。条目随状态变化更新：完成的移到「✅ 已完成」，开始做的标"进行中"，未立项的留在「📋 候选」。**"完成"的定义见 [`PROJECT.md`](PROJECT.md) 第 9 节** —— 测试通过不算数，必须在线验证过关键字段才算。

## 状态

- **已完成**：M0 开工就绪度核验 · M1 Bangumi 全链路接入 · M2 NeoDB 图书接入 · M3 NeoDB 电影 / 剧集接入
- **进行中**：无
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

### D3 · 项目文档补齐（2026-09-18）

新增/重写：`README.md`（fork 中文门面）、`PROJECT.md`（全景）、`TASK.md`（本文件）、`RULES.md`（规约 + 坑点）、`CHANGELOG.md`（fork 条目）；修正 `docs/CONTRIBUTING.md` 与 `.claude/CLAUDE.md` 残留的 WSL 壳与过时计数。

验收：全部文档引用路径经 `git ls-files` 核验存在；analyze 仍全绿；无上游内容被误删。

### D4 · NeoDB 图书接入（2026-09-20，第二个国内源）

图书数据源，联邦宇宙中文目录，免密钥。排在全部图书源之前，是图书类型的**主源**。

**改动面**：

- 模型：`DataSource.neodb` 枚举 + `Book.fromNeoDBItem` 解析器（`packages/core/lib/models/`）
- 注册面：`data_source_ui.dart` · `source_catalog.dart` · `search_sources.dart`（**排在 OpenLibrary 之前** —— 注册顺序即主源/备源，中文用户应默认拿到中文结果）
- API 三件套 + facade：`lib/core/api/neodb/{types,http_client,search_api}.dart` + `neodb_api.dart`
- 源实现：`lib/features/search/sources/neodb_book_source.dart`（id `neodb`，无筛选器、单排序项）
- Web + 限流：`proxy_targets.dart` 加 `neodb('neodb.social')`；`proxy_handler.dart` 免密钥分支；`kHostMinRequestGap` 加 250ms 礼貌间隔
- 本地化：6 语言 ARB × 1 键（`welcomeSourceDescNeoDB`），各语言 1744 键齐平

**连带必修（漏了会静默失效，不报错）**：

- `lib/features/collections/helpers/collection_actions.dart` —— 图书刷新是 `if/else if` 链，不加分支就落到 `unsupported`
- `lib/features/search/handlers/media_handlers.dart`（`_fetchFullBook`）—— 不加 case 则详情页无简介
- `lib/core/services/import_service.dart`（`_fetchOneBook` + 构造注入 + provider watch）—— 不加则 `.xcoll` 导入丢条目
- `lib/features/welcome/widgets/welcome_step_sources.dart` —— 不加则向导里描述为空串

**验收记录**：

- [x] `flutter analyze --fatal-infos --fatal-warnings`：No issues found
- [x] `dart test`（packages/core）：2256 通过（基线 2224 + 32 解析器用例）
- [x] `dart test`（server）：98 通过
- [x] RPC 生成物 `git diff --exit-code`：字节一致
- [x] **在线活体验证**：「三体」→ 6 条 / 6 页；首条 `authors=[刘慈欣]`（英文重复名已剥除）、`rating=8.6`（未乘 2）、`pages=302`（字符串转数字）、ISBN-13、出版社、中文标签、豆瓣外链全部落地；第 2 页 11 条；短查询（1 字）不发请求
- [x] 既有护栏同步：`source_badge_test` 20→21 · `search_sources_test` id 表补 `neodb` · `source_output_media_type_test` 补一条
- [x] `browse_provider_test` 无需改（图书走 `textQueryOnly`，无按源浏览计数断言）
- [ ] **未做**：Web 端 `/proxy/neodb/**` 在线验证（同 Bangumi，需自托管环境）

**本轮探测推翻的两条旧结论**（上一轮凭记忆写的，已被实测订正）：

- ~~「NeoDB 需要自定义 User-Agent（Cloudflare 前置）」~~ → **错**。默认 UA、空 UA 均返回 200；与 Bangumi 的 403 完全是两回事。
- ~~「rating 0–10，×10 映射到模型」~~ → **错**。`Book` 模型就是 0–10 刻度，NeoDB 的 8.6 **直接使用**；×2 只适用于 OpenLibrary / Google Books / Hardcover 那类 0–5 刻度源。

**实测补充**：无 `query` → 422、空串 → 400，故**不支持空关键词浏览**（与 Bangumi 不同）；分页每页条数不规则（1/2/3 页分别 6/11/19 条），只能用 `pages` 字段判页；详情端点是 `/api/book/{uuid}`（按类目分流，非 `/api/catalog/item/`）。

---

## 📋 候选（下一步从这里挑）

> 接入优先序共识：**Bangumi ✅ > NeoDB 图书 ✅ > NeoDB 影视 > 微信读书 > 优酷/爱奇艺 > 豆瓣**。豆瓣元数据最全但引入签名 + 403 两个新变量，且 NeoDB 已是豆瓣数据的免密钥代理，故排在最后。

### T1 · 豆瓣 403 退避（可推迟，见 T2）

> **2026-09-19 更新**：NeoDB 已是豆瓣数据的免密钥代理（见 T2），本任务不再是任何工作的前置，仅在需要豆瓣**独有数据**（短评、想看人数、精确剧集排期）时才值得做。

- 现状：`lib/core/api/host_rate_limiter.dart` 只做「按主机 FIFO + 最小间隔」，**不处理 403 封禁**；表内仅 `musicbrainz.org`、`coverartarchive.org` 两项。
- 要做的：为豆瓣主机加「连打 N 次 → 冷却 M 分钟」的退避策略；接在「FIFO 间隔」之后，402/429/403 触发冷却；冷却期内请求直接失败并给出用户可读提示。
- 验收：模拟 10 连击后第 11 次被冷却；冷却期间请求不发出网；冷却结束自动恢复。带单测。

### T2 · NeoDB 扩电影 / 剧集（✅ 2026-09-20 完成 → M3）

图书类目已于 D4 落地，客户端、代理白名单、限流条目都是现成的，扩一个类目的边际成本只剩模型映射与筛选器。

**落地结果**：类目常量扩为 book / movie / tv；`NeoDBSearchApi` 的解析泛型化（`search<T>` / `getItem<T>`），`NeoDBApi` 新增 `searchMovies` / `searchTvShows` / `getMovieById` / `getTvShowById`；`Movie.fromNeoDBItem` 与 `TvShow.fromNeoDBItem` 落地，解析逻辑抽到 `packages/core/lib/utils/neodb_json.dart` 供三类共用（`book.dart` 的私有 helper 一并改为委托）；新源 `neodb_movie` / `neodb_tv` 注册在可浏览的 TMDB / TheTVDB **之后**（搜索型源不做主源）。**剧集以「季」为粒度**（`category=tv` 只返回 `TVSeason`），刷新用 `externalUrl` 反解 uuid。文档侧：`kDataSourceCatalog` 的 NeoDB 补 movie / tvShow。

**实测契约（2026-09-19 二轮探测 + D4 落地时复核）**：

- **六大类目全通**：book / movie / tv / music / game / podcast；换 `category` 参数即可复用 `NeoDBSearchApi.search<T>`。
- **它是豆瓣数据的免密钥代理**：`external_resources` 挂 `book.douban.com` / `movie.douban.com`，中文简介与 tags 带豆瓣血统。→ T1（豆瓣签名 + 403 退避）可整体推迟。
- **不要求自定义 UA**（实测默认 UA / 空 UA 均 200），与 Bangumi 的 Cloudflare 403 相反。
- **无限流**：25 连打 0 个非 200，延迟中位数 770ms → 已加 250ms 礼貌间隔即可，无需退避。
- **头号陷阱**：`localized_title` / `localized_description` 是 **`[{lang, text}]` 数组**，须挑 `zh-cn`（fallback `zh-hans → zh-hant → zh-tw → zh`）。且 `display_title` 对**影视 / 游戏是英文名**（`The Wandering Earth` / `Black Myth: Wukong`），中文原名在 `orig_title` —— 不可直接拿 `display_title` 充标题。图书类目的 `display_title` 才是中文，别被它骗过。
- **不支持空关键词浏览**：无 `query` → 422，空串 → 400。影视源也一样只能搜索。
- **详情端点按类目分流**：`/api/{category}/{uuid}`，例如 `/api/book/{uuid}`、`/api/movie/{uuid}`。`/api/catalog/item/{uuid}` 是 404。
- 剧集详情带 `episode_count` / `episode_uuids`，可做剧集列表。

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
| B2 | Web 端 /proxy 全链路验证 | 白名单已加 `api.bgm.tv` 与 `neodb.social`，均未做真实自托管 + 浏览器链路验证 | 发布 Web 前必须补 |
| B3 | 上游同步 | fork 基线 0.44.0；上游以周为节奏发版 | 每次同步人造裁决冲突清单见 PROJECT.md §3 |
| B4 | 中文数据源覆盖 | 动画 ✅；图书 ✅；电影/剧集候选排期中；漫画未定 | 尽快先取 T2（NeoDB 影视）缩小空白 |

## 护栏速查（改代码前看一眼，防炸）

1. `test/shared/widgets/source_badge_test.dart` —— `DataSource.values.length` 硬编码（现 21），加枚举即炸。。
2. `test/features/search/providers/browse_provider_test.dart` —— 该媒体可浏览源数硬编码，加源即炸。
3. `test/features/search/sources/search_sources_test.dart` —— 注册表 id 顺序表，加源须补序。
4. RPC：改 DAO/模型 → `dart run tool/generate_rpc.dart` → 提交生成物，否则 `dart test` 必挂，无幸免。
5. mocktail 断言命名参数：**不要用 `verify(...).captured` 按位取**（顺序无保证），在 `thenAnswer` 里按 `Symbol('x')` 取。
6. **同一条消息里对同一个文件不要发两次编辑** —— 实测最多只有一次生效，其余静默丢失且不报错。改完同一文件的多处，务必拆成多次调用并逐处 grep 复核。