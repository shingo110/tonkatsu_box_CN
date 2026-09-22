# TASK.md — 任务清单

活的待办清单。条目随状态变化更新：完成的移到「✅ 已完成」，开始做的标"进行中"，未立项的留在「📋 候选」。**"完成"的定义见 [`PROJECT.md`](PROJECT.md) 第 9 节** —— 测试通过不算数，必须在线验证过关键字段才算。

## 状态

- **已完成**：D1–D24 全部收口 —— M0 开工就绪度核验；**十一个国内源**（Bangumi 动画 / NeoDB 图书 / NeoDB 影视 / 微信读书 / 豆瓣图书 / 豆瓣影视 / Bangumi 漫画 / 豆瓣动画 / 豆瓣音乐 / TapTap 游戏 / 喜马拉雅播客）；自托管 `/proxy` 全链路验证（B2 闭环）；源区域维度与连通性自检（D15）；**M7 三端打包与发布流水线（D20）**；明文凭据审计（D21）；**游戏库两条导入路径**（D22 粘贴名单 / **D23 PSN 登录导入**）；**D24 PSN 导入真机修正**（CSRF 闸门 · 「查看」弹窗误关页面 · 库补齐「玩过」一半）
- **进行中**：无
- **进行中（阻塞）**：Windows 桌面**本地**构建（缺 VS C++ 工作负载）—— 但发布走 CI 的 `windows-2022` 运行器，不阻塞出包

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

### D5 · 微信读书接入（2026-09-20，第三个国内源）

中文电子书与网文商店，免密钥，**仅搜索**（无 by-id 详情端点）。排列在 NeoDB 之后、OpenLibrary 之前 —— 中文书目优先于海外目录。

**改动面**：

- 模型：`DataSource.weread` 枚举 + `Book.fromWeReadItem`（`packages/core/lib/models/book.dart`）
- 注册面：`data_source_ui.dart`（无品牌资源 → `null`，回落 `Icons.local_library`）· `source_catalog.dart` · `search_sources.dart`
- API 三件套 + facade：`lib/core/api/weread/{types,http_client,search_api}.dart` + `weread_api.dart`
- 源实现：`lib/features/search/sources/weread_book_source.dart`（id `weread`，无筛选器、单排序项）
- Web + 限流：`proxy_targets.dart` 加 `weread('weread.qq.com')`；`proxy_handler.dart` 免密钥分支；`kHostMinRequestGap` 加 200ms
- 本地化：6 语言 ARB × 1 键（`welcomeSourceDescWeRead`）

**连带必修（漏了会静默失效，不报错）**：

- `collection_actions.dart` —— 图书刷新 `if/else if` 链加 `weread` 分支（按标题重搜 + 匹配 bookId）
- `media_handlers.dart`（`_fetchFullBook`）—— 加 `DataSource.weread` case
- `import_service.dart` —— 显式 case 注明「导出不含标题，无从重搜」，**不注入 API**（注入了也无处可用，会触发 `unused_field`）

**验收记录**：

- [x] `flutter analyze --fatal-infos --fatal-warnings`：No issues found
- [x] `flutter test`：**5591 通过 / 3 跳过 / 0 失败**（基线 5566，+25）
- [x] `dart test`（packages/core）：**2323 通过**（基线 2309，+14）
- [x] `dart test`（server）：98 通过
- [x] RPC 生成物 `git diff --exit-code`：字节一致（未改模型字段）
- [x] **在线活体验证**：「三体」→ 20 条、`hasMore=true`、`totalPages=2`；首条「三体全集（全三册）」/ `authors=[刘慈欣]` / `rating=9.3`（930÷100）/ `publishers=[重庆出版社]` / deepLink 外链；第 2 页首条换书（印证 `maxIdx` 有效）；按标题重搜回填 `sameId=true`；空关键词 → 0 条、`hasMore=false`
- [x] 既有护栏同步：`source_badge_test` 21→22 · `search_sources_test` id 表补 `weread` · `source_output_media_type_test` 补一条 · `mocks.dart` 补 `MockWeReadApi`
- [ ] **未做**：Web 端 `/proxy/weread/**` 在线验证（需自托管环境）

**探测阶段推翻的一条自造结论**：一度以为「微信读书要求浏览器 UA」（空 UA 返回 0 字节）。复测发现是**探测时走了沙箱代理**导致的偶发空体 —— 直连后 Chrome UA / 应用 UA / 空 UA **三者都返回 6303 字节**。**教训：探测网络接口必须按 P1 的规矩先清 `HTTP_PROXY` 等变量**，否则会把代理噪声当成服务端行为。

### D6 · 豆瓣 403 退避（2026-09-20，为接豆瓣筑的护城河）

豆瓣实测「十连打即 403、冷却 3–5 分钟」，而原有 `host_rate_limiter.dart` 只做间隔、不认封禁 —— 一跑 ISBN 列表就会撞墙。本轮补上「连打 N 次 → 冷却 M 分钟」的断路器。

**改动面**（单文件为主）：`lib/core/api/host_rate_limiter.dart` —— 新增 `HostBackoffPolicy(maxBurst, cooldown)` 与 `kHostBackoffPolicy` 表、`HostCooldownException`；`HostRateLimiter` 加 burst 计数与冷却拒绝；查表改为「精确 → 逐级父域」并**按命中表键缓存**（同域子站共用一份预算）；`HostRateLimitInterceptor` 加 `onError`，402/403/429 触发 `recordRefusal`。另：`kHostMinRequestGap` 补 `douban.com: 800ms`；`extractApiError` 注册该异常类型。

**验收记录**：

- [x] `flutter analyze --fatal-infos --fatal-warnings`：No issues found
- [x] `test/core/api/host_rate_limiter_test.dart`：**18 通过**（原 5 + 新 13）
- [x] `test/core/api/api_error_extract_test.dart`：**5 通过**（+1）
- [x] 10 连击后第 11 次抛 `HostCooldownException` —— 验收原文逐条对应
- [x] 冷却期间**不发网**：拦截器在 `onRequest` 直接 `handler.reject`，无 adapter 参与
- [x] 冷却结束**自动恢复**：`cooldown` 到期后 `acquire()` 正常返回
- [x] 被拒的调用**不污染 FIFO 队列**：连续两次被拒，第二次仍按自己的判断拒绝，而非继承上一个异常
- [x] **域级共享**：`frodo` / `book` / `movie` 三个子域返回同一实例、同一预算
- [x] 被动开闸：403 响应使下一次请求被冷却；500 不触发
- [ ] **未做**：真实豆瓣接口的活体验证（须先有豆瓣源；且活体验证本身会消耗封禁额度，宜随 ISBN 源一并做）

**已知折衷（已记入 RULES §七之五）**：冷却文案挂在 `DioException.error` 上，但各源的 `handleDioException` 会把 DioException 包成自家异常并套通用措辞（全仓 112 处 `on DioException catch`），故**既有源**的用户主文案仍是通用措辞，精确原因落在「详情」面板的 `Cause:` 行。**新写的豆瓣源须在自己的 `handleDioException` 里优先判 `e.error is HostCooldownException` 并采用其文案。**

### D7 · 豆瓣 ISBN 直查接入（2026-09-20，第四个国内源 · 首个需密钥源）

豆瓣 Frodo 的签名图书接口。**双后端单源**：查询词形如 ISBN（去连字符后 10 / 13 位）时走 `/api/v2/book/isbn/{isbn}`，否则走 `/api/v2/search/book`。后者不只是功能之别 —— 单后端会让每次关键词搜索都白发一发到易封主机。凭据由用户自填，源码不内置（照 RA / ComicVine / Hardcover / Google Books 范式）。

**改动面**：

- 签名与常量：`packages/core/lib/api/douban_signature.dart`（HMAC-SHA1；放 core 而非 lib，因为**自托管服务端要用同一份**）· `douban_constants.dart`
- API：`lib/core/api/douban/{douban_types,douban_http_client,douban_search_api}.dart` + `lib/core/api/douban_api.dart`（facade + `doubanApiProvider`）
- 模型：`DataSource.douban` 枚举 + `Book.fromDoubanItem`
- 源实现：`lib/features/search/sources/douban_book_source.dart`（id `douban`，无筛选器、`supportsBrowse=false`）
- 注册面：`data_source_ui.dart` · `source_catalog.dart`（`keyRequirement: mandatory`）· `search_sources.dart`（排在 NeoDB 之后、微信读书之前）
- 凭据：`api_key_initializer.dart` · `settings_provider.dart`（`SettingsKeys` / `hasDoubanKeys` / `setDoubanKeys` / `validateDoubanKeys`）· `credentials_content.dart`（key + secret + 「测试」动作）
- Web：`proxy_targets.dart` 加 `douban('frodo.douban.com')` · `credential_names.dart` · `server_credentials.dart` · `proxy_handler.dart` 的 `_authorize` 加**服务端签名**分支（签 `/$path` + 补 Frodo UA）
- 本地化：6 语言 ARB × 7 键（6 凭据键 + `welcomeSourceDescDouban`），各语言 **1752** 条

**连带必修（漏了会静默失效，不报错）**：`collection_actions.dart`（刷新分派）· `media_handlers.dart`（`_fetchFullBook`）· `import_service.dart`（`_fetchOneBook` + 注入；豆瓣**有** by-id，可解析，与微信读书相反）· `welcome_step_sources.dart` · `api_error_extract.dart`

**验收记录**：

