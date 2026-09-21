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
| R9 | **凭据字面量只准存在于它唯一的那处来源**：内置的第三方密钥（如豆瓣那对公开凭据）客户端在 `lib/shared/constants/douban_defaults*.dart`、服务端在 `server/lib/src/douban_defaults.dart`；**文档与测试一律引用常量，不得复制字面量** | 每多一份副本就多一个被爬虫 / 代码搜索捞走的点，且值一换就要全仓追杀 |

## 三、加数据源 SOP（八步 + 三处连带 + 八处护栏）

新增一个数据源 = 增量七步，顺序可参考：

1. `packages/core/lib/models/data_source.dart` —— 枚举加值（颜色合规参考既有项）
2. `lib/shared/constants/data_source_ui.dart` —— 图标 switch 加分支（穷尽性会让编译器盯住你）
3. `lib/shared/constants/source_catalog.dart` —— `SourceInfo` 加行。**`region` 与 `apiHost` 都是必填**：
   `apiHost` 是连通性自检要敲的主机（站点与 API 往往不同域），`region` 决定它是否默认开启、
   界面是否标「需国际网络」。分类依据是 **DNS 归属**，不是印象 —— 跑 `probe/host_reachability_audit.py`
4. `lib/features/search/sources/<源>_source.dart` —— 源实现（80–160 行，照 `bangumi_anime_source.dart` 抄壳）
5. `lib/core/api/<源>/` —— 三件套 + facade（types / http_client / search_api / `<源>_api.dart`）
6. `lib/features/search/sources/search_sources.dart` —— import + 实例；**列表顺序 = 主源/备源优先级**
7. 该源的筛选器（`lib/features/search/filters/<源>_*_filter.dart`，按需）
8. **仅需密钥的源**（`keyRequirement != none`）另加两处 UI，**全靠手写、漏了不报编译错**：
   - `lib/features/settings/content/credentials_content.dart` —— 一节（`_buildSourceHeader(source: …)` 自动给出"获取密钥"链接 + 输入框 + 提示）
   - `lib/features/welcome/widgets/welcome_step_sources.dart` —— `_KeyEditor.build` 的 **switch 加一支**（漏 → 向导卡片整块空白，无输入框无链接无提示）与 `_KeyBadge._resolve` 的 **mandatory 分支加判定**（漏 → 落到 IGDB 的 `hasCredentials`，误报"密钥已保存"）

**Web 端另加**：`packages/core/lib/api/proxy_targets.dart` 一行；带密钥的还在 `server/lib/src/proxy_handler.dart` 的 `ApiProxy._authorize` 加分支。

**三个「漏了不报错、只静默降级」连带点**：

- `lib/features/collections/helpers/collection_actions.dart` —— 该媒体类型刷新 switch，新源 id 必须发对的查询目标（例子：Bangumi id 发去 AniList 查）
- 相似推荐等按源支配的穷尽 switch —— 不是我们源可用的端点，返回空即可
- `lib/core/api/api_error_extract.dart` —— 新源的 `XxxApiException` 必须在 `extractApiError` 的
  switch 里占一支。**这张表是手写枚举，漏了不报编译错**，后果是搜索错误条直接显示
  `XxxApiException: … (status: null)`（内部类名 + 内部字段）而不是一句人话，且 `detail` 一并丢失、
  Tooltip 空白。D13 一次补齐 9 个（新源 NeoDB / Bangumi / WeRead + 上游本就漏的 6 个）。

**「加了必炸」护栏速查**（不写条数 —— 数字会烂，这份清单不会）：

- `test/shared/widgets/source_badge_test.dart` —— `DataSource.values.length` 硬编码（现 **25**）
- `test/features/search/providers/browse_provider_test.dart` —— 该媒体可浏览源数硬编码（anime 2→3）
- `test/features/search/sources/search_sources_test.dart` —— 注册表 id 顺序表
- `test/features/search/sources/source_output_media_type_test.dart` —— 输出媒体类型断言
- `test/shared/constants/source_catalog_test.dart` —— "哪些源要密钥"的集合写死（**加需密钥源必炸**）
- `test/features/welcome/widgets/welcome_step_sources_test.dart` —— 向导输入框数与"获取密钥"链接数，按目录派生（**加需密钥源必炸**；漏源同样炸）
- `test/core/api/api_error_extract_test.dart` —— **遍历 `lib/core/api` 下所有 `implements Exception`
  的类，缺一即炸**（D13 加）。此前只有手写的用例表，所以 NeoDB / Bangumi 漏了照样绿。
- `test/shared/constants/source_catalog_region_test.dart` —— **钉死「境内源恰好是豆瓣 + 微信读书 +
  TapTap + 喜马拉雅」**，并要求每行都有非空且**唯一**的 `apiHost`（D15 加）。新源没分类、或分类写反，即红。
- `test/features/search/providers/source_region_default_test.dart` —— 钉死**默认开启集合**：有境内源的
  类型只留境内源（书 = `douban` + `weread`，影 = `douban_movie`，动画 = `douban_anime`，
  音频 = `douban_music` + `ximalaya_podcast`，游戏 = `taptap_games`），无境内源的类型一个也不关
  （D19 起**只剩漫画与视觉小说**）。动了 `_initiallyDisabledSourceIds` 的规则即红。
- ⚠️ **按位置下标取目录的测试是隐性护栏**：`reachability_screen_test` 原用 `kDataSourceCatalog[i]`
  挑罐头数据，TapTap 插在 igdb 之后把 `neodb` 从下标 10 挪到 11 ⇒ 断言以毫不相干的方式变红。
  D19 已改为按 `DataSource` 经 `sourceInfoFor` 取。**写新测试不要按目录下标取源。**
- RPC 一致性（见 R7，无幸免）

## 四、Windows 环境坑（全部伪装成"项目坏了"）

