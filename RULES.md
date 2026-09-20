# RULES.md — 规约总纲与坑点登记册

> **改动代码前先读完这份。** 本文是与开发无关紧要的「不许做 / 必须做 / 会炸」清单；实现层次的细节与 WHY 以 [`.claude/CLAUDE.md`](.claude/CLAUDE.md) 为准，那是本仓库最详细的开发规约，两者冲突时以 CLAUDE.md 为准。文档缺失段落可向 [`PROJECT.md`](PROJECT.md)（全景）与 [`TASK.md`](TASK.md)（任务）查询。

## 0. 权威性与优先级

| 级别 | 文件 | 内容 |
|:----:|------|------|
| 1 | `analysis_options.yaml` | 唯一事实来源（lint 规则），改它必须同步改 `docs/CODESTYLE.md` 对应段落 |
| 1 | `.claude/CLAUDE.md` | 最细实现规约；本文件的展开 |
| 2 | 本文件 `RULES.md` | 人类可读硬约束 + 坑点登记 |
| 3 | `PROJECT.md` / `TASK.md` | 定位与任务，不承担规约 |

冲突时按级别裁定，同级冲突以更具体者为准。

## 二、硬约束（违反即不可合并）

| # | 约束 | 后果 |
|:-:|------|------|
| R1 | **语言边界**：代码注释与提交信息一律英文；对用户与协作者的文档（README / PROJECT / TASK / RULES）用中文；UI 文案只能进 `.arb` | 中文注释进代码、硬编码 UI 串，必然被 review 打回 |
| R2 | **迁移链只可追加，绝不可修改既有迁移**；`schema.dart` 的 `create*Table` 与之等权不可变。加列用 `Migration.addColumnIfAbsent`，加索引用 `CREATE ... IF NOT EXISTS` | 改链 = 已装机用户的库升级错乱，等同事故 |
| R3 | **三端同绿**：Windows / Android / Web 任一不得破。Web 端问题无构建期提示（`dart:io` 会编译成桩）—— 只能靠 `kIsWebBuild` 运行时守卫 | 破一端的提交在 CI 必挂 |
| R4 | **HTTP 出口唯一**：一切客户端必须经 `createApiDio`（`lib/core/api/api_dio.dart`）。禁止自建 `Dio` | 绕开会漏掉 Web 端代理重写，浏览器里静默 403 |
| R5 | **严格类型**：禁 `dynamic`；公开 API 禁 `var`；一切返回与参数标注类型 | `analysis_options` 直接判负 |
| R6 | **UI 文案必须进 ARB**：`lib/l10n/app_*.arb` × 6 语言，键必须齐平 | 缺一语言 `gen-l10n` 失败 |
| R7 | **改动 DAO 或模型**：必须 `cd packages/core && dart run tool/generate_rpc.dart` 并提交生成物 | `generated_up_to_date_test` 必挂 |
| R8 | **引用路径必须已被 git 跟踪**：写进提交文件前用 `git ls-files <path>` 核验 | 幽灵链接，克隆后即死 |

## 三、加数据源 SOP（七步 + 两处连带 + 三处护栏）

新增一个数据源 = 增量七步，顺序可参考：

1. `packages/core/lib/models/data_source.dart` —— 枚举加值（颜色合规参考既有项）
2. `lib/shared/constants/data_source_ui.dart` —— 图标 switch 加分支（穷尽性会让编译器盯住你）
3. `lib/shared/constants/source_catalog.dart` —— `SourceInfo` 加行
4. `lib/features/search/sources/<源>_source.dart` —— 源实现（80–160 行，照 `bangumi_anime_source.dart` 抄壳）
5. `lib/core/api/<源>/` —— 三件套 + facade（types / http_client / search_api / `<源>_api.dart`）
6. `lib/features/search/sources/search_sources.dart` —— import + 实例；**列表顺序 = 主源/备源优先级**
7. 该源的筛选器（`lib/features/search/filters/<源>_*_filter.dart`，按需）

**Web 端另加**：`packages/core/lib/api/proxy_targets.dart` 一行；带密钥的还在 `server/lib/src/proxy_handler.dart` 的 `ApiProxy._authorize` 加分支。