- [x] `flutter analyze --fatal-infos --fatal-warnings`：No issues found
- [x] `flutter test`：**5639 通过 / 3 跳过 / 0 失败**
- [x] `dart test`（packages/core）：**2340 通过**（基线 2323，+17 = 签名 6 + 解析 11）
- [x] `dart test`（server）：**99 通过**（+1）
- [x] RPC 生成物 `git diff --exit-code`：字节一致（未改模型字段）
- [x] 新增测试：`douban_signature_test` 6（与 Python 参考向量**逐字节锁定**）· `book_douban_test` 11 · `douban_api_test` 21 · `douban_book_source_test` 10 · `proxy_handler_test` 的**服务端验签**用例 1（断言 `_sig` 恰为参考向量 `g9+l253xM80riZQoEdnRsPFqgAs=`）
- [x] **在线活体验证**（4 发全 200，压在 10 发以内）：ISBN-13 `9787536692930` → 6042 字节 / `id=36892731` / `三体` / `authors=[刘慈欣]` / `rating=9.4`（**未翻倍**）/ `publishers=[重庆出版社]`（**`press` 生效**）/ `pages=300` / `year=2021` / 外链正确；ISBN-10 `7536692935` → **同一 subject id**；关键词「三体」第 1 页 → 200 / 11086 字节 / **解析 20 条** / `total=269` / `hasMore=true`（中文标题无乱码）；第 2 页 → 首条换书（`三体 2`，id 35092666），**分页有效**。注：响应 `tags` 是空数组、搜索行**根本没有 `tags` 字段** ⇒ `subjects` 为空是**正确行为**，非缺陷。
- [x] 既有护栏同步：`source_badge_test` 22→**23** · **`source_catalog_test` 的密钥集合加 `douban`**（第五处硬编码护栏，本轮才编目）· `search_sources_test` id 表 · `source_output_media_type_test` · `mocks.dart` 补 `MockDoubanApi`
- [ ] **未做**：Web 端 `/proxy/douban/**` 的真实自托管在线验证（需自托管环境；**服务端签名逻辑已有单测钉死**，见上）

**探测阶段推翻的自造结论**：曾按详情端点的形状推断搜索响应顶层键是 `books`，实测是 **`items`**，且每条把记录包在 `target` 下、作者 / 年份 / 出版社被压成 `card_subtitle` 单串。只按详情形状写解析 ⇒ **搜索结果全空且不报任何错**。

---

### D8 · 豆瓣电影与剧集接入（2026-09-20，第五、六个国内源）

豆瓣线的后半段。签名客户端、凭据存储、Web 端服务端签名、403 断路器全是 D6 / D7 现成的，本轮只加两个源与它们的解析。

**要点**：`douban_movie` / `douban_tv` 共享 `DataSource.douban`（与图书源同枚举值 ⇒ 凭据页与向导文案零新增键），但各自 `outputMediaType`、各自注册顺序，排在 keyless 的 NeoDB 影视源之后。

**本轮实证（七发，`probe/douban_movie_probe.py` + `douban_movie_type_probe.py`）**：

- **`/api/v2/search/movie` 是电影与剧集的混合池，`type` 参数无效。** 同一查询分别带 `type=movie`、不带 `type`、带 `type=tv`，**三次响应逐字节相同**且都是混排（`total` 都是 27）。分流只能按每行的 `target_type`（`movie` / `tv`）自己做。
- 搜索行 `target` 字段：`abstract` / `card_subtitle` / `cover_url` / `has_linewatch` / `id` / `rating` / `title` / `uri` / `year`（**有 `year`**，图书没有）。
- **`card_subtitle` 两种形状**：搜索行 `"中国大陆 / 科幻 冒险 灾难 / 郭帆 / 吴京 刘德华"`，详情记录多一个前导年份 `"2023 / 中国大陆 / …"` ⇒ 取类型要按形状判槽位。
- **详情路径分道**：电影 `/api/v2/movie/{id}`、剧集 `/api/v2/tv/{id}`（剧集送 `/movie/` 回 996）。响应 73 字段，`subtype` / `type` 标 `movie` / `tv`；剧集 `episodes_count: 39`；`first_air_time` **实测为 null**，年份取 `year`。
- `rating.value` 已是 0–10（8.3 / 8.5），**不可倍乘**；`durations` 是数组取首元素。

**落地物**：`lib/core/api/douban/douban_search_api.dart` 加 `searchMovies` / `searchTvShows`（共用一条请求、按 `target_type` 过滤）与 `getMovie` / `getTvShow`；`packages/core/lib/utils/douban_json.dart`（影视共用解析 helper）；`Movie.fromDoubanItem` / `TvShow.fromDoubanItem`；两个源文件；**`lib/core/api/episode_source/douban_episode_source.dart`** 与 resolver 的一支（**不加就会静默串到 TMDB**）。

**一处已知限制**：豆瓣搜索行没有 `intro`（`abstract` 恒为空串）⇒ **电影**收藏后简介为空，需手动刷新才补全；剧集有 `TvShowCacheWarmer` 在收藏时补。

### D9 · Bangumi 漫画接入（2026-09-20，第七个国内源 · 漫画线立项并落地）

> **结论：漫画线根本不必另找数据源。** T5 曾判定「国内漫画候选全灭」（B 站漫画 code 99、快看 404、动漫之家不可达）—— 但 **Bangumi 自己就是漫画 / 轻小说类目最全的免费源**。它的**书籍类型（`type=1`）**覆盖漫画、轻小说与画集，用 **`meta_tags` 里的「漫画」** 即可切出漫画，无需任何新目录服务。

**关键实证（2 发对照，`probe/next_line_probe.py` + 存档 `probe/bangumi_manga_meta.json`）**：

- 关键词「海贼王」+ `type=1` + `meta_tags: ['漫画']` → **12 条，全为真漫画**（首条 `3510 航海王 / ONE PIECE`）。
- **同一关键词不带 meta_tags** → **174 条**，混入小说与画集，且 `tags` 为空 ⇒ **「漫画」标签是必须的，不是可选的**。
- 字段与动画**同构**（`id` / `name` / `name_cn` / `date` / `images` / `rating` / `infobox` / `tags` / `eps` / `volumes` / `meta_tags`），故解析可共用一套 helper。
- `platform` 恒为「漫画」；`eps == total_episodes`（实测 12 条全等）；`volumes` / `eps` 的 **0 表示未填写**。
- **`status` 只能靠 meta 标签推导**：Bangumi 无连载状态字段，但标签里有「连载中」/「已完结」⇒ 映射到 `RELEASING` / `FINISHED`。

**在线活体验证（5 发全 200，刻意压在 10 发以内）**：

- 「海贼王」→ **12 条，`format` 全为 `MANGA`**；首条 `3510 航海王 / ONE PIECE / 1997 / score 88 / RELEASING / authors=[尾田栄一郎]`。
- 叠加「连载中」→ **3 条，`status` 全为 `RELEASING`**（映射成立）。
- 「进击的巨人」→ 9 条，`8491 / 74 分 / FINISHED / 139 话 / 34 卷`（**章节与卷数解析正确**）。
- `/v0/subjects/3510` → `航海王 / ONE PIECE / 1997-12-24 / 88 / MANGA / RELEASING / 尾田栄一郎` + 完整简介与封面。
- **动画线回归**：「进击的巨人」动画搜索正常（`进击的巨人 / 進撃の巨人`）。

**落地物**：`bangumi_manga_source.dart`（id `bangumi_manga`）· **`Manga.fromBangumi`** · **`packages/core/lib/utils/bangumi_json.dart`**（动画 / 漫画共用，`Anime.fromBangumi` 已改委托，删掉其私有 helper）· `BangumiSearchApi.searchSubjects<T>` / `getSubject<T>` **泛型化**（`Anime` / `Manga` 共用一条请求路径）· `BangumiApi.browseManga`（把「漫画」前置进 `meta_tags`）· `BangumiMangaMetaTagFilter`（漫画自己的 meta 词表）· **`lib/features/search/utils/bangumi_filter_utils.dart`**（`airDate` / `score` / `sort` 三个转换与动画共用）。

**一处既有缺陷顺手修掉**：`import_service.dart` 的 `_fetchOneAnime` 此前**只有 Kitsu 与 AniList 两支**，Bangumi 动画经 `.xcoll` 导入时会把 id 送去 AniList 查（`collection_actions.dart` 的刷新路径早有 Bangumi 支，导入路径漏了）。本轮回齐。

**新增护栏**：`test/features/search/providers/browse_provider_test.dart` 的漫画可浏览源数 **4 → 5**，`unsupportedSourceIds` 加入 `bangumi_manga`（漫画源没有共享的 `status` 筛选器），且 `seedLoaded` 助手的 `disabledSourceIds` 必须一并补 —— 否则该源会被触发加载，「asks nobody」不再成立。

**一处已知限制**：连载中作品的顶层 `volumes` 常为 0（真实卷数只写在 infobox 的版本区，是自然语言），故`章节 / 卷数`对这类作品留空。**不去解析 infobox 的自然语言**，宁可留空也不编数据。

### D10 · B2 闭环：自托管 /proxy 全链路验证（2026-09-20）

把「Web 端所有外部请求都经服务端 `/proxy/<slug>/…`」这条链路，从「只有逐 handler 单测 + 假上游」
补到「真实自托管跑通」。分三层落地：

- **真实 socket 的集成测试**（`server/test/proxy_serve_integration_test.dart`，9 例）：真
  `shelf_io.serve` 监听 loopback、真 `HttpClient` 发起，代理的出站腿经真 socket 打到本地假上游
  （它自己也是一台真 HTTP 服务器）。覆盖：键免费 GET 双向透传且上游观测到浏览器无法自设的
  `User-Agent`、POST 体逐字节完整、重复 query 全保留、未知 slug 404 且**零外发**、缺密钥 503、调用
  方自带 `Authorization` 被剥离、豆瓣服务端签名与客户端同一向量、密钥经 socket 上传即时生效，以及
  **配了 `--web-root` 时未知上游仍返 404 而不是被静态回退成应用外壳**。
- **跨层改写往返契约**（`test/core/api/proxy_round_trip_test.dart`，8 例）：对**全部** `ProxyTarget`
  断言 host ↔ slug 双向可逆，并把「客户端改写 `/proxy/<slug><path>` → 服务端 `segments.skip(2)` 还
  原」钉成纯 Dart 不变式 —— 覆盖重复 query、百分号编码，以及 AniList 那种裸主机（上游路径为空）。
- **真实自托管活体验证**（`probe/selfhost_proxy_live.py`，7/7）：起真二进制
  （`dart run server/bin/server.dart`，全新 data-dir 建库至 v64），按浏览器形状（不带 UA）请求：
  `/health` 200；`/proxy/bangumi/v0/subjects/3510` 200 且响应体 sha256 与直连**完全相同**；Bangumi
  搜索 POST 200；`/proxy/neodb/api/catalog/search` 200 且与直连一致；豆瓣无密钥 503；未知上游 404。
  若 `build/web` 存在，同一条脚本再起一台带 `--web-root` 的实例，验证 `/` 返回真实 Web 包、客户端
  路由回退到外壳、而 `/proxy/<坏 slug>` 仍是 404。

**为什么不把活体脚本放进 CI**：它要外网、会碰上游限流（Bangumi / NeoDB 都是免费公共服务）。所以
留存的两条护栏都是**离线**的，真上游复核按需手动跑。