| # | 现象 | 真凶 | 规避 |
|:-:|------|------|------|
| P1 | 全部测试 `+0 -413`，报 `WebSocketException: Invalid WebSocket upgrade request` | `HTTP_PROXY` 指向沙箱代理，`NO_PROXY` 未设，flutter_tester 连 loopback 被拦 —— 极易误判为编译错误 | 带清代理跑：`env -u HTTP_PROXY -u HTTPS_PROXY -u http_proxy -u https_proxy -u ALL_PROXY -u all_proxy NO_PROXY="127.0.0.1,localhost,::1" flutter test --no-pub` |
| P2 | `flutter analyze` 刷出 1 万+ `package:test` 错 | 子包依赖未装：根 `pub get` 不生成 `packages/core` / `server` 的 package_config | `dart pub get --directory packages/core` 与 `server` 各跑一遍 |
| P3 | `flutter run -d windows` 链接失败 | 缺 Visual Studio C++ 工作负载 + 插件符号链接受限 | 写码/分析/测试不受影响。本机实测全盘无 VS 与 Windows SDK（`flutter doctor` 报 `[X] Visual Studio`），要跑桌面须装 VS 2022 + 「使用 C++ 的桌面开发」工作负载（含 Windows SDK）。**替代路径：上游 `release.yml` 已用 `windows-2022` runner 在 CI 里出 Windows 包，无需本机 VS** |
| P4 | 两份 `flutter test` 并发 → 交替 `PathAccessException` / `errno=5` 崩的是工具本身 | 撞 `build/native_assets/windows/sqlite3.dll` 文件锁 | 测试串行，绝不并发 |
| P5 | flutter_test 里没有真网络 | 测试绑定默认装「一律返回 400」的假 HttpOverrides | 在线验证需在 `ensureInitialized()` 后 `HttpOverrides.global = null;` |
| P6 | `flutter.bat` 经 cmd 吃裸 `|` | 命令行参数含 `\|` 时（如 `--coverage-package="tonkatsu_box\|core"`）需写 `.ps1` 或加引号 | 见 `.claude/CLAUDE.md` Toolchain |
| P7 | 覆盖率统计缺 `packages/core` | `flutter test --coverage` 默认只包当前包 | 永远传 `--coverage-package='tonkatsu_box\|core'` |
| P8 | `git status` 恒显 `[ahead N]`，可远端其实早已收到推送 | `refs/remotes/origin/main` 卡在 fork 起点（`f2ed6e08`，只存在于 `.git/packed-refs`）；**本仓实测 `git update-ref` 返回 `rc=0` 却不落盘**，`.git/refs/remotes/` 始终为空 | **判据一律用 `git ls-remote origin main`**（权威），不要信 `git status` 的 ahead/behind。修法：`mkdir -p .git/refs/remotes/origin && git rev-parse refs/heads/main > .git/refs/remotes/origin/main`（纯 shell 直写能落盘） |
| P9 | `flutter build apk --release` 首次耗时离谱（实测 **38 分钟**），中途可能抛 `Could not download core-1.15.0.aar … C:\Users\ZL\.gradle\.tmp\gradle_download*.bin (拒绝访问。)` | ① 首次要联网拉 Gradle 8.14-all（360 MB）+ Maven 依赖约 1.7 GB，经沙箱代理很慢；② 那句「拒绝访问」是临时文件被瞬时占用（**不是权限缺失** —— 同一目录手工读写正常），重试即过 | **直接重试**（缓存已留下，第二次 13 分钟）。进度判据：`du -sh ~/.gradle/caches/modules-2` 是否还在涨。另需 `android/key.properties`（已 gitignore，模板见 `docs/CONTRIBUTING.md`），缺则 release 签名直接失败 |
| P10 | 构建日志刷 `this and base files have different roots: C:\Users\ZL\AppData\Local\Pub\Cache\… and D:\Projects\…\android` 的 suppressed 异常 | pub 缓存在 C:、项目在 D:，Kotlin 增量编译器无法跨盘相对化路径 | **不影响产物，APK 照常生成，可忽略**；实在碍眼就删 `build/<plugin>/kotlin/`，或把 `PUB_CACHE` 也挪到 D: |
| P11 | 用 Python 补丁脚本改本仓库文件时，多行锚点**看着一模一样**却 `count == 0` | 工作树是 **CRLF**，而脚本里的锚点习惯按 `\n` 书写 | 替换函数里按目标文件**实际行尾**归一化（`eol = '\r\n' if '\r\n' in text else '\n'`，读文件用 `newline=''`）。逐行改写 JSON / arb 时**要保留行尾的 `\r`**，否则整文件行尾被改写。新写的 Dart 文件默认 LF，提交前转 CRLF。**注**：Edit 工具本身会保留 CRLF，只有手写脚本要自己管 |
| P12 | 想校验 APK 签名，`cmd //c "…apksigner.bat …"` 一条输出都没有 | 同「PowerShell 无 stdout」一类，沙箱 shim 截断 | **直接用 POSIX 路径调用 `.bat`**：`"D:/Software/Android/build-tools/37.0.0/apksigner.bat" verify --print-certs <apk>`。另：`llvm-objcopy … Permission denied`（x86_64 符号表）**不致命** —— APK 照常产出、三 ABI 齐全，只少 Play 用的调试符号 |

## 五、测试设施坑（mocktail，都是血泪）

- **`verify(...).captured` 的命名参数顺序无保证**：它遍历 role invocation 的 `namedArguments.keys`，**不是调用点书写顺序**。实测 8 个命名参数吐 `[sort, page, perPage, …]`，按书写序编号必全错位。症状：十几个断言全挂、可值明明发对。正解：`thenAnswer((Invocation invocation) {...})` 里按 `invocation.namedArguments[Symbol('x')]` 取。
- **本 SDK 的 `Symbol` 没有 `name` getter** —— 只能 `Symbol('x')` 相等查找，不能反向取名。
- **Dart VM 会把未传的可选命名参数默认值一并物化进 invocation**：调用点只传 8 个，得到 9 个 named 参数（多一个 `null` 的 `tags`）。查询按键断言用 `containsAll`，不要比集合相等。

## 六、数据源实测结论（2026-09-18）

**稳定可用**：Bangumi `api.bgm.tv/v0` · NeoDB `neodb.social/api/catalog/search` · 微信读书 `weread.qq.com/web/search/global`（**已接入，仅搜索** —— 无 by-id 端点，见七之四）· 优酷 `search.youku.com/api/search` · 爱奇艺 `mesh.if.iqiyi.com/.../homePageV3` · 网易云 · QQ 音乐。

**可用但限流极狠**：豆瓣 Frodo `frodo.douban.com/api/v2/*` —— HMAC-SHA1 签名（**apiKey / secret 的取值只认
`lib/shared/constants/douban_defaults_io.dart`（客户端）与 `server/lib/src/douban_defaults.dart`（服务端兜底），
本文件不再复制其字面量** —— 那对是 Frodo 官方客户端自带的公开配对，多抄一份只是多一个被爬虫与代码搜索捞走的
点；+ 配对 UA）；**连打 10 次即 403，冷却 3–5 分钟**；签名 path 必须等于最终请求 path（剧集 `/tv/{id}`，用
`/movie/{id}` 会 996）。**图书源已接入（ISBN 直查 + 关键词搜索），契约详见七之六。**

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

### 七之六、豆瓣接入要点（2026-09-20，`douban`，图书）