**两个「漏了必串源」连带点**：

- `lib/features/collections/helpers/collection_actions.dart` —— 该媒体类型刷新 switch，新源 id 必须发对的查询目标（例子：Bangumi id 发去 AniList 查）
- 相似推荐等按源支配的穷尽 switch —— 不是我们源可用的端点，返回空即可

**五个「加了必炸」护栏**：

- `test/shared/widgets/source_badge_test.dart` —— `DataSource.values.length` 硬编码（19→20）
- `test/features/search/providers/browse_provider_test.dart` —— 该媒体可浏览源数硬编码（anime 2→3）
- `test/features/search/sources/search_sources_test.dart` —— 注册表 id 顺序表
- `test/features/search/sources/source_output_media_type_test.dart` —— 输出媒体类型断言
- RPC 一致性（见 R7，无幸免）

## 四、Windows 环境坑（全部伪装成"项目坏了"）

| # | 现象 | 真凶 | 规避 |
|:-:|------|------|------|
| P1 | 全部测试 `+0 -413`，报 `WebSocketException: Invalid WebSocket upgrade request` | `HTTP_PROXY` 指向沙箱代理，`NO_PROXY` 未设，flutter_tester 连 loopback 被拦 —— 极易误判为编译错误 | 带清代理跑：`env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy -u ALL_PROXY -u all_proxy NO_PROXY="127.0.0.1,localhost,::1" flutter test --no-pub` |
| P2 | `flutter analyze` 刷出 1 万+ `package:test` 错 | 子包依赖未装：根 `pub get` 不生成 `packages/core` / `server` 的 package_config | `dart pub get --directory packages/core` 与 `server` 各跑一遍 |
| P3 | `flutter run -d windows` 链接失败 | 缺 Visual Studio C++ 工作负载 + 插件符号链接受限 | 写码/分析/测试不受影响；要跑桌面需装 VS 组件 |
| P4 | 两份 `flutter test` 并发 → 交替 `PathAccessException` / `errno=5` 崩的是工具本身 | 撞 `build/native_assets/windows/sqlite3.dll` 文件锁 | 测试串行，绝不并发 |
| P5 | flutter_test 里没有真网络 | 测试绑定默认装「一律返回 400」的假 HttpOverrides | 在线验证需在 `ensureInitialized()` 后 `HttpOverrides.global = null;` |
| P6 | `flutter.bat` 经 cmd 吃裸 `|` | 命令行参数含 `\|` 时（如 `--coverage-package="tonkatsu_box\|core"`）需写 `.ps1` 或加引号 | 见 `.claude/CLAUDE.md` Toolchain |
| P7 | 覆盖率统计缺 `packages/core` | `flutter test --coverage` 默认只包当前包 | 永远传 `--coverage-package='tonkatsu_box\|core'` |

## 五、测试设施坑（mocktail，都是血泪）

- **`verify(...).captured` 的命名参数顺序无保证**：它遍历 role invocation 的 `namedArguments.keys`，**不是调用点书写顺序**。实测 8 个命名参数吐 `[sort, page, perPage, …]`，按书写序编号必全错位。症状：十几个断言全挂、可值明明发对。正解：`thenAnswer((Invocation invocation) {...})` 里按 `invocation.namedArguments[Symbol('x')]` 取。
- **本 SDK 的 `Symbol` 没有 `name` getter** —— 只能 `Symbol('x')` 相等查找，不能反向取名。
- **Dart VM 会把未传的可选命名参数默认值一并物化进 invocation**：调用点只传 8 个，得到 9 个 named 参数（多一个 `null` 的 `tags`）。查询按键断言用 `containsAll`，不要比集合相等。

## 六、数据源实测结论（2026-09-18）

**稳定可用**：Bangumi `api.bgm.tv/v0` · NeoDB `neodb.social/api/catalog/search` · 微信读书 `weread.qq.com/web/search/global`（**已接入，仅搜索** —— 无 by-id 端点，见七之四）· 优酷 `search.youku.com/api/search` · 爱奇艺 `mesh.if.iqiyi.com/.../homePageV3` · 网易云 · QQ 音乐。