### D11 · 密钥界面瑕疵修复（2026-09-20，起源：少爷真机反馈"NeoDB 配置入口在哪"）

少爷在真机上找 NeoDB 的密钥配置，发现密钥界面只有豆瓣一节。查证结果：**NeoDB 免密钥，本就不该在那**
（见下），但顺着这条线查出密钥界面一批真瑕疵，一并修掉。

**免密钥源的判定链（答疑留档）**：`SourceInfo.keyRequirement` 默认 `SourceKeyRequirement.none` ⇒
界面对该源不生成输入框。而 `credentials_content.dart` 是**手写枚举**、不 import `source_catalog.dart`，
所以"界面上有没有这一节"由人手决定。NeoDB / Bangumi / WeRead 等 11 个源均为 `none`，故只在**源开关**
（`source_chips_row.dart`）与首次向导的"无需密钥"徽章（`welcomeSourcesNoKeyNeeded`）里露面。

**修掉的瑕疵（5 组）**：

1. **向导漏豆瓣分支 ⇒ 卡片整块空白**（功能 bug）：`welcome_step_sources.dart` 的 `_KeyEditor.build`
   有 igdb / tmdb / tvdb / comicVine / googleBooks / hardcover / podcastIndex 七支，**独缺
   `DataSource.douban`**，落 `default` 返回 `SizedBox.shrink()` —— 首次向导里豆瓣既无输入框也无申请
   链接，且一声不吭。
2. **向导状态徽章误判**（逻辑 bug）：`_KeyBadge._resolve` 的 `mandatory` 分支只特判 tvdb / hardcover，
   豆瓣落到 `settings.hasCredentials`（**IGDB 的凭证 flag**）⇒ 只配了 IGDB 的用户会看到豆瓣显示
   "密钥已保存"。
3. **设置页无"获取密钥"入口**（一致性）：向导每节都挂了 `_GetKeyLink(url: info.url)`，设置页一处在都
   没有 —— 而 `SourceInfo.url` 的注释明写自己正是 *"Get a key link target"*，等于声明了却半悬空。
   现让 `_buildSourceHeader` 收 `DataSource`，经 `_keyUrlFor()` 从目录取 url 渲染同一链接，两端不再
   可能漂移；豆瓣 url 同时从 `book.douban.com` 收到站根（它已覆盖三类媒体）。
4. **豆瓣节文案落后**（6 语言）：源在 D8 已扩到 图书 + 电影 + 剧集，界面仍写「豆瓣 API（书籍）」/
   *"The Chinese book catalogue"*；图标 `Icons.menu_book` 同理。标题、描述、图标全改。
5. **mandatory 源被喂了"可选"提示**：`_buildOwnKeyHint()` 的语义是"你已有内置密钥，用自己的更好"，
   却对 **hardcover**（无内置、必需）无条件显示；**TVDB** 在无内置密钥时干脆一条提示都不显示。新增
   `credentialsKeyRequiredHint`（6 语言）+ `_buildRequiredKeyHint()`，按 `keyRequirement` 分流。

**护栏补强（本轮最值钱的一环）**：`welcome_step_sources_test.dart` 原断言"向导恰好 9 个输入框"——
**它自己漏了豆瓣**，所以豆瓣静默消失时它照样绿。已改为**按 `kDataSourceCatalog` 派生**（需密钥源数
+ 双字段源数），漏源即炸；并新增 `credentials_content_key_links_test.dart` 钉住"每节都有申请链接"
（= 需密钥源数）与豆瓣节标题。

**未做（待定夺）**：豆瓣密钥无官方申请入口（官方 API 已停发），其 url 暂指站根；新接入的国内源
（豆瓣 / NeoDB / Bangumi / WeRead）**均无品牌图标**，只能吃 Material 兜底图标，待补资源。

### D12 · 豆瓣改为内置公用密钥，配置界面下线（2026-09-20，起源：少爷定夺）

D11 留下一条"未做"：豆瓣密钥**无官方申请入口**（Frodo 已停发），界面却仍要求用户填一对拿不到的密钥。
少爷定夺：**既然没得配，就内置公用密钥，并从配置界面摘掉**。

**内置的是什么**：Frodo 现存的可用密钥对，就是它自己客户端内置的那一对（公开、非我方机密，多个开源
客户端都在用）。落地在 `lib/shared/constants/douban_defaults{,_io,_web}.dart` —— 走**条件导入**而非
`kIsWeb`：Web 版返回空串，让密钥**从构造上**进不了 `main.dart.js`（还原签名交给自托管 `/proxy`）。

- `ApiDefaults.doubanApiKey / doubanApiSecret`（getter，转调上述常量）+ `hasDoubanKey`；
  `ApiKeys.fromPrefs` 按 **用户已存密钥 → 内置** 取值，且**两半一起解析**（半对无法签名），与
  PodcastIndex 同型。
- `SourceInfo.keyRequirement` 由 `mandatory` 改回默认 `none` ⇒ 设置页与向导**自动不再渲染该节**，
  徽章从"必需"变成"无需密钥"，语义也正确了。
- `credentials_content.dart` 删 `_buildDoubanSection` + 4 个字段 + 2 个方法（-108 行）；
  `welcome_step_sources.dart` 删 `_KeyEditor` 的 `case DataSource.douban` + 2 字段 + `_saveDouban` +
  `_KeyBadge` 的豆瓣分支（-54 行）。`welcomeSourceDescDouban` 改为"已内置密钥，无需配置"（6 语言）。
- **服务端**：`server/lib/src/douban_defaults.dart` 持同一对，`_authorize` 的豆瓣分支改为
  `credentials[...] ?? 内置`（**操作者配置优先**），自托管**零配置即可搜豆瓣**。刻意**不**种进
  `ApiCredentials` —— `/proxy/keys` 会把那张表回显给浏览器，种进去等于把密钥发给每个访客。

**顺手根治的同类瑕疵**：`browse_provider._keylessSourceIds()` 只认 tvdb / podcastIndex 两个**硬编码源名**，
而 Hardcover 同为 `mandatory` 且无内置 ⇒ 缺密钥时 chip 仍默认开启、照发请求吃 401。已补 Hardcover；
豆瓣则因现在恒有密钥无需入表（代码内留注释说明）。**判据**：`mandatory` 且**无内置**的源都必须在此表内。

**四关**：analyze 干净 · **5703 应用**（+1）/ **2380 core** / **110 server**（+2）· RPC 字节一致。

### D13 · 报错链路补全与「境外源」可达性认定（2026-09-21，起源：少爷真机反馈）

少爷真机搜「哈利波特」：**豆瓣出结果了**（D12 内置密钥生效），但 **NeoDB 报
`NeoDBApiException: Connection timeout (status:null)`**。查下来是**两件事叠在一起** —— 一件是环境，
一件是真 bug。

**真因一（环境，非 bug）：手机那条网络到 `neodb.social` 不通。** `neodb.social` 在 **Cloudflare**
上（`104.21.37.245` / `172.67.216.112`），少爷手机无代理 ⇒ 连接超时；同一次搜索里 **TMDB（同样境外）
也超时**，而**豆瓣（`frodo.douban.com`，解析到 `120.53.130.158` 等腾讯云 IP）正常** —— 一致的
「**境外全不通、境内通**」规律。反证：本机侧测什么都通（NeoDB 5 个实例全 200、0.84s），是因为
**这台电脑跑着 TUN 模式代理** —— 宿主机 TCP 到境外站只要 **1–28ms**（`ProxyServer=127.0.0.1:7897`，
Clash 默认口），这种延迟不可能是直连。**故本机测试不能作为「手机也能通」的依据。**

**真因二（真 bug，已修）：`extractApiError` 漏了 9 个异常类。** 它的 switch 是**手写枚举**，
而 `lib/core/api` 下有 27 个 `implements Exception` 的类，**9 个不在表里** ⇒ 全部落到兜底
`e.toString()`。这 9 个是：本次新增的 **NeoDB / Bangumi / WeRead**，以及**上游本就漏的**
Kitsu / MangaDex / MusicBrainz / Podcast Index / TheTVDB / TVMaze。少爷看到的
`NeoDBApiException: Connection timeout (status:null)` 就是这么来的 —— 内部类名与内部字段直接糊到
用户脸上，同时 `detail` 被丢（Tooltip 原本该有的 URL / Type / Cause 全空）。

- `lib/core/api/api_error_extract.dart` —— 补 9 个分支 + 9 个 facade import。
- `test/core/api/api_error_extract_test.dart` —— 用例表补 9 条；**并新增源码扫描护栏**：遍历
  `lib/core/api` 下所有 `implements Exception` 的类，缺一即红。已用「**临时抽掉 NeoDB 分支**」**证伪**
  过（两条测试确实炸），不是摆设。

**认定（重要，务必记住）**：本项目的源要分清「境内」与「境外中文站」两种 ——

| 源 | 主机 | 托管 | 无代理时 |
|---|---|---|---|
| 豆瓣 | `frodo.douban.com` | 腾讯云（境内 IP） | ✅ 可直连 |
| 微信读书 | `weread.qq.com` | 腾讯（境内） | ✅ 可直连 |
| Bangumi | `api.bgm.tv` | Cloudflare（境外） | ❌ 不稳 / 不通 |
| NeoDB | `neodb.social` | Cloudflare（境外） | ❌ 不稳 / 不通 |

即：**「接入国内数据源」≠「全部免代理可用」**。豆瓣与微信读书是**境内服务**，装完即用；Bangumi 与
NeoDB 是**境外托管的中文站**，**需要国际网络**。后续给人介绍本 fork 时不要含糊。

**四关**：analyze 干净 · **5707 应用**（+1 护栏）/ 2380 core / 110 server · RPC 字节一致。

### D15 · 源区域维度 + 连通性自检（2026-09-21，起源：少爷质疑「NeoDB 要梯子，还算本土化吗」）

少爷这一问戳到了项目的命门。傲天把**全部 21 个 API 宿主**过了 DNS + ASN 归属，结论比 NeoDB
单点严重得多：