- **签名**：`_sig = base64(HMAC-SHA1(secret, "GET&" + urlencode(path, safe='') + "&" + _ts))`，path **不含 query**、**含前导 `/`**，且必须与最终请求路径逐字符一致。实现 `packages/core/lib/api/douban_signature.dart`（放 `core` 而非 `lib`，因为 **server 端签名要用同一份**），已与 Python 参考实现 **5 组向量逐字节锁定**（`packages/core/test/api/douban_signature_test.dart`）。客户端每条请求现算（`_ts` 分钟级过期），不做缓存。
- **凭据用户自填、源码不内置**：`SettingsKeys` → `ApiKeys.fromPrefs` → 凭据页（key + secret + 「测试」动作）→ 6 语言 l10n，照本仓已有四例（RA / ComicVine / Hardcover / Google Books）范式，**不新造存储设施**。**native 端无凭据则不发请求、直接返空**（`_canRequest` 守卫）；**Web 端豁免** —— 密钥在服务端，浏览器本就不该持有。
- **UA 必须与客户端配对**（`api-client/1 com.douban.frodo/7.22.0(230) …`），否则 403。Web 端 `createApiDio` 会剥掉 UA，故 **由代理端补**（`proxy_handler` 的 `_authorize` 设 `kDoubanUserAgent`）。
- **双后端单源**：查询词形如 ISBN（去连字符后 10 位 `[0-9Xx]` 或 13 位数字）→ `/api/v2/book/isbn/{isbn}`；否则 → `/api/v2/search/book`。**单后端会让每次关键词搜索都白发一发到易封主机**，双后端同时是省额度之选。
- **分页是偏移制**：搜索用 `start` / `count`（`start = (page - 1) * count`），响应 `total` 给总命中数 ⇒ `hasMore = start + 本页条数 < total`；缺 `total` 时只能以「满页」兜底。
- **搜索结果与详情记录是两种形状**（最易踩）：搜索响应顶层键是 **`items`**（不是 `books`），每条把记录包在 **`target`** 下，作者 / 年份 / 出版社被压成 **`card_subtitle`** 单串（`"刘慈欣 / 2008 / 重庆出版社"`）；**by-ISBN / by-id 的记录才是平铺的完整字段**。只按后者写解析 ⇒ **搜索结果全空且不报任何错**。
- **量纲**：`rating.value` 已是 0–10，**直接用，不可乘 2**（与 NeoDB 同规矩）。**出版社在 `press`，没有 `publisher`**；`pubdate` / `pages` / `price` **都是数组**，取首元素；封面兜底 `pic.large`。
- **响应不回显 ISBN** ⇒ `native_id` 存**查询所用的 ISBN**，刷新按 ISBN 重查，**不存在 id 反解问题**（比 NeoDB 影视省事）；有 by-id 端点 ⇒ `import_service` 的 `.xcoll` 降级路径**可以解析**（与微信读书相反，别照拄后者的 `return null`）。
- **`handleDioException` 优先判 `e.error is HostCooldownException`** 并采用其文案（见七之五的「文案现实折衷」）—— 本源的断路器拒绝发生在发网之前，只有这条文案能告诉用户还要等多久。
- 免签两路已确认死路，勿再试：`book.douban.com/isbn/{isbn}` 跳 301 到 HTML；`movie.douban.com/j/subject_suggest` 对 ISBN 返空数组。

### 七之七、豆瓣影视接入要点（2026-09-20，`douban_movie` / `douban_tv`）

- **`/api/v2/search/movie` 是电影与剧集的混合池，`type` 参数无效。** 实测同一查询分别带 `type=movie`、不带 `type`、带 `type=tv`，三次响应**逐字节相同**且都是混排（`total` 都是 27）。**分流只能自己做**：每行有 `target_type`（`movie` / `tv`）与 `type_name`（`电影` / `电视剧`）。**只看 `type=tv` 那次「生效」会得出错误结论** —— 「狂飙」本身就是剧集，默认结果自然全是剧集。
- **分页要按混合池推进**：`total` 是混排总数（「三体」27 条里电影只有几条），过滤后每页条数不定。`hasMore` 用 **host 实际返回的行数**（`items.length`）算，**不能用过滤后的条数** —— 否则会提前判尾页。这与微信读书「别用行数判尾页」是同一类坑的另一面。
- **详情路径分道**：电影 `/api/v2/movie/{id}`、剧集 `/api/v2/tv/{id}`；**剧集 id 送 `/movie/` 会回 996**。响应 73 字段，`subtype` / `type` 标 `movie` / `tv`。
- **`card_subtitle` 两种形状**：搜索行 `"中国大陆 / 科幻 冒险 灾难 / 郭帆 / 吴京 刘德华"`（国家 / 类型 / 导演 / 演员），**详情记录多一个前导年份** `"2023 / 中国大陆 / 科幻 冒险 灾难 / …"`。取类型要**按形状判槽位**（首段是四位年份则取第 3 段，否则第 2 段）—— 一律取第 2 段会把「中国大陆」当类型。（图书的 `card_subtitle` 语义又不同：`作者 / 年 / 出版社`。）
- **`original_title` 实测为空**，英文名只在 `aka` 数组里。取第一个**不含汉字**的别名 —— 只查 `[A-Za-z]` 会误取 `"流浪地球2(3D版)"`（中文别名里夹着 `3D`）。
- **`rating.value` 已是 0–10**，直接用（与图书同）。`durations` 是数组（`["173分钟"]`）取首元素抽数字；`episodes_count` 只有剧集有（电影为 0）；`first_air_time` 虽在字段表里但**实测为 null**，年份一律取 `year`。
- **搜索行没有 `intro`**（`abstract` 恒为空串）⇒ 搜索结果无简介，影视详情页也不做 lazy-load，所以**豆瓣影视收藏后简介为空**。剧集靠 `TvShowCacheWarmer` 在收藏时补（见下条），**电影没有这一步**，需手动刷新。
- **`tvEpisodeSourceResolverProvider` 是 `_ => tmdb` 兜底 —— 加影视源必须同时给它一支。** 否则 `TvShowCacheWarmer` 与 `_refreshedTvShow` 会拿豆瓣 id 去 TMDB 查，**可能把不相干的剧写进缓存**（静默串源，不报任何错）。已加 `DoubanEpisodeSource`：只 `getShow` 干活（借 warmer 补全记录与简介），`getSeasons` / `getSeasonEpisodes` 返回空 —— 豆瓣**没有季切分、也没有集列表**，宁可空也不编。
- **刷新与 `.xcoll` 导入用 `externalId`**：豆瓣 subject id 本身就是十进制数字，`Movie.tmdbId` / `TvShow.tmdbId` 直接存它，**不需要 NeoDB 那套 URL 反解**。注意 `CollectionItem.nativeId` 只对 book / audio 生效，影视一律走 `externalId`。
- 源 id `douban_movie` / `douban_tv`，均 `supportsBrowse=false`、无筛选器、单排序项，**注册在 keyless 的 NeoDB 影视源之后**。二者与图书源共享 `DataSource.douban` ⇒ 凭据页与向导文案**零新增键**。
- 活体验证（7 发内）：「流浪地球2」→ `id=35267208` / year 2023 / rating 8.3；`/movie/35267208` → 73 字段 / `durations=["173分钟"]` / `genres=[科幻, 冒险, 灾难]` / 完整 `intro`；「狂飙」→ `/tv/35465232` / 39 集。

### 七之八、Bangumi 漫画接入要点（2026-09-20，`bangumi_manga`）

**漫画线不必另找数据源。** 调研（T5）曾判定国内漫画候选全灭，但 Bangumi 本身就是漫画 / 轻小说类目最全的免费源：它的**书籍类型（`type=1`）**覆盖漫画、轻小说与画集，用 **`meta_tags` 里的「漫画」** 即可切出漫画。实测「海贼王」：不带该标签 174 条（混入小说、画集，`tags` 为空），带上 12 条全是漫画。