**可用但限流极狠**：豆瓣 Frodo `frodo.douban.com/api/v2/*` —— HMAC-SHA1 签名（secret `bf7dddc7c9cfe6f7` + apiKey `0dad551ec0f84ed02907ff5c42e8ec70` + 配对 UA）；**连打 10 次即 403，冷却 3–5 分钟**；签名 path 必须等于最终请求 path（剧集 `/tv/{id}`，用 `/movie/{id}` 会 996）。

**免签补充**：`movie.douban.com/j/subject_suggest`（需 Referer），无限流，字段少。

**不可用**：猫眼（302）· B 站主站（412）· 哔哩哔哩漫画（code 99）· 快看（404）· 动漫之家（不可达）· 腾讯视频搜索（仅 HTML）· 芒果 TV（401）· RSSHub 公共实例（403 Cloudflare，自建可用）。

## 七、Bangumi 接入要点（首个源样板）

- 入口 `api.bgm.tv/v0`，免密钥，**必须带自定义 User-Agent**，否则 Cloudflare 403。
- 搜索 `POST /v0/search/subjects`（body `{keyword, sort, filter:{type:[2], meta_tags, air_date, rating, rank}}`）；详情 `GET /v0/subjects/{id}`。
- 代码位置：`lib/core/api/bangumi/` 三件套 + `bangumi_api.dart`（`bangumiApiProvider`）+ `bangumi_anime_source.dart`（id `bangumi_anime`）+ `bangumi_meta_tag_filter.dart` / `bangumi_rank_filter.dart`。
- 领域映射：`name_cn`→`title`，`name`→`titleNative`，`rating.score ×10`→`averageScore`（0–10 → 0–100），`date`/`air_date`→起播日月年，`eps`→集数，`platform`→format（TV/WEB→ONA、剧场版→MOVIE），`tags` 截 12 个且丢票数，infobox `动画制作`/`製作`→studios，外链 `bgm.tv/subject/{id}`。
- **空关键词浏览必须把 `sort` 从 `match` 兜底为 `rank`**：`match` 无关键词时结果无意义。
- **搜索接口的 `keyword` 与 `filter` 两路必须都传**：只传 `filter` 会 400。

## 七之二、NeoDB 接入要点（第二个源，2026-09-19）

- 入口 `neodb.social/api`，免密钥。**不要求自定义 User-Agent**（实测默认 UA / 空 UA 均 200）—— 与 Bangumi 的 Cloudflare 403 相反，别套用前者的经验。
- 搜索 `GET /api/catalog/search?query=&category=book&page=`；详情 `GET /api/{category}/{uuid}`（**按类目分流**，`/api/catalog/item/{uuid}` 是 404）。
- 代码位置：`lib/core/api/neodb/` 三件套 + `neodb_api.dart`（`neodbApiProvider`）+ `neodb_book_source.dart`（id `neodb`，无筛选器、单排序项）。
- **不支持空关键词浏览**：无 `query` → 422，空串 → 400。因此 `supportsBrowse = false`，并要设最小查询长度（2）。
- **分页只信 `pages` 字段**：接口会折叠同一作品的不同版本，每页条数不规则（实测第 1/2/3 页为 6/11/19 条），绝不能按条数推 `hasMore`。
- 领域映射：`localized_title` 数组挑 `zh-cn` → `title`，`orig_title`→`originalTitle`，`author` **优先取中文写法**（`["Cixin Liu","Liu Cixin","刘慈欣"]` → `["刘慈欣"]`），`pages` 可能是**字符串**，`isbn` 按长度分 10/13，`publisher` 空时退回 `pub_house`，`tags`→`subjects`（截 15），`series`→丛书，外链取 `id`（绝对路径）。
- **`rating` 已是 0–10，直接使用，不可乘 2**。×2 只适用于 OpenLibrary / Google Books / Hardcover 那类 0–5 刻度源；`Anime` 模型才是 0–100（Bangumi ×10）。**刻度搞错不会报错，只会显示离谱的分数**，务必看模型注释。
- **加图书源的连带点比动画更多**：`collection_actions.dart`（刷新，`if/else` 链，漏了就 unsupported）、`media_handlers.dart`（`_fetchFullBook`，漏了详情页无简介）、`import_service.dart`（`_fetchOneBook` + 构造注入 + provider watch，漏了导入丢条目）、`welcome_step_sources.dart`（漏了向导描述为空）。这四处都不报编译错。