| 归属 | 数 | 具体 |
|---|:-:|---|
| **境内** ✅ | **2** | `frodo.douban.com`（腾讯云 AS45090）· `weread.qq.com`（腾讯） |
| 境外 Cloudflare | 8 | NeoDB · Bangumi · AniList · MangaBaka · Kitsu · ComicVine · Podcast Index · SteamGridDB |
| 境外 AWS | 3 | TMDB · TheTVDB · IGDB |
| 境外其他 | 8 | MangaDex(ID) · VNDB(NL) · TVmaze(DE) · OpenLibrary(US) · Fantlab(RU) · Google Books(US) · Hardcover(US) · MusicBrainz(DE) |

**真正的病**：**8 个媒体类型的默认主源 8/8 在境外** —— 而境内唯一可用的豆瓣在图书 / 影视里都**排在
NeoDB 之后**。图书更惨：8 个图书源**全部** `supportsBrowse => false`，连浏览视图都没有。
⇒ **「本土化」的判据改成「默认路径全境内可达」，不是「所有源都在境内」。**

**D（连通性自检）**：`lib/core/api/source_reachability.dart` + `lib/features/settings/screens/reachability_screen.dart`
- 逐源对 `apiHost` 发一次 `GET /`（`Range: bytes=0-0`、`validateStatus` 全收），`Future.wait` 并发。
- **判据是「有没有 HTTP 响应」**：401 / 403 / 404 一律算**可达**，否则「没配密钥」会被误报成网络故障。
  已用 4 条纯函数测试钉住映射（超时 / 拒绝 / 非 Dio 异常 / HTTP 错误码）。
- Web 端跳过（浏览器侧结论其实描述服务端），UI 写明。
- **活体验证**：20/20 可达、总耗时 2.0s；**豆瓣 222ms · 微信读书 741ms**，其余 1043–2025ms ——
  区域分类在延迟上也看得出来。记录存 `probe/reachability_probe_live.txt`（冒烟脚本用完即删：
  它要联网，不能进 CI）。

**A（区域优先）**：`SourceInfo` 加**必填**的 `region` + `apiHost`（21 处标注）·
`BrowseNotifier._initiallyDisabledSourceIds`（原 `_keylessSourceIds`）**有境内源时关掉境外源**，
**全类型无境内源则一个不关**（动画 / 漫画 / 游戏 / 音乐 / 播客 —— 提示不等于证据，空标签页什么也说明不了）·
`search_sources.dart` 图书 / 影视**豆瓣提到 NeoDB 之前** · 境外源在源开关带 `Icons.public`、
向导卡片加「需国际网络」chip · 新增 13 个 l10n 键（**1747 → 1760**，六语言齐平）。

**护栏**：新增 3 个测试文件 14 条 —— `source_catalog_region_test.dart`（4，钉死境内集合 +
`apiHost` 唯一非空）· `source_region_default_test.dart`（5，钉死默认开启集合）·
`source_reachability_test.dart`（4）· `reachability_screen_test.dart`（2）。顺手同步
`search_sources_test.dart` 的 id 顺序表。**已证伪**：临时把微信读书标成 `overseas` → 3 条测试报红，
指向明确，不是摆设。

**四关**：analyze 干净 · **5722 应用**（+15）/ 2380 core / 110 server · RPC 字节一致 · **Web 构建通过**。

### D16 · 豆瓣动画源（2026-09-21，起源：少爷「我要的就是纯粹的不用梯子就能刮削到所有内容，并且是中文数据」）

少爷否掉了 T6（网络代理输入框）——**「需要在手机上开代理才能用，就跟我没改造它没有太大区别」**。
判据因此只剩一条：**不挂代理，默认路径就得出中文**。D15 接住了图书 / 电影 / 剧集，
**动画与漫画是剩下两个洞**（两者此前的中文元数据全押在 Bangumi 一家，而它对少爷的网络不可达）。

**选型实证（先探测、后写码）**：

- **豆瓣没有「动画」条目类型** —— 动画剧集就是剧集、动画电影就是电影，**唯一标记是题材里的「动画」**。
  实测 `/api/v2/search/movie` 混合池里 `[tv] 孤独摇滚！`（35366293）、`[tv] 咒术回战 第三季`（36714178）都在；
  `/api/v2/tv/{id}` 详情 **73 字段**，含 `episodes_count` / `intro` / `genres` / `rating`（0–10）
  —— **数据比 Bangumi 还全**。⇒ **不必另找源，也不必背 bangumi-data 那 1.45MB 快照与 CC-BY 署名义务。**
- `/api/v2/search/music` **也是通的**（200 / 中文专辑名 / `rating` 0–10 / `genres` / `pubdate` / `intro` / `discs`）
  ⇒ 音乐线**已落地（→ D18）**。`/api/v2/search/game` **404**（豆瓣无游戏入口）。
- **漫画中文已落地（→ D17）**：**MangaDex 原生支持中文标题检索** —— `?title=进击的巨人` 命中
  "Attack on Titan"，`altTitles` 带 `{'zh': '进击的巨人'}`。修的是**既有源**，零新增；
  本轮实测中文别名覆盖 **61%**（热门头部 83%）。
- 候选替代源归属复核（`probe/audit_candidates.py`，DNS + ASN）：境内 = 豆瓣 / 微信读书 /
  `registry.npmmirror.com` / `www.ximalaya.com`（播客候选）/ `www.taptap.cn`（游戏候选）/ `api.bilibili.com`。
  **`api.mangabaka.dev` 已官方下线**（500 "deprecated and no longer serves traffic"）；项目用的是 `.org`，不受影响。
- ⚠️ **`本机通 ≠ 手机通`**：本机 ping 境外站只有 1–28ms，是 **TUN 代理**造成的假象。判据只能看 **DNS 归属**。
- ⚠️ **阻断是域名级的**，不是整段封锁：同为 Cloudflare，AniList / Kitsu 可达，Bangumi / NeoDB 不可达。

**落地**（`lib/features/search/sources/douban_anime_source.dart`，id `douban_anime`）：

- **复用 `DataSource.douban`** ⇒ **零新枚举值 / 零图标分支 / 零密钥界面 / 零新 l10n 键**
  （沿用 `l.mediaTypeAnime` / `l.searchHintAnime`）；`source_badge_test` 的枚举计数、
  `source_catalog_test` 的密钥集合、`welcome_step_sources_test` 的输入框数**全都不动**。
  缓存身份也不撞车：非 game/manga 的唯一索引是 `(collection_id, media_type, external_id)`，**`media_type` 在内**。
- `DoubanSearchApi.searchAnime` 复用 `_searchSubjects<T>`（`targetType` 改**可空** + 新增 **`accept` 谓词**），
  **不复制客户端**。`getAnime` **先 `/tv/{id}` 再 `/movie/{id}`** —— 豆瓣按 id 分不出电影还是剧集；
  **只把 404 当「不是这一类」继续试**，401 / 403 照抛（密钥问题或封禁，再打只是多烧一次配额）。
- `Anime.fromDouban`：`title` = 中文名；`titleNative` = `original_title`（**动画记录里豆瓣确实给了日文名**
  —— 实测 `孤独摇滚！` → `ぼっち・ざ・ろっく！` —— 但中文电影记录恒为空，不能假设它有）；
  `titleEnglish` = `aka` 里第一个**不含汉字**的别名。**两者必须分开取**：影视那套
  `doubanItemOriginalTitle`（「`original_title` 优先、`aka` 兜底」）会把**日文名当成英文名**，
  故另加 `doubanItemNativeTitle` / `doubanItemAliasTitle` 两个 helper。
  `averageScore` = `rating.value ×10 round()`（0–10 → 0–100）、`format` 由 `type`/`subtype`（详情）
  或 `uri` 的 `/tv/`、`/movie/`（搜索行）判 `TV` / `MOVIE`、`popularity` = `rating.count`、
  `episodes` = `episodes_count`、`duration` = `durations[0]` 抽数字、
  `externalUrl` = `movie.douban.com/subject/{id}`。**搜索行没有 `intro` / `episodes_count`**，刷新后才补全。
- **活体实测**（2026-09-21，真接口喂真解析器）：搜「孤独摇滚」→ 5 条全中文，评分 90 / 82 / 84，
  `format` 正确分出 TV 与 MOVIE；详情 `/tv/35366293` → `episodes=12`、`duration=24`、
  `score=90`、中文 `intro` 完整；`/movie/1291561`（千与千寻）→ `format=MOVIE`、`duration=125`。

**连带必改 3 处（都不报编译错）**：`collection_actions` 的动画刷新 `switch` 加 `DataSource.douban` 臂
（漏了豆瓣 id 会被送去 AniList）· `import_service._fetchOneAnime` 加臂（`.xcoll` 降级导入）·
`source_catalog` 的 `mediaTypes` 补 `MediaType.anime`（漏了 region 规则不认，动画页默认仍全境外）。
`anime_similars_section` 的 `_ => null` 天然覆盖。

**⚠️ 行为变化（必须记住）**：D15 规则是「该类型有境内源 ⇒ 境外源默认关」，所以动画页**默认只开
`douban_anime`**，AniList / Kitsu / Bangumi 默认关。代价是**动画页打开时是空的**（豆瓣不浏览），
与图书 / 影视同构 —— 输入中文关键词即出结果；想要英文浏览，点一下 AniList 芯片即可。
搜索是**并发打所有开启源并做并集**，所以中文查询由豆瓣命中即可，不必抢主源。

**护栏**：新增 2 个文件（`douban_anime_source_test.dart` 6 条 · `douban_anime_json_test.dart` 10 条）
+ `source_output_media_type_test.dart` 加一行；同步 `search_sources_test.dart` 的 id 顺序表、
`source_region_default_test.dart`（动画改为只留 `douban_anime`，并把「漫画无境内源」作为新的全开用例）、
`browse_provider_test.dart` 的 pre-0.41 迁移用例（`hasLength(3)` → `1`）。

**四关**：analyze 干净 · **5741 应用**（+19）/ 2380 core / 110 server · RPC 字节一致。

### D17 · 漫画中文元数据（2026-09-21，起源：D16 收尾时判定的「漫画是最后一个洞」· 零新增源）

D16 之后，**漫画线是最后一个「中文查询只回罗马音」的类型**。缺口不在数据 —— MangaDex 一直带着中文名，
只是解析器没去读它。

**缺口定位（先探测、后写码）**：

- MangaDex 的**检索本身跨全部标题**：`?title=海贼王` → 命中 `One Piece`，`?title=进击的巨人` →
  命中 `Attack on Titan`。**搜索从来不是问题**。