- **一个枚举可承载多个媒体类型**：`DataSource.bangumi` 已被动画源占用，漫画源**复用**它，故 `source_badge_test` 的 `DataSource.values.length` **不变**（仍 23）。这不同于加一个新目录服务 —— 那种情况才需要动枚举与 `SourceCatalog` 的密钥集合断言。
- **`meta_tags` 是 AND 语义**（`bangumi_meta_tag_filter.dart` 的注释已记），故 `['漫画', '日本']` 是「漫画 且 日本」。客户端在 `BangumiApi.browseManga` 里**始终把「漫画」前置**，用户的额外选择追加在其后；顺序不影响结果集。
- **`platform` 恒为「漫画」** ⇒ `format` 恒为 `MANGA`；`bangumiMangaFormat` 只认这一个值，其余返 null（能走到这里的行本就不该不是漫画）。
- **`eps` 与 `total_episodes` 恒等**（实测 12 条全等），取 `eps` 即话数；**两者与 `volumes` 的 0 表示未填写**，必须转 null，否则会把「未统计」当「0 话」。
- **`status` 只能从 `meta_tags` 推导**：Bangumi 没有连载状态字段，但 meta 标签里有「连载中」/「已完结」。映射到 AniList 词汇 `RELEASING` / `FINISHED`；未来日期仍走 `NOT_YET_RELEASED`（优先于标签）。
- **`authors` 取 infobox 的「作者」**（漫画），而动画源取「动画制作 / 製作 / 制作」；两者的回退链不同，故 `bangumi_json.dart` 提供 `bangumiMangaAuthors` 与 `bangumiAnimeStudios` 两个函数。
- **评分与动画同规矩**：`rating.score` 是 0–10，乘 10 存入 0–100 的 `averageScore`。
- **解析 helper 已抽到 `packages/core/lib/utils/bangumi_json.dart`**（`bangumi_json` 系列），`Anime.fromBangumi` 已改为委托（与 `neodb_json.dart`、`douban_json.dart` 同范式）。新增 Bangumi 系媒体类型时**不要再各写一份**。
- **搜索客户端已泛型化**：`BangumiSearchApi.searchSubjects<T>({required parse, subjectType})` 与 `getSubject<T>(id, parse)`，动画传 `Anime.fromBangumi`、漫画传 `Manga.fromBangumi`；`subjectType` 默认动画（2），书籍为 1。
- **连带必改（漏了会静默串源，均不报编译错）**：`collection_actions.dart` 的 **`MediaType.manga` switch**（其 `default` 兜底到 AniList —— 不加 Bangumi 支会把 Bangumi id 送去 AniList 查）与 `import_service.dart` 的 `_fetchOneManga`。
- **顺带修的既有缺陷**：`import_service.dart` 的 `_fetchOneAnime` 此前**只有 Kitsu 与 AniList 两支**，Bangumi 动画的 `.xcoll` 导入会把 id 送去 AniList。同轮补上，与 `collection_actions` 那边的刷新路径对齐。
- **护栏（新撞一处）**：`test/features/search/providers/browse_provider_test.dart` 硬编码漫画类型的**可浏览源数**（4 → 5）与 `unsupportedSourceIds`（漫画源没有共享的 `status` 筛选器，故加入其中）；其中 `seedLoaded` 助手的 `disabledSourceIds` 也必须补上新源，否则该源会被触发加载、"asks nobody" 不再成立。另外 `search_sources_test` 的 id 顺序表与 `source_output_media_type_test` 各补一条。

### 七之九、自托管 /proxy 验证要点（2026-09-20，B2 闭环）

**Web 端没有直连**：浏览器的跨域、UA 剥离、密钥不下发三条限制，决定了 Web 构建下所有外部请求都要
经服务端 `/proxy/<slug>/…`。这条链路现在有三道防线，改代理相关代码前先读这一节。

- **白名单是允许清单，不是开放中继**：`packages/core/lib/api/proxy_targets.dart` 的 `ProxyTarget`
  是唯一真相 —— `proxyTargetForHost`（客户端改写用）与 `proxyTargetForSlug`（服务端路由用）遍历同
  一枚举。**加源时 Web 端只需确认该 host 已在枚举里**：缺了不报任何错，浏览器会静默直连然后被 CORS
  拦掉，症状是「桌面能用、Web 空白」。
- **客户端改写与服务端还原是一对逆运算**：客户端把 `https://<host><path>?<query>` 改写成
  `<selfhost>/proxy/<slug><path>?<query>`；服务端取 `pathSegments[1]` 当 slug、`skip(2)` 当上游路
  径。两者由 `test/core/api/proxy_round_trip_test.dart` 对**全部** `ProxyTarget` 钉死，含裸主机
  （AniList 的 POST 目标上游路径为空）与百分号编码。
- **代理永远自带 `User-Agent`**（`kProxyUserAgent`）且**只转发 `content-type` / `accept`**：调用方
  自带的 `Authorization` 一律被剥离，凭据由服务端注入；豆瓣还要改穿 Frodo 自己的 UA。
- **服务端限流与客户端断路器是两套**：`proxy_handler.dart` 的 `_minRequestGap` 按主机在**服务端**
  串行（MusicBrainz 1.1s、豆瓣 0.8s）—— 一次封禁覆盖本服务器背后的所有标签页，客户端断路器看不到
  别的浏览器的流量。新增有封禁史的主机时**两处都要配**。
- **`/proxy` 必须绕开 Web 静态回退**：`app_handler.dart` 的 `_withWebFallback` 把 `/health`、
  `/rpc`、`/proxy/`、`/images/` 判为 API 路径直连 router。漏了这条，未知上游会拿到 index.html +
  200（读起来像成功，把错误埋掉）。`proxy_serve_integration_test.dart` 有专门一例盯着它。
- **验证手法**：离线两条（真 socket 集成 + 跨层往返）随 CI 走；要真上游复核时跑
  `probe/selfhost_proxy_live.py` —— 起真二进制、绑 127.0.0.1 随机端口、按浏览器形状发请求，并把代
  理响应与直连响应做 sha256 比对。**活体脚本不进 CI**（要外网、会碰限流）。

### 七之十、密钥界面契约（2026-09-20，D11 修瑕疵时确立）

**两个界面**都能配密钥，且都必须与 `kDataSourceCatalog` 保持一致：

| 界面 | 文件 | "要密钥"的判据 |
|---|---|---|
| 设置页 | `lib/features/settings/content/credentials_content.dart` | 手写节，逐节给 `source:` |
| 首次向导 | `lib/features/welcome/widgets/welcome_step_sources.dart` | 目录驱动（`info.keyRequirement`） |

- **"获取密钥"链接取自目录**：`SourceInfo.url` 的语义就是 *"Get a key link target"*。设置页走
  `_keyUrlFor(source)`，向导走 `info.url` ⇒ **两端同源，不可能漂移**。`SourceInfo.keyRequirement == none`
  的源不渲染链接。
- **提示文案按 `keyRequirement` 分流**：`credentialsOwnKeyHint`（"建议用自己的密钥"）**只对"有内置密钥"
  或"可选"的源成立**；`mandatory` 且无内置（Hardcover，以及无内置密钥时的 TheTVDB）一律用
  `credentialsKeyRequiredHint`。写反了会明确误导用户。
- **豆瓣不向用户要密钥**（D12）：Frodo 已停发新密钥，故密钥对**内置在构建里**
  （`lib/shared/constants/douban_defaults*.dart`，**条件导入** —— Web 版为空串，签名归自托管 `/proxy`；
  服务端 `server/lib/src/douban_defaults.dart` 同源兜底，`credentials[...] ?? 内置`），
  `keyRequirement` 回到 `none`，两个密钥界面都不再有该节。**别再给豆瓣加密钥界面。**
  其 `url` 仍指站根 `https://www.douban.com/`（该源覆盖图书 / 电影 / 剧集三类）。