### 七之三、NeoDB 影视类目补充（2026-09-20，`neodb_movie` / `neodb_tv`）

- **影视的 `display_title` 是英文名**，中文在 `localized_title` / `orig_title`。图书的 `display_title` 才是中文，别把图书经验套过来。
- **TV 只能以「季」为粒度**：`category=tv` 的搜索结果 `type` 恒为 `TVSeason`，标题自带季号；`TVShow` 本体只有打 `/api/tv/{parent_uuid}` 才拿得到，且它的 `localized_title` 常缺 `zh-cn`。所以映射到 `TvShow` 模型时用季记录的字段，**不要为每行结果再补一次 parent 请求**。
- **详情路径 = 类目（+ 段）**：电影 `/api/movie/{uuid}`；剧集是 `/api/tv/season/{uuid}`（多一段 `season`）。
- **搜索行没有 `year` / `length`**：年份只能扫 `tags` 里第一个「四位纯数字」，且要排除 `1990s` 这类年代段（实测年份漂在 `tags[0]` 或 `tags[1]`）；`length` 是**秒**，模型存分钟。`year` / `duration` / `imdb` 只有详情接口才有。
- **整型 id 反推不出 uuid**：`Movie` / `TvShow` 只有整型 id（`fnv1a64(uuid)`）且**没有 native-id 列**，`.xcoll` 与刷新都拿不回 uuid。刷新靠记录里的 `externalUrl` 反解（`neodbUuidFromUrl`）；纯 `native_id` 的降级导入路径对影视无效。**给影视加新源时若需要详情重取，必须先解决"id 不可逆"这件事**。
- 解析逻辑统一在 `packages/core/lib/utils/neodb_json.dart`，图书 / 电影 / 剧集共用；`book.dart` 的等价私有 helper 已改为委托，**别再各写一份**。

### 七之四、微信读书接入要点（2026-09-20，`weread`）

- **没有 by-id 详情端点**：`weread.qq.com/web/book/info?bookId=` 对未登录客户端返回 `{"errCode":-2010,"errMsg":"用户不存在"}`，官方没有公开的按 id 取书接口 → **只做搜索源**。详情与刷新靠「按标题重搜 + 精确匹配 `bookId`」（实测精确标题命中就在第 0 位）。`Book.nativeId` 存的就是 `bookId`，所以能对上。
- **`totalCount` / `hasMore` 都不可信**：同一关键词前两页 `totalCount=59`，第 3 页起跳到 `10087`；`hasMore` 恒为 1。**只有 `maxIdx` 偏移可用**（`maxIdx=(page-1)*count`），判页规则是「返回空页即终点」—— `browse_provider` 本身也这么兜底（*An empty page is the end no matter what hasMore claims*）。`count` 上限 50；每页条数不规则（实测 20/20/28/17/20），**不能拿「行数 < 请求数」判尾页**。
- **`newRating` 是 0–1000 刻度**（930 在客户端显示为 93.0）→ **除以 100** 得本应用的 0–10。既不是 ×2 也不是 ×10。缺 `newRating` 或为 0 的条目（网文常见）应留空，不要记 0 分。
- **`author` 是自由格式展示串**：`[哥]加西亚·马尔克斯`、`曹雪芹著 无名氏续 程伟元 高鹗整理`。**不可按空格切分**，否则凭空造出作者；整串放进 `authors` 单元素列表。
- **无 UA 要求**（Chrome / 应用 / 空 UA 实测均 200）。但注意：**用 curl 经沙箱代理探测时曾连续返回 0 字节**，一度误判为「UA 被拒」；清掉 `HTTP_PROXY` 等变量直连后同一请求正常返回 6303 字节。**探测网络接口务必先清代理**（同 P1 的规矩），否则会把代理噪声当成服务端行为。
- **`.xcoll` 降级导入无法解析微信读书条目**：`CollectionItem.toExport()` 只导出 `media_type / external_id / native_id / source`，**不含标题**，而重搜必须有标题。故该分支显式 `return null` 并注明原因；正常导入走内嵌媒体数据，不受影响。