- 问题在**解析**：`Manga.fromMangaDex` 的 `title` 取 `ja-ro ?? en ?? native`，而 MangaDex 的中文名
  **从不写在 `title` 里**，只存在于 `altTitles` 的 `zh` / `zh-hk` 键 ⇒ **搜中了也显示 `"One Piece"`**。
- 实测（`probe/mangadex_zh_coverage.py`）：**5/5 中文关键词全部命中**，且**每一行都带中文标题**；
  `zh` 是**简体**、`zh-hk` 是**繁体**；**中文标题覆盖 61%**（`followedCount` 排序 500 行采样；
  **前 100 行 83%**）。原始 JSON 核对：「海贼王」那条 `altTitles` 有四个中文别名
  （`海贼王` / `海盗路飞` / `航海王` / `zh-hk:海賊王`），`zh` 键取首位。
- 附带实测（`probe/mangadex_desc_tag_probe.py`）：**描述中文仅 7%**（21/300；语言键 en 300 / ja 233 /
  pt-br 202 …）；**77 个 tag 的名全部只有 `en`** ⇒ 筛选词表不受影响。
- ⚠️ **MangaBaka 直连 403**（`series/search` 正确端点 + 带 UA 仍 403，传输层无特殊 header）——
  属**服务端拒直连**，与中文标题无关，**单独记入 T5/待办**。

**落地**（`packages/core/lib/models/manga.dart`，**零新源、零新枚举、零 l10n**）：

- `Manga.fromMangaDex` 新增中文拾取 `_zhTitleKeys = ['zh', 'zh-cn', 'zh-hans', 'zh-hk', 'zh-hant']`，
  **中文优先进 `title` 槽** ⇒ 默认标题语言（romaji）下显示中文；**无中文的记录行为完全不变**
  （仍 `ja-ro ?? en ?? native`）。
- `titleNative` **移出**原先的 `zh` 末位兜底，只留 `ja ?? ko`（原名语义干净化）；
  `titleEnglish` 不动。三槽语义：**中文主标题 / 英文 / 日韩原名**。
- `_localized` 同样中文优先（zh 系 → en → 首个非空），**影响描述**（7% 的记录）、**不影响 tag**
  （tag 只有 en）。
- `Manga.title` / `Anime.title` 的字段注释同步更正 —— 原文写「Romaji title (always present per
  AniList contract)」，D16 之后这句已不成立。

**活体实测**（真接口喂真解析器）：搜「海贼王」→ `title=海贼王 · en=One Piece · native=ワンピース`；
「进击的巨人」→ `进击的巨人`；「鬼灭之刃」→ `鬼灭之刃`；「咒术回战」→ `咒术回战`。

**未做（判断过、刻意不做）**：**不动 `search_sources` 的注册顺序**。注释虽写「order drives per-type
primary」，但 `primarySearchSourceFor` 全仓**只有 `wishlist_screen` 一处调用**（判断该类型有无源），
搜索结果本就是**并发打所有开启源做并集** ⇒ 挪动 MangaDex 到漫画组首位**不改变任何行为**，
只会炸 `search_sources_test` 的 id 顺序表。漫画线 5 源全在境外（D15 规则：无境内源 ⇒ 一个都不关），
MangaDex 本来就默认开启。

**⚠️ 诚实的边界**：MangaDex **仍是境外源**（DNS 归属印尼），D15 的 `region` 标注**照实保留为
`overseas`**。这一轮做到的是「**不挂代理也能拿到中文漫画元数据**」（它在少爷网络下可达，且**不在
D15 手机自检的失败名单里**），**不是**「漫画线有了境内源」—— 那一条至今无解（B 站漫画 code 99 ·
快看 404 · 动漫之家不可达 · copymanga 302）。

**护栏**：`packages/core/test/models/manga_mangadex_kitsu_test.dart` 新增 5 条
（中文优先进 `title` · `zh` 优先于 `zh-hk` · 仅繁体时兜底 · **无中文时行为不变** · 描述中文优先）。

**四关**：analyze 干净 · **5741 应用** / **2385 core**（+5）/ 110 server · RPC 字节一致。

### D18 · 豆瓣音乐源（2026-09-21，起源：D17 收尾判定的「音乐线」· 零新增源 / 零新枚举 / 零新文案键）

**问题**：`MediaType.audio` 的专辑半边只有 MusicBrainz（境外、无中文），播客半边是 PodcastIndex（境外）
⇒ 不挂代理时音频页拿不到任何中文专辑元数据。

**关键发现：豆瓣的音乐是独立条目类型**（不像动画混在影视混合池里）——
搜索 `/api/v2/search/music`、详情 `/api/v2/music/{id}`，**详情是唯一带 `songs` 的形状**。
⇒ 又是 D16 的形态：**复用 `DataSource.douban`，只加一个源**，不引新枚举 / 图标 / 密钥界面 / 文案键。

**四个实测出来的坑（决定映射方案）**：

| 现象 | 实测 | 处置 |
|---|---|---|
| `songs[].track_number` 为 `null` | 一张 169 行合集里 **31 行**是 `"全套曲目"` / `"CD1"` / `"早期音乐"` / `"总时间：70分钟"` | `doubanMusicSongs` **过滤** —— 它们不是曲目 |
| 真曲目编号 | **跨碟全局连续**（实测 1..138，无重复） | `discNumber` 恒取 1，position 不撞 `(source, audioId, disc, position)` |
| `duration` 字段 | **恒为 0** | 不当 `lengthMs`；时长只在**合集标题尾部**（`…《万福，光耀海星 》   2:15`），抽走并**从标题删掉** |
| 搜索行 `card_subtitle` | 「**歌手 / 年份**」（影视池是「国家 / 题材 / 导演 / 演员」） | **不能复用 `doubanItemGenres`**（它会把 `'2016'` 读成题材），另写 `doubanMusicGenres` 只认 `genres` 数组 |

**映射**：`title` = 中文名 · `artists` = 详情 `singer[].name`（搜索行取 `card_subtitle` 首段）·
`firstReleaseDate` = `pubdate[0]`（**数组**）· `genres` = `genres` 数组 · `label` = `publisher[0]`（数组）·
`format` = `media[0]`（`'CD'`）· `discCount` = `discs` 长度 · `rating` = `rating.value`（**已是 0–10，别乘**）·
`ratingCount` = `rating.count` · `description` = `intro` · `trackCount` = 过滤后曲目数 ·
`externalUrl` = `url`（`music.douban.com`，**不是 movie 域**）。缓存身份 `nativeId` = 豆瓣 subject id。

**⚠️ 区域规则补丁（本轮唯一的跨功能改动）**：`.audio` 是**唯一一个装着两本目录**的媒体类型
（`AudioKind.album` / `podcast`），而 D15 的区域规则粒度是**媒体类型** ⇒ 豆瓣音乐（境内）一进来，
「有境内源 ⇒ 关境外源」会**连带关掉 PodcastIndex** —— 而它是播客唯一的源、**没有任何境内替代**，
关掉就是凭空空白（正是 D15 注释里要避免的"用沉默骗人"）。新增
`BrowseNotifier._isAloneInItsCatalogue`：**一个源若独自撑着一本无境内替代的目录，豁免**。
测试该条必须给 mock prefs 配上 `SettingsKeys.podcastIndexApiKey` / `Secret`，否则它本就因缺密钥被关，
断言测的就不是区域规则本身。

**连带必改 5 处（全不报编译错）**：`collection_actions` 刷新臂 · `import_service._fetchAlbumRefs`
（豆瓣用 `externalId` = 豆瓣 id）· `media_handlers` 的 `sheetBuilder` 与 `enrich`（两处）·
`source_catalog` 的 `mediaTypes` 补 `MediaType.audio` · `search_sources` 注册（炸 id 顺序表）。

**UI**：`DoubanMusicSheet`（仿 `PodcastIndexSheet`，`previewTracks = 50`）—— 豆瓣一条 subject 就是一张专辑，
**没有** MusicBrainz 那种版本选择；塞给 `MusicBrainzAlbumSheet` 会按 `nativeId` 当 MBID 查 release，
静默失败。`ItemDetailsSheet.album` 加 `overview`（只有豆瓣填 `intro`，MusicBrainz 为 null ⇒ 行为不变）。

**活体实测**（2026-09-21，真接口喂真解析器）：搜「周杰伦」→ **20 条全中文专辑名** / 歌手 / 年份 / 评分；
详情 `genres=[流行]`、`label=杰威尔音乐`、`format=CD`、`date=2016-06-24`、`discs=1`、`rating=8.1`、
`intro` 完整、`url=music.douban.com/subject/26812952/`；曲目 **10 首**，pos 1..10，标题干净，
`lengthMs=null`（官方专辑无时长，符合预期）。

**护栏**：新增 2 个文件（`douban_music_source_test.dart` 7 条 · `douban_music_json_test.dart` 10 条）
+ `source_output_media_type_test.dart` 加一行；同步 `search_sources_test.dart` 的 id 顺序表、
`source_region_default_test.dart`（新增 audio 三态用例：`douban_music` + `podcastindex` 开、`musicbrainz` 关）。

**四关**：analyze 干净 · **5759 应用**（+18）/ 2385 core / 110 server · RPC 字节一致。

### D19 · 游戏与播客两条媒体线（2026-09-21，起源：少爷「继续，全都做，一次性做完」）

**TapTap 游戏源（`taptap`）+ 喜马拉雅播客源（`ximalaya`）** —— 8 个媒体类型至此全线「不挂代理 + 中文」。
接口实证、契约细节与踩坑见 [`RULES.md`](RULES.md) 七之十四 / 七之十五 / 七之十六；本条只记验收。

**活体实测**（真接口喂真解析器）：TapTap 搜「原神」→ 10 条 / 评分 `79.0` / `app/168332` /
`getGameById` 回环通；喜马拉雅搜「三体」→ **30 条中文节目名** / `album/56974128` / 标题重搜回环通。

**活体验证抓到三条夹具测试抓不到的问题**：

1. **喜马拉雅用 `Content-Type: text/plain` 送 JSON** ⇒ Dio 把 body 留成 String ⇒ 解析器首道
   `is! Map` **静默返回空表**（搜索永远 0 条、无异常）。修法：解码提到共享层 `api_dio.dart` 的
   `decodeJsonBody()`，传输层声明 `ResponseType.plain`；Fantlab 同款先例改为委托。