- **免密钥源不出现在这两个界面**（`keyRequirement: none`）—— tvmaze / anilist / bangumi / mangabaka /
  mangadex / kitsu / vndb / neodb / weread / openLibrary / fantlab / musicBrainz / **douban**(内置公用
  密钥，见下) 共 **13 个**。它们只在
  **搜索页的源开关**（`source_chips_row.dart`）与向导的"无需密钥"徽章里露面。**别再问"XX 的密钥配置
  在哪"—— 先看 `keyRequirement`。**
- **品牌图标**：新接入的国内源目前都吃 Material 兜底图标（豆瓣 `Icons.local_library`）；`AppAssets` 里
  有 igdb / tmdb / tvdb / anilist / comicvine 等的彩色 png，但**无豆瓣 / NeoDB / Bangumi / WeRead**。

### 七之十一、数据源区域与连通性自检（2026-09-21，D15）

**结论先行**：21 个 API 宿主里**境内只有 2 个**（`frodo.douban.com` 腾讯云 · `weread.qq.com` 腾讯），
其余 19 个全在境外（Cloudflare 8 · AWS 3 · 其余 8）。更糟的是**8 个媒体类型的默认主源 100% 在境外** ——
境内唯一能用的豆瓣反而排在 NeoDB 之后。**「本土化」的正确判据是「默认路径全境内可达」，而不是
「所有源都在境内」**（中文元数据最强的 Bangumi / NeoDB 恰恰都托管在境外）。审计脚本：
`probe/host_reachability_audit.py`（DNS + ip-api ASN，21 宿主逐一定性）。

- **`SourceInfo.region` / `apiHost` 均为必填**（D15）。`region` 取 `domestic` / `overseas`；
  `isDomesticSource(DataSource)` 对**不在目录里的源返回 `false`** —— 安全半边，不许假设可达。
- **默认开启规则**（`BrowseNotifier._initiallyDisabledSourceIds`，原名 `_keylessSourceIds`）：缺密钥的
  `mandatory` 源关；**且当该类型存在境内源时，境外源一并关**。若整个类型一个境内源都没有
  （**只剩漫画与视觉小说**），**一个都不关** —— 区域只是提示、不是「它一定不通」的证据，而开一个
  空标签页什么也说明不了。D18 曾为音频的播客半边留过一个「该目录独占」豁免（`_isAloneInItsCatalogue`）；
  D19 喜马拉雅补上了境内播客源，**豁免与其方法一并删除**，规则对全类型整类生效。
- **主源顺序**（`search_sources.dart`）：图书 / 影视里**豆瓣排在 NeoDB 之前**（D15）。
- **连通性自检**（`lib/core/api/source_reachability.dart` + 设置页 → 数据源 → 网络连通性自检）：
  逐源对 `apiHost` 发一次 `GET /`，带 `Range: bytes=0-0` 与 `validateStatus: (_) => true`，
  `Future.wait` 并发（全程一次往返）。**判据是「有没有 HTTP 响应」，不是状态码** —— 401 / 403 / 404
  一律算**可达**，否则「没配密钥」会被误报成「网络故障」。Web 端直接跳过：浏览器侧的结论描述的
  其实是服务端，UI 里写明。**别把它做成 CI 测试** —— 它需要网络，且本机（TUN 代理）的结果
  不代表用户手机。
- **界面标注**：境外源在筛选面板的源开关上带 `Icons.public`（Tooltip = `sourceNeedsIntlNetwork`）、
  在向导卡片上多一枚「需国际网络」chip。
- **活体记录**：`probe/reachability_probe_live.txt`（20/20 可达，2.0s；豆瓣 222ms / 微信读书 741ms
  与其余 1043–2025ms 泾渭分明，正好印证区域分类）。

### 七之十二、MangaDex 中文标题（2026-09-21，D17 · 既有源改造，零新增）

**缺口不在数据，在解析。** MangaDex 的检索**本来就跨全部标题**（`?title=海贼王` 命中 `One Piece`、
`?title=进击的巨人` 命中 `Attack on Titan`），中文名也一直在响应里 —— 只是 `Manga.fromMangaDex`
的 `title` 取 `ja-ro ?? en ?? native`，而中文名**从不写在 `title`**，只藏在 `altTitles` 的
`zh` / `zh-hk` 键 ⇒ **搜中了也显示英文**。

- **中文键只有两个**：`zh` = **简体**、`zh-hk` = **繁体**（实测 500 行：`alt.zh` 248 · `alt.zh-hk` 205 ·
  `alt.zh-ro` 17 罗马化，**后者无价值，不收**）。`title` map 里**没有** zh 键，所以 `pickTitle`
  必须先查 `titleMap` 再扫 `altTitles`（现有实现已是如此）。
- **覆盖 61%**（`followedCount` 排序 500 行；**前 100 行 83%**）⇒ 近四成条目无中文，
  **必须保证无中文时行为完全不变**（`title` 仍 `ja-ro ?? en ?? native`）。
- **槽位约定**：中文进 **`title`**（主标题槽）⇒ 默认设置 `romaji` 下就显示中文；
  `titleEnglish` = `en`；**`titleNative` 只留 `ja ?? ko`** —— 原实现把 `zh` 当末位兜底，
  中文移入 `title` 后必须**移除**，否则同一名字占两槽。
- **`_localized` 同样中文优先**（zh 系 → en → 首个非空）：**描述**受影响（**仅 7%** 的记录有中文描述，
  21/300）；**77 个 tag 的名只有 `en`**，故筛选词表**零影响**。
- ⚠️ **MangaBaka 直连 403**（`series/search` 正确端点 + 带 UA 仍拒），传输层无特殊 header ⇒
  服务端拒直连，与标题无关，**单独待办**。

**不做（判断过）**：**不挪 `search_sources` 注册顺序**。注释虽写「order drives per-type primary」，
但 `primarySearchSourceFor` 全仓**只有 `wishlist_screen` 一处调用**（问该类型有无源），
搜索本就是**并发打所有开启源做并集** ⇒ 把 MangaDex 挪到漫画组首位**不改变任何行为**，
只炸 `search_sources_test` 的 id 顺序表。漫画 5 源全境外（D15 规则 ⇒ 一个都不关），MangaDex 本就默认开。

**诚实的边界**：MangaDex **仍是境外源**（DNS 归属印尼），`region` 照实标 `overseas`。
本轮做到的是「**不挂代理也拿得到中文漫画元数据**」，**不是**「漫画线有了境内源」——
后者至今无解（B 站漫画 code 99 · 快看 404 · 动漫之家不可达 · copymanga 302）。

### 七之十三、豆瓣音乐源与 `.audio` 的两本目录（2026-09-21，D18）

- **豆瓣的音乐是独立条目类型**（不像动画混在影视池里）：搜索 `/api/v2/search/music`、
  详情 `/api/v2/music/{id}`。**详情是唯一带 `songs` 的形状**，一次请求把专辑与曲目一起拿回来
  —— 豆瓣封禁突发，**绝不能拆成两次请求**。