### 七之五、宿主限流与 403 退避（2026-09-20）

`lib/core/api/host_rate_limiter.dart` 有**两道闸**，都由 `HostRateLimitInterceptor` 执行（`createApiDio` 自动挂载；**必须在 proxy rewrite 之前**，否则认到的是自托管服务器而非真实上游主机）。

- **闸一 · 最小间隔**（`kHostMinRequestGap`）：按主机 FIFO 串行，两次请求的**发起**时刻至少隔开给定间隔。**响应不等**，只错开发起。
- **闸二 · 断路器**（`kHostBackoffPolicy`）：`HostBackoffPolicy(maxBurst, cooldown)` 就是「连打 N 次 → 冷却 M 分钟」。同一波（相邻两次间隔小于 `cooldown`）放行 `maxBurst` 次，第 `maxBurst + 1` 次**直接抛 `HostCooldownException`、不发网**；冷却到期自动恢复。`cooldown` 兼作「多长的间隔算换了一波」，所以零星散布的调用永远攒不到上限。
- **两个触发源**：① 次数到顶（主动预防）；② 收到 **402 / 403 / 429** 响应（被动，自被拒那刻立即开闸）。二者共用同一只 `cooldown`。
- **同域共享**：查表先精确匹配，再逐级剥掉最左标签往父域找（`frodo.douban.com` → `douban.com`），且**限流器按命中的表键缓存** ⇒ `frodo` / `book` / `movie` 三个子域**共用一份预算**。理由：豆瓣按客户端计数，一个子域一把队列等于把允许量乘以子域个数。
- **豆瓣取值**：`maxBurst: 9`、`cooldown: 5min`、间隔 `800ms`。实测十连打即 403、冷却 3–5 分钟，故**比实测少放一次**再开闸，让封禁永远挣不到。
- **`acquire()` 抛错不得污染队列**：`_tail` 必须用 `then(onError:)` 吞掉被拒的那一对 future，否则后续调用会链在已作废的 future 上，抛的是**上一个**异常而不是自己的判断。
- **文案的现实折衷（务必知悉）**：冷却文案挂在 `DioException.error` 上。但**各源的 `handleDioException` 会把 DioException 包成自家异常并套通用措辞**（全仓 112 处 `on DioException catch`），故对**既有源**而言用户看到的仍是该源的通用文案，精确原因（主机 + 剩余秒数）落在「详情」面板的 `Cause:` 行（`buildApiErrorDetail` 自动收 `exception.error.toString()`）。`extractApiError` 已为 `HostCooldownException` 注册分支，供未被包装的路径与**新写的源**取用 —— **接豆瓣源时，其 `handleDioException` 应优先判 `e.error is HostCooldownException` 并采用其文案**。

## 八、提交约定（对齐上游 `docs/COMMITS.md`）

Conventional Commits：`type(scope): desc`。本分支自带前缀惯例：**国内源相关用 `feat(cn-*)` scope**（如 `feat(cn-bangumi): add Bangumi anime source`、`feat(cn-neodb): add NeoDB book source`），以便 grep 区分上游/分支。

## 九、定义完成（必须全绿再收工）

1. `flutter analyze --fatal-infos --fatal-warnings` **零输出**
2. `flutter test` · `dart test`（packages/core）· `dart test`（server）**全绿**
3. RPC 生成物 `git diff --exit-code -- packages/core/lib/rpc/generated` 为空
4. **在线活体验证**通过（临时插真实 API；不允许"测试都过了"当完工）
5. 护栏、ARB 键数（6×1745 全齐）、`TASK.md` 状态同步

按此清单跑完，再回头补文档与记忆。