2. `getGameById` 收的是**偏移后的模型 id**，我的活体测试喂了裸 appId ⇒ 落进 `appId <= 0` 保护而返 null。
   **链路本身是自洽的，错在测试**；facade 文档已写死这一点。
3. `reachability_screen_test` 按**数组下标**取目录条目，TapTap 插在 `igdb` 之后把 `neodb` 从 10 挤到 11 ——
   一个与游戏毫不相干的断言被炸红。已改为按 `DataSource` 经 `sourceInfoFor` 取。

**区域规则收口**：音频半边也有境内源 ⇒ `BrowseNotifier._isAloneInItsCatalogue` 豁免**删除**，
「有境内源 ⇒ 关境外源」对全类型整类生效（游戏页的 IGDB 随之由默认开转默认关，**预期行为**）。

**护栏**：新增 `test/core/api/taptap_api_test.dart` / `ximalaya_api_test.dart` 共 **36** 条；同步
`source_badge_test`（25 个枚举值）、`source_catalog_region_test`、`search_sources_test`、
`source_output_media_type_test`、`source_region_default_test`、`browse_provider_test`。

**四关**：analyze 干净 · **5800 应用**（+36）/ 2385 core / 110 server · RPC 字节一致。
**提交**：`cd10c3e0`（59 文件，+1986 −78），已推送。

### D20 · M7 三端打包与发布（2026-09-21，起源：M7 里程碑）

三端的打包面与分发机制落地 —— 过程中**逮到一处只在 Web 形态下发作的真缺陷**。

- **Web（本轮主战场）**：`flutter build web --release` → `build/web/`（57MB / 192 项）；起**真自托管服务端**
  （`dart run server/bin/server.dart --web-root build/web`）实测：`/health`、`/rpc`、`/proxy/keys`、
  canvaskit 与 assets 全 200，非白名单 slug 404，未知路径 SPA 回退 200。
- ⚠️ **逮到的真缺陷**：TapTap 在 Web 上必得 `400 INVALID_XUA`。服务端 `/proxy` 的
  `_forwardedRequestHeaders` **只放行 `content-type` 与 `accept`**，`X-UA` 被丢弃 ⇒ 游戏页**静默空白**。
  修法：`ApiProxy._authorize` 把 `ProxyTarget.taptap` 移出免密钥组，由服务端补 `kTapTapXUa`
  （与 Douban 自持 UA 同法），并补两条服务端护栏。**喜马拉雅经实测不需要补 `Referer`**（`ret: 200`）——
  假设被推翻，故未动手。详见 [`RULES.md`](RULES.md) 七之十七。
- **Android**：`flutter build apk --release`（94.0MB）。本地产物**仅供真机验收** —— 仓库里的
  `android/app/verify-release.jks` 是一次性验证密钥（`**/*.jks` 已 gitignore），不是发布密钥；
  CI 发布需 `KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_ALIAS` 三个 secret。
- **Windows**：**本机不可用** —— `flutter doctor` 报 `[X] Visual Studio not installed`（B1 属实）。
  发布走 CI 的 `windows-2022` 运行器（该 pin 的理由见流水线注释）。
- **分发**：新增 `.github/workflows/release-cn.yml`（fork 专属、**零改动上游文件**），推 `cn-v*` 标签触发，
  构建 Windows / Android / Web 并发成 GitHub Release。**标签前缀必须是 `cn-`** —— 上游 `release.yml`
  在 `v*` 上触发，`v0.44.0-cn` 会把它一并点着。详见 [`PROJECT.md`](PROJECT.md) ADR-15。

**四关**：analyze 干净 · 5800 应用 / 2385 core / **112 server**（+2）/ RPC 字节一致。

### D21 · 明文凭据审计（2026-09-21，起源：少爷问「GitHub 仓库中有明文的密钥吗」）

**结论：有且只有一组 —— 豆瓣 Frodo 的公开 key pair**，明文、已推 GitHub。**性质是「共享凭据」，
不是本 fork 的泄露**（Frodo 已停发新 key，这对就是官方客户端自带的那份），故不重写历史。
按少爷裁定把**明文副本从 12 处压到 5 处**：文档改为指向来源文件、测试改用符号引用；
新增硬约束 **R9**（凭据字面量只准存在于它唯一的那处来源）。
**已核验干净面**：`.env` / keystore / CI secrets 从未入库（全历史 `--diff-filter=A` 核对）。

### D22 · 「游戏名列表导入」（2026-09-21，少爷「先试一下B吧」）

粘贴游戏名 → 匹配 → 预览改选 → 批量入库，**零凭据**。第十二个导入源 `name_list`。

- ★ **最关键的一课：真实数据推翻了算法假设。** 初版用 Dice 相似度，单测全绿；跑
  `probe/ps5_name_match_probe.py` 打真 TapTap 后暴露：搜「战神」头部返回**「烈火战神」**、
  搜「血源诅咒」返回**「樱花女校：血源诅咒」** —— 短查询 + 蹭名会**静默预选错的游戏**。
  重写为**封顶不等式**（埋在更长标题里 ≤55、纯 Dice ≤61，两者均**低于**预选线 62），
  只有「查询词是候选前缀」才进预选档。详见 [`RULES.md`](RULES.md) 七之十八。
- **中英分流**：含 Han → TapTap；纯拉丁 → IGDB 批量；拉丁弱/空 → TapTap 兜底并去重合并。
- **两阶段**：`match()` 只读，`import()` 才写 —— 用户永远先看到匹配结果。
- **63 条新测试**（matcher / parser / service）；l10n 六语言 1762 → **1791**。

### D23 · 「PSN 登录导入」（2026-09-21，少爷「做outh」）

承 D22 追问 —— **B 缺一个上游：用户手上并没有那份名单**（PSN 官方无任何导出功能；网上流传的
「网页端导出游戏列表」是内容农场编的）。方案 A 落地：**NPSSO → code → token** 的社区授权流。

- **索尼没有第三方 OAuth 注册、没有 PIN flow，也走不了内嵌 WebView**（Android 端没有 webview 依赖）
  ⇒ 唯一三端通吃形态：用户从浏览器取 **NPSSO**，应用用它换令牌。
- **已购全库确实有接口**（推翻此前的判断）：不在 trophy 域，而在
  `web.np.playstation.com/api/graphql/v1/op` 的 persisted query **`getPurchasedGameList`**。
- **没有写第二个 `ImportSource`**：PSN 只给裸游戏名，与粘贴名单同构 ⇒ 止步于 `List<String>`，
  交给 `GameNameListImportContent(initialNames:)`，匹配 / 阈值 / 预览 / 入库**一行不复制**。
- **凭据纪律**：NPSSO 绝不落盘（等同密码）；只有 refresh token 可持久化，且 opt-in。
- **Web 端靠服务端搬凭据**（`七之十七` 的第二次验证）：凭据走 query，服务端 `_authorize` 搬进 header
  并**从 URL 删掉** —— 不删，密码级凭据就进了对方访问日志。
- 详见 [`RULES.md`](RULES.md) 七之十九；设计说明见 `lib/core/api/psn/README.md`。

**四关**：analyze 干净 · RPC 字节一致 · **5885 应用 / 2385 core / 115 server**。

### D24 · PSN 导入三处真机修正（2026-09-21，少爷真机反馈）

少爷真机跑通授权后回报三件事，逐条查实、留证据、再动手：

1. **「查看」选完候选 → 整个匹配结果页被关掉**（来不及导入）。根因：`showDialog` 默认挂 **root**
   Navigator，而导入页在**每个 tab 自己的 Navigator** 上（`app_shell.dart:343`）；候选行却用
   **页面 context** 调 `pop()` ⇒ 弹掉的是**弹窗背后的页面**，弹窗自己还留着（真机观感即"界面被关掉"）。
   修法：**所有出口统一用弹窗自己的 context，且只 pop 一次**（一次点击可能既命中 tile 又命中 radio）。
   测试先行：`test/features/settings/content/game_name_list_import_content_test.dart` 用真嵌套 Navigator
   驱动真实页面，**断言 tab 根哨兵页不得露出来** —— 修前红、修后绿。
2. **PS+ 会员目录里玩的游戏不在列表里**（玩通、甚至拿了白金也不在）。根因：`getPurchasedGameList`
   只认**购买**，而订阅目录里的游戏从未被购买。修法：**库 = 已购 ∪ 玩过**；游玩历史走 REST
   `m.np.playstation.com/api/gamelist/v2/users/me/titles`（`offset` 真分页 **且**带 `localizedName`；
   同宿主的 `getUserGameList` 两者皆无）⇒ 新增**第三个 `ProxyTarget.psnme`**。两半来自不同宿主，
   **独立失败**，只有两边都没拿到名字才报错。scope **无需变更**（psn-api 全库只用我们已持有的那组）。
3. **匹配成功率低** —— **少爷的截图改写了诊断**：失败行写的是「查询失败」（= 请求抛异常），不是「未找到」；
   唯一命中的 `黑神话：悟空` 走 TapTap「完全一致」⇒ **TapTap 覆盖主机大作，真正断的是英文那条腿**
   （IGDB 无凭据，`connectionStatus` 却因残留令牌显示已连接 ⇒ 警告横幅被藏住）。二轮落地三件事：
   **① 修「查询失败」粘性误报** —— 按**行**记"问过几处、答上几处"，一处都没答上才算失败
   （旧语义：IGDB 一抛就把整批标失败，之后 TapTap 兜底成功也不撤销 ⇒ 真机上出现
   「`>` 已匹配 + 查询失败 + 断云图标」的自相矛盾行）；**② 无凭据则整个跳过 IGDB**，拉丁名直接落 TapTap；
   **③ 别名匹配**（少爷拍板）—— `match` 入参升为 `GameNameQuery`（name + aliases），
   多拼写各走各的目录、候选合并回一行，**阈值一字未动**；PSN 侧 `PsnLibraryTitle` 供 `localizedName` 作别名。
   **诚实的边界**：纯 VR/独占（Zenith、Vegas Infinite、Epic Roller Coasters 这类）TapTap 没有、
   索尼也没给中文名 ⇒ **只有 IGDB 密钥能救**；B5 已更新为"别名已做 + 请少爷配 IGDB"。

**四关**：analyze 干净 · RPC 字节一致 · 应用 **5911 通过 / 3 跳过** · core **2385** · server **116**
（较 D23：应用 +26、服务端 +1）。

### D25 · 代理环境误判「无网络 / 密钥无效」（2026-09-22，少爷真机反馈）