- **`songs.track_number` 为 `null` 的行是分隔行**（实测："全套曲目" / "CD1" / "早期音乐" /
  "总时间：70分钟"），**不是曲目**，必须过滤（`doubanMusicSongs`）。真曲目编号**跨碟全局连续**
  （实测 1..138 无重复）⇒ `discNumber` 恒取 1，position 不会撞 `(source, audioId, disc, position)`。
- **`duration` 字段恒为 0**，别拿来当 `lengthMs`；只有**用户整理的合集**把时长写在标题尾部
  （`…《万福，光耀海星 》        2:15`），`doubanTrackTitleAndLength` 抽走它**并从标题删掉**。
  官方专辑（如周杰伦）标题干净、无任何时长 ⇒ 一律 `null`，不得编造。
- **搜索行的 `card_subtitle` 是「歌手 / 年份」**（影视池是「国家 / 题材 / 导演 / 演员」）⇒
  **音乐不能复用 `doubanItemGenres`**（它会把年份读成题材，实测得到 `['2016']`），
  必须用 `doubanMusicGenres`，只认 `genres` 数组。
- **`.audio` 是唯一一个装着两本目录的媒体类型**（`AudioKind.album` / `podcast`）。D15 的区域规则
  粒度是**媒体类型**，所以豆瓣音乐一进来，「有境内源 ⇒ 关境外源」会**把 PodcastIndex 一起关掉**
  —— 而它是播客唯一的源、且没有任何境内替代 ⇒ 会直接让播客空白。
  `BrowseNotifier._isAloneInItsCatalogue` 让它豁免。**以后往 `.audio` 加源前先想这一条**。
- 复用 `DataSource.douban` ⇒ 零枚举值 / 零图标分支 / 零密钥界面 / **零新 l10n 键**（音频线表
  = `searchSourceMusic`、提示 = `searchHintMusic`、面板标题 = `musicSheetTracks`）；
  缓存身份含 `media_type`，与图书 / 影视 / 动画不撞车。
- **连带必改 5 处**（全不报编译错）：`collection_actions` 刷新臂 · `import_service._fetchAlbumRefs`
  · `media_handlers` 的 `sheetBuilder` 与 `enrich`（两处）· `source_catalog` 的 `mediaTypes`
  · `search_sources` 注册（会炸 `search_sources_test` 的 id 顺序表）。
- **豆瓣一条 subject 就是一张专辑**，没有 MusicBrainz 那种版本选择 ⇒ 走 `DoubanMusicSheet`
  （仿 `PodcastIndexSheet`），不进 `MusicBrainzAlbumSheet`（它按 `nativeId` 当 MBID 查 release，会静默失败）。

### 七之十四、TapTap 游戏源（2026-09-21，D19，`taptap`）

**游戏线要的不是「中文」，是「免梯子」。** IGDB 的中文支持一向够用，但它和其余七个类型的默认主源一样
在境外（D15 审计）。TapTap 是境内唯一能给游戏元数据的中文目录，于是它同时解决两件事：路由不出境 +
标题本来就是中文。

- **端点**：搜索 `/webapiv2/app-search/v1/by-keyword`（旧文档里的 `/mix-search/v1/by-keyword` **已死**，
  404/405）；详情 `/webapiv2/app/v4/detail?id=<appId>`。**必带 `X-UA`**，否则一律 `400 INVALID_XUA`
  —— 它是契约不是装饰，故它写在 BaseOptions 的 headers 里（`kTapTapXUa`）。
- **分页参数叫 `from`，是偏移不是页码**（`from = (page - 1) * 10`）。**`total` 不可信**：第二页调用时它
  直接消失而数据照出 ⇒ 判尾靠「空页」+ `kTapTapMaxOffset` 封顶。
- **评分是字符串 `"7.9"`、0–10 标度** ⇒ `taptapRating` 乘 10 存进 0–100 的 `Game.rating`；未发布应用
  没有 `score`，读到非数字（如 `"—"`）必须返 null，**不许当 0**。总票数在 `vote_info` 的五个桶里，
  `taptapRatingCount` 求和（`vote_info` 全 0 视同没有评分）。
- **id 空间必须偏移**：TapTap app id 与 IGDB game id 同为整数，而 `collection_items` 的 game 唯一索引
  **不含 `source`** ⇒ 会撞车。`kTapTapIdOffset = 1e9`，`Game.id = appId + offset`、`Game.externalUrl`
  用裸 appId 拼。**刷新路径靠 `collection_items.source` 分流**：`game_handler` 必须按
  `game.isFromTapTap ? DataSource.taptap : DataSource.igdb` 写入 source，否则刷新会拿 TapTap id 去问 IGDB。
- ⚠️ **`getGameById(id)` 收的是「偏移后的模型 id」，不是裸 appId**。传裸 appId 会被 `appId <= 0` 的
  保护挡掉、**静默返回 null**（作者本轮就在这里被自己的活体测试骗过一次）。facade 的文档已写明。
- **无平台表**：一个境内商店只列 Android / iOS 一份 ⇒ `platformIds = null`，选择器不该等平台解析。
  搜索行与详情记录**键位相同**，一套 reader 服务两种形状。
- 连带必改：枚举 + 图标分支（`data_source_ui` 返 null）+ `source_catalog`（`domestic`）+
  `proxy_targets` + `proxy_handler` 的 keyless 组 + `welcome_step_sources._description` + 6 语言 ARB
  + 刷新臂 + `import_service` 的 `tapTapIds` 分流 + `extractApiError` + `host_rate_limiter`（`taptap.cn` 200ms）
  + `source_output_media_type_test` + `search_sources_test` 顺序表 + 两个区域测试。

### 七之十五、喜马拉雅播客源（2026-09-21，D19，`ximalaya`）

- **端点**：`/revision/search/seo`（**不是** `/revision/search/main` —— 后者对无会话客户端答
  `{"ret":200,"reason":"risk invalid","riskLevel":5}`）。必带 `Referer`（前端总有），参数
  `core=album` 把单集挡在结果外 —— 本源收的是节目不是单集。**专辑详情端点在黑名单后**，故本源
  **search-only**：刷新走「标题重搜 + 按 albumId 匹配」（与微信读书同范式），导出无标题即降级为 null。
- ⚠️⚠️ **最贵的一口咬痕：它用 `Content-Type: text/plain` 送 JSON。** Dio 的 JSON 嗅探因此拒绝解析，
  `resp.data` 是 **String**，而解析器第一道 `if (data is! Map<String, dynamic>) return const []` 会
  **静默返回空表** —— 表现为「搜索永远 0 条、无异常、无报错」。仓库里 Fantlab 早就踩过同类坑
  （它的 Content-Type 尾部多个 `;`）。D19 把解码统一提到 `api_dio.dart`：
  **传输层 `responseType: ResponseType.plain` + 解析前 `decodeJsonBody(resp.data)`**
  （`FantlabHttpClient.decodeBody` 已改为委托它）。**教训：新源一定要写一条「响应体是 String」的
  解析测试** —— 这口咬痕是活体验证抓到的，夹具测试若不喂 String 就抓不到。
- **`ret != 200` 必须抛异常并带上 `msg`**（`no such search word` / `risk invalid`）：否则又被上面的
  空表逻辑吞成「没有结果」。`_parseAlbums` 收到非 Map 才返回空表。
