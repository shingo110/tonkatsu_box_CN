# TASK.md — 任务清单

活的待办清单。条目随状态变化更新：完成的移到「✅ 已完成」，开始做的标"进行中"，未立项的留在「📋 候选」。**"完成"的定义见 [`PROJECT.md`](PROJECT.md) 第 9 节** —— 测试通过不算数，必须在线验证过关键字段才算。

## 状态

- **已完成**：M0 开工就绪度核验 · M1 Bangumi 全链路接入 · M2 NeoDB 图书接入 · M3 NeoDB 电影 / 剧集接入 · M4 微信读书图书接入 · D6 豆瓣 403 退避 · D7 豆瓣 ISBN 直查接入
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

## 📋 候选（下一步从这里挑）

> 接入优先序共识：**Bangumi ✅ > NeoDB 图书 ✅ > NeoDB 影视 ✅ > 微信读书 ✅ > 豆瓣（图书 ISBN 直查）✅ > 豆瓣影视 ✅ > 优酷/爱奇艺 > 漫画**。豆瓣元数据最全但引入签名 + 403 两个新变量，且 NeoDB 已是豆瓣数据的免密钥代理，故一直排在最后；其**图书线已于 D7、影视线已于 D8 落地**（两个新变量都已验证：403 退避 D6 + 签名 D7）。豆瓣线至此**全部完成**。

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

### T5. 漫画线调研

- 已实测失败：B 站漫画（code 99）· 快看（404）· 动漫之家（不可达）。
- 候选路径：NeoDB 覆盖漫画条目；或爬自有公开 API 的中文漫画库（如 `ggzy` 系开源代理，需先验合规与稳定性）。
- 验收：找到免密钥可直连 5 秒内响应的候选再立项。

---

## 🔧 阻塞与长期债

| # | 事项 | 现状 | 影响 |
|:-:|------|------|------|
| B1 | Windows 桌面运行 | 缺 Visual Studio C++ 工作负载 + 插件符号链接受限 → `flutter run -d windows` 不可用 | 无法桌面预览；写码/分析/测试不受影响 |
| B2 | Web 端 /proxy 全链路验证 | 白名单已加 `api.bgm.tv` / `neodb.social` / `weread.qq.com` / `frodo.douban.com`，**均未做真实自托管 + 浏览器链路验证**（豆瓣的服务端签名逻辑已有单测钉死） | 发布 Web 前必须补 |
| B3 | 上游同步 | fork 基线 0.44.0；上游以周为节奏发版 | 每次同步人造裁决冲突清单见 PROJECT.md §3 |
| B4 | 中文数据源覆盖 | 动画 ✅（Bangumi）；图书 ✅（NeoDB / 微信读书 / **豆瓣**）；电影 / 剧集 ✅（NeoDB / **豆瓣**）；漫画未定 | 漫画线（T5）已知候选全灭，待找免密钥可直连的库 |

## 护栏速查（改代码前看一眼，防炸）

1. `test/shared/widgets/source_badge_test.dart` —— `DataSource.values.length` 硬编码（现 **23**），加枚举即炸。
2. `test/features/search/providers/browse_provider_test.dart` —— 该媒体可浏览源数硬编码，加源即炸（**仅可浏览类型**；图书走 `textQueryOnly`，无此断言）。
3. `test/features/search/sources/search_sources_test.dart` —— 注册表 id 顺序表，加源须补序。
4. `test/shared/constants/source_catalog_test.dart` —— **「哪些源要密钥」的集合写死**（断言 `keyRequirement != none` 的源**恰好等于**那组枚举）。加任何**需密钥**的源即炸；D7 才把它编入护栏。
5. RPC：改 DAO/模型 → `dart run tool/generate_rpc.dart` → 提交生成物，否则 `dart test` 必挂，无幸免。
6. mocktail 断言命名参数：**不要用 `verify(...).captured` 按位取**（顺序无保证），在 `thenAnswer` 里按 `Symbol('x')` 取。
7. **同一条消息里对同一个文件不要发两次编辑** —— 实测最多只有一次生效，其余静默丢失且不报错。改完同一文件的多处，务必拆成多次调用并逐处 grep 复核。
8. `lib/core/api/episode_source/tv_episode_source.dart` —— **影视源必须给 `tvEpisodeSourceResolverProvider` 加一支**（它是 `_ => tmdb` 兜底）。漏了不报任何错，但 `TvShowCacheWarmer` 与 `_refreshedTvShow` 会拿新源的 id 去 TMDB 查，**可能把不相干的剧写进缓存**。
9. **影视的 `CollectionItem.nativeId` 恒为 null**（该 getter 只对 book / audio 生效）—— 刷新与 `.xcoll` 导入一律用 `externalId`。