**现象**：开代理（规则或全局）后——自检 22 源全部「无法连接」；各 API 校验全挂且**误报「API密钥无效」**；
关代理立即恢复。少爷怀疑"网络模块近期改动"。

**排查结论（两层拆开）**：
1. **自检无 bug**：判据是"有无 HTTP 应答"（401/403/404 都算可达）；22 源全挂 = 连接层真炸。
   断路器也已排除（`kHostBackoffPolicy` 只有豆瓣域注册，放大不了）。**根因在代理环境**：
   app 的 Dart `HttpClient` **不读系统代理**（全仓库无 `findProxy`），TUN（fake-ip）接管后
   流量全进代理 ⇒ 出口/分流对这些域不通 ⇒ 连接层全炸，**规则模式下国内域也挂正指向 DNS/分流处理**。
   **app 侧无解也不该硬解**；给用户的验证法：开代理后浏览器直接开 `https://www.taptap.cn/`，
   浏览器也不行就是代理层。
2. **「API密钥无效」误报是真 bug，已修**：各 `validateApiKey` 原本
   `on DioException { return false; }` —— "没收到应答"与"密钥被拒"压成同一个 `false`，
   设置页统一渲染成「XX API 密钥无效」。修法：**`e.response == null` 一律 rethrow**
   （SteamGridDB / TMDB / TheTVDB / ComicVine / Google Books 五处），
   设置页新增 `_runKeyCheck` 捕获并以「连接错误 + 传输层真实原因」提示。**Hardcover 未改**
   （其客户端把异常包成 `HardcoverApiException`，无 response 可判，待客户端暴露状态码再补）。
   另 IGDB 的连接测试（`getAccessToken`）映射本就正确（有 response 才判密钥），不用改。

**测试**：两条钉旧语义的用例改写为新契约（"网络错误 ⇒ rethrow"）。

**D25 续（少爷实测：浏览器挂梯可达 Twitch，应用仍报连接错误）**——**第三层根因：授权调用共用 5 秒数据超时**。
`getAccessToken` 与数据调用共用 `_timeout=5s`，而从大陆到 `id.twitch.tv` 通常要经代理出国，
TLS 握手在慢节点上 5 秒到不了 ⇒ **永远超时** ⇒ "从来没有出现过连接成功"（浏览器无此死线，所以浏览器能通）。
修法：**授权调用单独 30 秒**（`Options(connectTimeout: _authTimeout)`，两个月才一次，慢点无代价）；
且 `verifyConnection` 的 errorMessage 现在附带传输层 detail（socket refused / handshake failed / timed out），
**让"授权域被墙"与"密钥填错"从此可区分**。测试：新增断言授权请求携带 30s 超时；11 处 post stub 补齐 options。

## 📋 候选（下一步从这里挑）

> 接入优先序共识：**Bangumi ✅ > NeoDB 图书 ✅ > NeoDB 影视 ✅ > 微信读书 ✅ > 豆瓣（图书 ISBN 直查）✅ > 豆瓣影视 ✅ > Bangumi 漫画 ✅ > 优酷/爱奇艺**。豆瓣元数据最全但引入签名 + 403 两个新变量，且 NeoDB 已是豆瓣数据的免密钥代理，故一直排在最后；其**图书线已于 D7、影视线已于 D8 落地**（两个新变量都已验证：403 退避 D6 + 签名 D7）。豆瓣线至此**全部完成**。

### T1 · 豆瓣 403 退避（✅ 2026-09-20 完成 → D6）

> **2026-09-19 更新**：NeoDB 已是豆瓣数据的免密钥代理（见 T2），本任务不再是任何工作的前置，仅在需要豆瓣**独有数据**（短评、想看人数、精确剧集排期）时才值得做。

已于 D6 落地：断路器（连打 N 次 → 冷却 M 分钟）+ 402/403/429 被动开闸 + 域级共享预算，豆瓣取值 `maxBurst: 9` / `cooldown: 5min` / `gap: 800ms`。**后续 T3 的豆瓣 ISBN 可直接开工** —— 新源只需在自己的 `handleDioException` 里优先采纳 `HostCooldownException` 的文案。

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

> **2026-09-20 更新**：微信读书已落地（见 D5）；豆瓣 ISBN **亦已落地（见 D7）** —— T3 整项完成。以下为选型阶段的实证与定案，留作记录。

**豆瓣 ISBN 实证结论（2026-09-20，`probe/douban_isbn_probe.py` + 存档 `probe/douban_isbn.json`）**：

- **签名 Frodo 的 ISBN 端点可用**：`GET frodo.douban.com/api/v2/book/isbn/{isbn}`，带 `apiKey` / `_ts` / `_sig`，其中 `_sig = base64(HMAC-SHA1(secret, "GET&" + urlencoded(path) + "&" + ts))`，UA 需用 `api-client/1 com.douban.frodo/...` 那一串 → **HTTP 200 / 6042 字节 / 55 字段**。ISBN-13 与 ISBN-10 命中同一本书。
- **五发全 200，未见限流**（另含 3 发对照：ISBN 当关键词搜、书名搜索、图书详情，均 200）。
- **返回的是完整记录**（与详情端点同级）：`id`（字符串主体 id）、`title`、`author`（数组）、`translator`、`press`（数组 —— **出版社在 `press`，没有 `publisher`**）、`pubdate` / `pages` / `price`（**三者都是数组**）、`rating`、`intro`、`catalog`、`author_intro`、`cover_url` / `pic`、`url`、`tags`。
- **关键：`rating.value` 已是 0–10**（本例 9.4，`max: 10`）⇒ **直接用，不可乘 2**（与 NeoDB 同规矩）。
- **响应不回显 ISBN**（无 `isbn13` / `isbn10`）⇒ `nativeId` 宜存**查询所用的 ISBN**，刷新按 ISBN 重查即可，**不存在 id 反解问题**（比 NeoDB 影视省事）。
- 先前记录的两条依然成立，故**免签路径不再考虑**：`book.douban.com/isbn/{isbn}` 会 301 跳 HTML；`movie.douban.com/j/subject_suggest` 对 ISBN 返空数组。
- 第三方 `isbn.work` 需 appkey（`probe/isbnwork.json` 记 `code 1 appkey无效`）⇒ 违背 ADR-3 免密钥原则，**弃用**。

- [x] 微信读书：`weread.qq.com/web/search/global`（免密钥，仅搜索）→ D5
- [x] 豆瓣 ISBN：**已落地 → D7**（双后端单源 + 凭据自填 + Web 端服务端签名）。
- 验收：ISBN 精确命中返回对应中文图书；关键词搜索中文书名无乱码；在线验证。

**设计定案（2026-09-20 拍板）**：

1. **凭据由用户自填，源码不内置。** 照搬本仓既有范式，**不新造存储设施**：`SettingsKeys`（`settings_provider.dart`）加键 → `ApiKeys.fromPrefs` 读 `SharedPreferences` → `settings/content/credentials_content.dart` 加一节（带「测试」动作，Podcast Index / ScreenScraper 已有此范式）→ 6 语言 l10n。**"仅读 prefs、无内置"的先例本仓已有四例**：RetroAchievements · ComicVine · Hardcover · Google Books。
2. **双后端单源**：关键词走 `/api/v2/search/book`；输入形如 ISBN（10 / 13 位数字，去连字符）时改走 `/api/v2/book/isbn/{isbn}`。**这不只是功能取舍 —— 单后端会让每次关键词搜索都白发一发到易封主机**，故双后端同时是省额度之选。

**实现清单（下一阶段）**：

- `lib/core/api/douban/{douban_types,douban_signature,douban_http_client,douban_search_api}.dart` + `douban_api.dart` —— **HMAC-SHA1 签名是新增件**，参照 `probe/sign.py`（`_sig = base64(HMAC-SHA1(secret, "GET&" + urlencode(path, safe='') + "&" + ts))`）。
- `douban_book_source.dart`（id `douban`）+ `Book.fromDoubanItem`（`press` 取出版社、数组字段取首元素、`rating.value` 直接用）。
- 注册面 7 处 · Web `proxy_targets` + `_authorize` · 三处护栏 · 连带必改 5 处 · 凭据设置 4 处 + l10n。
- 限流两道闸已于 D6 就位（`kHostBackoffPolicy` 的 `douban.com: maxBurst 9 / cooldown 5min`；`kHostMinRequestGap` 的 `douban.com: 800ms`）；新源的 `handleDioException` 须优先判 `e.error is HostCooldownException`。

### T4. 影视线：优酷 / 爱奇艺

- 均已实测搜索接口可用、免密钥，但字段偏少（无演员/简介级别元数据）—— 适合做「列表 + 海报 + 链接」，不适合做详情主源。
- 验收：关键词搜索返回中文标题与海报；详情缺失字段时无异常、字段留空。

### T5. 漫画线调研（✅ 2026-09-20 完成 → D9）

> **结论**：不必另找源。**Bangumi 的书籍类型（`type=1`）叠加 `meta_tags: ['漫画']`** 即是最佳免费漫画源 —— 免密钥、已接入、中文标题、解析与动画同构。已落地（见 **D9**）。

- 已实测失败（外部漫画平台）：B 站漫画（code 99）· 快看（404）· 动漫之家（不可达）· copymanga（302）。
- 未采用：NeoDB 的漫画类目（其影视线已验证客户端可扩，但中文标题不如 Bangumi 直接）。
- 验收已达成：免密钥、可直连、秒级响应、实测 12 条全为真漫画。

---

### T6 · 原生端网络代理设置（待少爷定夺）

D13 把 NeoDB 超时的病根钉死了：**境外源在无代理网络下不可达** —— 而这是物理事实，代码改不动。
但可以让 App 自己会走代理。

- **做法**：设置页加一项「网络代理」（`http://host:port`，留空＝直连），在 `createApiDio`
  （`lib/core/api/api_dio.dart`，全仓唯一 HTTP 出口）里给 native 的 `IOHttpClientAdapter` 装
  `findProxy`。一次投入可救**全部**境外源（NeoDB / Bangumi / AniList / TMDB / TheTVDB / TVmaze …）。
- **零代码替代（优先建议先试）**：手机端开 **TUN 模式**代理（Clash 等）即可让所有 App 流量走代理 ——
  Android 上 Flutter 的 `HttpClient` **不读系统「Wi-Fi 代理」设置**（那套只给 WebView / OkHttp 用），
  所以必须是 TUN/VPN 形态，填普通 HTTP 代理无效。