- **id 空间同样要偏移**：albumId 是 8 位整数，与豆瓣 subject id 会在 `collection_items.external_id`
  的 audio 唯一索引（**不含 `source`**）上撞车 ⇒ `kXimalayaIdOffset = 2e9`；`nativeId` 存裸 albumId 字符串。
- **封面是裸 `storages/...` 路径** ⇒ `ximalayaCoverUrlFor` 拼 `https://imagev2.xmcdn.com/`。
  **`createdAt` 是毫秒**（与 `released_time` 的秒不同），`tracksCount` / `playCount` 的 0 含义不同：
  前者 0 = 未填写（转 null），后者 0 = 真没人听过（保留 0）。
- **无评分字段** ⇒ `rating` 留 null，不编造。`kind = podcast`，与豆瓣音乐（`album`）共用 `.audio`。
- 与 TapTap 同一批的连带走一遍；**额外**：`media_handlers` 的 `sheetBuilder` 要走
  `XimalayaPodcastSheet`（记录展示，无单集预览 —— 单集列表在登录态 `webtk` 之后）。

### 七之十六、D19 的收口：区域规则整类生效 + 测试别再按下标取目录

- **音频半边也有境内源了** ⇒ `BrowseNotifier._isAloneInItsCatalogue` 及其调用点**删除**，
  「有境内源 ⇒ 关境外源」不再有任何豁免；**游戏同理**：TapTap 一进来，IGDB 默认由开转关
  （`source_region_default_test` 的 game 用例从「一个都不关」翻成 `active={taptap_games}`）。
- **`reachability_screen_test` 踩了位置下标**（见护栏速查最后一条）。已改为
  `sourceInfoFor(DataSource.x)`，**这类改动以后是新源 SOP 的一部分**。
- **两个新源都补齐了 `test/core/api/<source>_api_test.dart`**（仓库惯例：每个源一份）。它们同时覆盖
  字段 reader 的边界（空串 / 0 / 非数字）、HTTP 错误映射、坏行丢弃、以及喜马拉雅那条 String 体回归。

### 七之十七、源要的自定义头，Web 端必须由服务端补（2026-09-21，D20）

**Web 形态下所有外部请求都经服务端 `/proxy/<slug>/…`**，而 `proxy_handler` 的
`_forwardedRequestHeaders` **只放行 `content-type` 与 `accept`** —— 其余一律丢弃（这是防"构造请求
借用服务端凭据"的设计，不是疏漏）。于是源的 http_client 里 `headers:` 写了什么，**客户端设了也白设**。
漏一个，就是 Web 端一个**静默空白**：桌面搜索正常，浏览器里那一页什么都没有。

两类情形要分清，处置完全不同：

| 情形 | 例子 | 浏览器能设？ | 服务端收得到？ | 处置 |
|------|------|:---:|:---:|------|
| **自定义头** | TapTap 的 `X-UA` | 能（同源自定义头合法） | **收得到但会被丢** | 必须在 `_authorize` 里补 |
| **禁止头** | `Referer` / `User-Agent` / `Origin` / `Host` | **不能**（Fetch 规范的 forbidden header names，静默忽略） | 收不到 | 只能服务端补 |

- **D19 就漏了第一类**：TapTap 源在客户端侧带 `X-UA` 是对的，但服务端没补 ⇒ 浏览器发出的请求到了
  上游就成 `400 INVALID_XUA`，游戏页空白。修法是在 `ApiProxy._authorize` 里把 `ProxyTarget.taptap`
  移出 keyless 组、由服务端写 `kTapTapXUa`（与 Douban 自持 UA、Bangumi 由服务端补 UA 同一范式）。
- **但「需要禁止头」不等于「一定要补」**：喜马拉雅客户端侧带 `Referer`，服务端并未补，活体实测
  `/revision/search/seo` 仍答 `ret: 200`（服务端发的 UA 就够）。**这类要靠实测裁决，不能靠类推** ——
  假设在这里被推翻过一次。
- **验证方式**（唯一可靠的一种）：起**真服务端**（`dart run server/bin/server.dart --web-root build/web
  --port <p>`），用「客户端会发的头」curl 打 `/proxy/<slug>/…`，看**上游原样的响应**。
  **桌面能搜 ≠ Web 能搜**，这条路没有离线替代品。
- **自查动作**：新源落地后，把 http_client 的 `headers:` 与 `_forwardedRequestHeaders` / `_authorize`
  逐条对照；若源依赖某个头，就补一条**服务端**测试（"这个头被送出"+"调用方自带的同名头被覆盖"）。
  另见 `tonkatsu-selfhost-proxy-verify` 技能的三层验证法。

### 七之十八、名称匹配的阈值是实测出来的，不是拍的（2026-09-21，D21）

`lib/core/import/sources/name_list/` 的「游戏名列表导入」把一份纯文本游戏名列表匹配成条目。匹配是启发
式的，**阈值一松就静默写错游戏**，所以三条判据锁在 `GameTitleMatcher` 里，每条都有活体数据背书
（`probe/ps5_name_match_probe.py` 可复跑）：

| 情形 | 例子（均为 TapTap 真实返回） | 分数 | 预选？ |
|------|------|:---:|:---:|
| 完全相同 / 去符号后相同 | `地平线 西之绝境` ↔ `地平线：西之绝境` | 95 | ✅ |
| **查询词是候选标题的前缀** | `最后生还者` → `最后生还者 第二部` | 85 | ✅ |
| 查询词埋在更长标题里 | `血源诅咒` → `樱花女校：血源诅咒` | 55（封顶） | ❌ |
| 只共享一个词 | `战神` → `烈火战神` | 46 | ❌ |
| 仅 bigram 重合（Dice） | `God of War Ragnarok` → `Sticky Man : The God of War` | ≤61（封顶） | ❌ |

- **`confidentScore = 62` 是预选线**，`nestedCeilingScore`(55) 与 `diceFloor + diceSpan`(61) **必须低于它**，
  这是**故意**的：它们只配当"候选"让用户挑，绝不替用户做决定。有一条测试专门钉住这个不等式。
- **前缀对齐才算续作**：`第二部` / `导演剪辑版` / `重制版` 都是**后缀**扩展（同系列）；手游仿冒则是
  **前缀**借用（`樱花女校：血源诅咒`）。同一段 `contains`，只差一个 `startsWith`。
- **两个目录的分工不是猜的**：中文名 → TapTap（20 个真实 PS5 中文名里 13+ 真命中）；英文名 → IGDB。
  TapTap 的英文名结果是**垃圾场**——`Elden Ring` 返回 `Elden Shell: Mortal Ring (RPG)`、`Ghost of
  Tsushima` 返回 `Ghost of Kyiv`——所以它只当**兜底**，靠上面的封顶拦住这些行。
- **别为"提高匹配率"松开这几条**：松开的直接后果是把 `烈火战神` 写进用户的收藏。宁可少匹配（落进愿望
  单，用户看得见），不可错匹配（静默污染）。要动，先跑 `probe/ps5_name_match_probe.py` 拿新数据。

### 七之十九、PSN 登录导入：授权流、已购库与凭据纪律（2026-09-21，D23）

**索尼不提供第三方 OAuth 注册，也没有 PIN flow。** 本项目里 Simkl 走的 PIN 是 OAuth 变体中最省事的那种，
PSN 只剩社区逆向出来的这一套：**NPSSO cookie → code → token**。以下全部是实测值，**照抄，别再猜**：

| 步骤 | 请求 | 关键点 |
|---|---|---|
| 换 code | `GET https://ca.account.sony.com/api/authz/v3/oauth/authorize`，参数 `access_type=offline`、`client_id=…`、`redirect_uri=com.scee.psxandroid.scecompcall://redirect`、`response_type=code`、`scope=psn:mobile.v2.core psn:clientapp` | 带 `Cookie: npsso=<x>`；**必须 `followRedirects: false`**，从 302 的 `Location` 里抠 `code` |
| 换 token | `POST https://ca.account.sony.com/api/authz/v3/oauth/token` | `Authorization: Basic <base64(clientId:clientSecret)>`；form-urlencoded：`code`/`redirect_uri`/`grant_type=authorization_code`/`token_format=jwt` |
| 续期 | 同端点 | `grant_type=refresh_token` + `refresh_token`，**scope 必须与授权时同一组** |

- **`client_id` / `client_secret` 是索尼 PS App 的公开常量**（`09515159-7237-4370-9b40-3806e67c0891` /
  `ucPjka5tnrB2KqsP`），每个开源 PSN 客户端都携带同一份。**不做成用户可配**：一个字节错就是 `invalid_grant`，
  且用户手上不会有更好的值。落在 `packages/core/lib/api/psn_constants.dart`，**两端共用**（照 `douban_constants` 先例）。
- **「302 但没有 code」= NPSSO 失效**（索尼把人弹去登录页），不是畸形响应。判据写在 `PsnAuthClient._codeFrom`，
  文案必须引导"重新登录拿新的"，而不是报网络错误。

**「已购库」确实存在，但不在 trophy 域**：`trophy/v1/.../trophyTitles` 只有**玩过的**，
`gamelist/v2/.../titles` 是**单设备**的，真正的购买记录在
**`web.np.playstation.com/api/graphql/v1/op`** 的 **persisted query** `getPurchasedGameList`
（sha256 `827a423f6a8ddca4107ac01395af2ec0eafd8396fc7fa204aaf9b7ed2eefa168`），
请求只发 `operationName` + hash + variables。
- 响应**没有 total**，分页靠**「短页即止」**（`games.length < size`），并用 `kPsnPurchasedMaxPages` 兜底。
- 同一游戏 PS4/PS5 是两条记录 ⇒ **按显示名去重**。收藏的是「游戏」，不是「权益」。
- 未授权实测：该端点返 **400**（GraphQL 惯例），不是 404 —— 别拿 400 当"端点不存在"。

**NPSSO 等同账号密码，纪律三条**：① **绝不落盘**（读进内存、用完即弃，`dispose` 里 `clear()`）；
② 只有**刷新令牌**可持久化，且必须 **opt-in**（`SettingsKeys.psnRememberToken` 为真才写 `psnRefreshToken`）；
③ 不允许出现在日志或 URL 里（见下条）。

**三端一条流，靠服务端搬凭据** —— 这是 **七之十七** 的第二次验证：
浏览器**不允许**设置 `Cookie` 请求头，而 `/proxy` 只转发 `content-type` / `accept`（`_forwardedRequestHeaders`），
所以 Web 端把凭据放 **query**（`npsso` / `access_token`），服务端 `_authorize` 的
`ProxyTarget.psnauth` / `psnweb` 分支**把它搬进 header 并从 query 里删掉** ——
不删，密码级的 NPSSO 就跟着 URL 进了索尼的访问日志。桌面/手机直连，走真实 header，
同一个客户端代码里只多一个 `kIsWebBuild` 分支。

**别给它写 `ImportSource`**：`ImportSource` 的语义是「名字 → **目录条目**」，而 PSN 只给**裸名字**
（与粘贴名单同构）。所以 PSN 止步于 `List<String>`，交给 `GameNameListImportContent(initialNames:)` ——
**匹配、阈值、预览、入库全部复用同一套实现**（即 七之十八 那套）。
`lib/core/import/sources/psn/` 因此**不存在**，不是漏了；设计理由写在 `lib/core/api/psn/README.md`。

**这条链路唯一会静默死掉的地方：无 body 的 GET 必须自己声明 `content-type`。**
索尼的 Apollo 网关开着 CSRF 防护：请求若**压根没有** `content-type`，或它是
`application/x-www-form-urlencoded` / `multipart/form-data` / `text/plain`，就直接回
**400 "blocked as a potential Cross-Site Request Forgery"**——除非带 `x-apollo-operation-name`
或 `apollo-require-preflight`。而 `getPurchasedGameList` 是 **GET + query string**，
Dio 对无 body 的请求**一个 content-type 都不发** ⇒ 整条导入在这一步死掉（真机首发即中）。

- 修法：`Options(contentType: 'application/json')`。这是**两选一里唯一三端都通的那个** ——
  另一个 `x-apollo-operation-name` 会被 `/proxy` 丢掉（它只转发 `content-type` / `accept`，见七之十七）。
- **真机复现判据（无需账号）**：CSRF 检查发生在**鉴权之前**，所以用假 token 直打该端点就能看到 400 CSRF；
  补上该头后同一请求变 **200 + `invalid_psn_access_token`**（已进业务层，且顺带证明 hash / operationName 有效）。
  **"本机没账号所以验不了" 是错的** —— 见 九之④ 的活体验证要求。
- 教训：**「没有 body」≠「不需要声明类型」**。网关反问 CSRF 时先看自己发了什么头，别去翻 token。
- 回归护栏：`psn_library_client_test.dart` 有一条**只断言 `options.contentType`** 的用例 ——
  删掉这个头能让功能在真机上整体失效，而**其余所有单测照样全绿**（MockDio 不关心头）。

**可达性判据（30 秒，必须在用户设备上跑）**：浏览器打开
`https://m.np.playstation.com/api/trophy/v1/users/me/trophyTitles` —— 出 JSON **401** ⇒ 可达；
转圈超时 ⇒ 该网络到不了 PSN。**本机测出来的不算数**（本机跑着 TUN 代理，见 七之十一）。

## 八、提交约定（对齐上游 `docs/COMMITS.md`）

Conventional Commits：`type(scope): desc`。本分支自带前缀惯例：**国内源相关用 `feat(cn-*)` scope**（如 `feat(cn-bangumi): add Bangumi anime source`、`feat(cn-neodb): add NeoDB book source`），以便 grep 区分上游/分支。

## 九、定义完成（必须全绿再收工）

1. `flutter analyze --fatal-infos --fatal-warnings` **零输出**
2. `flutter test` · `dart test`（packages/core）· `dart test`（server）**全绿**
3. RPC 生成物 `git diff --exit-code -- packages/core/lib/rpc/generated` 为空
4. **在线活体验证**通过（临时插真实 API；不允许"测试都过了"当完工）
5. **新源在自托管 Web 形态下过一遍**：起真服务端，用「客户端会发的头」打 `/proxy/<slug>/…`，
   看**上游原样的响应** —— 前端能编译不等于浏览器能搜（详见七之十七）
6. 护栏、ARB 键数（6×**1811** 全齐）、`TASK.md` 状态同步

按此清单跑完，再回头补文档与记忆。