- **待定**：是否需要「只让境外 host 走代理」的白名单开关（国内源绕开代理更快）。少爷风格是「越简单
  越好」，所以先做**全局开关**即可。
- **D15 已交付度量的那一半**：设置页 → 数据源 → 「网络连通性自检」可**逐个源实测**当前网络能通到谁。
  配上 D15 的 `region` 标注，用户已能自己判断该开哪些源；T6 补的是「开完之后怎么让它通」。

#### T6 合规评估（2026-09-21，结论：**只做「通用网络设置」形态，不做统一出口**）

先把混称的「B」拆成三件性质不同的事：

| 形态 | 架构 | 定性 | 结论 |
|------|------|------|------|
| ① 应用内代理设置（本条 T6） | App 只给「`http://host:port`」输入框，出口由用户自备 | 通用网络客户端能力，同浏览器代理设置 | ✅ **可做**，但见下方四条红线 |
| ② OS 层 TUN | 用户自行挂 Clash 等，App 零介入 | App 不参与 | ✅ 无风险 |
| ③ 「统一出口」（自有 server 转发全部请求） | 用户 → 本机/自有服务器 → 境外 API | 见下 | ❌ **不做** |

**现行有效依据**（均已核实）：

- 《计算机信息网络国际联网管理暂行规定》**2024-03-10 第二次修订、2024-05-01 施行**：第六条「任何单位和个人不得自行建立或者使用其他信道进行国际联网」；第十四条 → 责令停止联网 + 警告 + **1.5 万元以下**罚款。**该条不区分自用 / 经营、不要求牟利。**
- 工信部《关于清理规范互联网网络接入服务市场的通知》（信管函〔2017〕32 号）：未经批准不得自行建立或租用专线（含 VPN）等信道**开展跨境经营活动**——此处限定语是「经营」。
- 《网络安全法》**2025-10-28 修正、2026-01-01 施行**：罚则分层提额（网络运营者最高 **1000 万**、直接责任人最高 **100 万**），并**新增「关闭网站或者应用程序」**这一处罚手段——即 **App 本身可成为处罚对象**。
- 《网络数据安全管理条例》（国务院令 790 号，**2025-01-01 施行**）第八条第二款：不得为非法网络数据处理活动提供**互联网接入、服务器托管、网络存储、通讯传输**等技术支持——「托管服务器替他人转发」正落在被点名行为里。

**③「统一出口」为何不做**：它把合规风险从「用户的网络环境」搬到了**「你的服务器 + 你的发布行为」**——而这恰是监管能直接触及的两端。变体差异：

- 服务器在**境外** ⇒ 境内用户流量经境外中转，属第六条「使用其他信道」；一旦对外提供，还可能落入 32 号文的「未经批准开展跨境经营」。
- 服务器在**境内** ⇒ 手机→服务器这一跳合法，但整机实质成为「跨境访问通道」，且**大陆云厂商 ToS 明确禁止搭建代理 / 加速，风控识别即停机封号**（这条几乎必然先于任何执法发生）。
- **自用 vs 发布是两个档次**：MIT 开源 + APK 分发会使「提供工具」情节显著加重（《刑法》285 条三款 / 非法经营罪的实务落点均在此）。**"我只是刮个番剧元数据"不构成豁免**——监管口径看的是「是否使用了非法定信道」，不是内容是否敏感。

**①形态要守的四条红线**（守住则同浏览器代理设置性质）：

1. 不内置任何节点 / 服务器地址；2. 不提供订阅链接、不做「一键连通」；3. 文案中立——叫「网络代理」，不出现「加速 / 科学上网 / 绕过限制」暗示；4. 不做"只让境外 host 走代理"的自动分流规则（那等于替用户做规避决策）。

**若 T6 后续要做，验收入口**：设置页新增「网络代理」项 → 写入 `createApiDio` 的 `IOHttpClientAdapter.findProxy` → 留空等于直连 → 与 D15 的连通性自检联动（填了代理后境外源是否转为 `Reached`）。

## 🔧 阻塞与长期债

| # | 事项 | 现状 | 影响 |
|:-:|------|------|------|
| B1 | Windows 桌面运行 | 缺 Visual Studio C++ 工作负载 + 插件符号链接受限 → `flutter run -d windows` 不可用 | 无法桌面预览；写码/分析/测试不受影响 |
| B2 | Web 端 /proxy 全链路验证 | 白名单已加 `api.bgm.tv` / `neodb.social` / `weread.qq.com` / `frodo.douban.com`，✅ **2026-09-20 闭环（→ D10）**。真实自托管实测 7/7：Bangumi GET / POST、NeoDB 搜索经代理返回与直连**逐字节相同**；豆瓣无密钥 503、非白名单目标 404 均在服务端拦下。护栏两条：`server/test/proxy_serve_integration_test.dart`、`test/core/api/proxy_round_trip_test.dart` | ✅ 已闭环 |
| B3 | 上游同步 | fork 基线 0.44.0；上游以周为节奏发版 | 每次同步人造裁决冲突清单见 PROJECT.md §3 |
| B4 | 中文数据源覆盖 | 动画 ✅（Bangumi）；图书 ✅（NeoDB / 微信读书 / **豆瓣**）；电影 / 剧集 ✅（NeoDB / **豆瓣**）；漫画 ✅（**Bangumi 书籍类型**）；**游戏 ✅（TapTap）；音乐 ✅（豆瓣音乐）；播客 ✅（喜马拉雅）** | **已闭环** —— 七类媒体均有免密钥中文源；仅漫画仍全境外托管（中文元数据可用，但路由需出境） |
| B5 | **PSN 导入的匹配率低**（D24 少爷真机反馈） | 二轮已落地：**粘性误报已修**（"查询失败"只在该行问过的所有来源都抛异常时出现）+ **无凭据跳过 IGDB** + **别名匹配**（`GameNameQuery`，多拼写各走各的目录）。**剩下的一步在少爷手上**：配置 IGDB 密钥（Twitch 开发者后台免费）—— ① 现状是**残留令牌让"未配置"看起来像"已连接"**，警告横幅曾被藏住；② 纯 VR/主机独占（Zenith / Vegas Infinite / Epic Roller Coasters 这类）TapTap 没有、索尼也没给中文名，**只有 IGDB 能救** | **别名已做；等少爷配好 IGDB 再实测一轮**。若配好后中文名仍搜不动英文目录，再考虑 ③ PSN 自建目录（工作量等同 D16–D19 加源） |

## 护栏速查（改代码前看一眼，防炸）

1. `test/shared/widgets/source_badge_test.dart` —— `DataSource.values.length` 硬编码（现 **25**），加枚举即炸。
2. `test/features/search/providers/browse_provider_test.dart` —— 该媒体可浏览源数硬编码，加源即炸（**仅可浏览类型**；图书走 `textQueryOnly`，无此断言）。漫画现 **5** 个（AniList / Bangumi / MangaBaka / MangaDex / Kitsu）；该文件的 `unsupportedSourceIds` 与 `seedLoaded` 的 `disabledSourceIds` 也各随源数变动。
3. `test/features/search/sources/search_sources_test.dart` —— 注册表 id 顺序表，加源须补序。
4. `test/shared/constants/source_catalog_test.dart` —— **「哪些源要密钥」的集合写死**（断言 `keyRequirement != none` 的源**恰好等于**那组枚举，现 **7** 个：igdb / tmdb / tvdb / comicVine / googleBooks / hardcover / podcastIndex）。加任何**需密钥**的源即炸；D7 才把它编入护栏。**豆瓣已于 D12 退出该集合**（改用内置公用密钥），同文件新增 `Douban asks the user for nothing` 反向钉住。
5. RPC：改 DAO/模型 → `dart run tool/generate_rpc.dart` → 提交生成物，否则 `dart test` 必挂，无幸免。
6. mocktail 断言命名参数：**不要用 `verify(...).captured` 按位取**（顺序无保证），在 `thenAnswer` 里按 `Symbol('x')` 取。
7. **同一条消息里对同一个文件不要发两次编辑** —— 实测最多只有一次生效，其余静默丢失且不报错。改完同一文件的多处，务必拆成多次调用并逐处 grep 复核。
8. `lib/core/api/episode_source/tv_episode_source.dart` —— **影视源必须给 `tvEpisodeSourceResolverProvider` 加一支**（它是 `_ => tmdb` 兜底）。漏了不报任何错，但 `TvShowCacheWarmer` 与 `_refreshedTvShow` 会拿新源的 id 去 TMDB 查，**可能把不相干的剧写进缓存**。
9. **影视的 `CollectionItem.nativeId` 恒为 null**（该 getter 只对 book / audio 生效）—— 刷新与 `.xcoll` 导入一律用 `externalId`。
10. `test/features/welcome/widgets/welcome_step_sources_test.dart` —— 向导的**输入框数**与**"获取密钥"链接数**，**按 `kDataSourceCatalog` 派生**（需密钥源数，双字段源另加）。加**需密钥**源必炸；反过来，某源若漏在向导 `_KeyEditor` 的 switch 里，这条也会炸 —— D9 时代它硬编码数字，所以漏了豆瓣照样绿（D11 根治）。双字段源集合现为 **igdb / podcastIndex** 两个（豆瓣 D12 退出）。
12. `test/shared/constants/source_catalog_region_test.dart` —— **钉死「境内源恰好是豆瓣 + 微信读书」**，并要求每行的 `apiHost` 非空且唯一。新源没分类或分类写反即炸（D15 加）。
13. `test/features/search/providers/source_region_default_test.dart` —— 钉死**默认开启集合**：书 = `douban` + `weread`、影 = `douban_movie`、动画 3 个全开（无境内源则一个都不关）。动 `_initiallyDisabledSourceIds` 的规则即炸（D15 加）。
11. `test/core/api/api_error_extract_test.dart` —— **遍历 `lib/core/api` 下所有 `implements Exception` 的类，缺一即炸**。加源的 `XxxApiException` 必须同时进 `extractApiError`（`lib/core/api/api_error_extract.dart`）的 switch，否则搜索错误条会显示类名与 `(status: null)`、且 `detail` 丢失。D13 补 9 个：本次新增的 NeoDB / Bangumi / WeRead ＋ 上游本就漏的 Kitsu / MangaDex / MusicBrainz / Podcast Index / TheTVDB / TVMaze。