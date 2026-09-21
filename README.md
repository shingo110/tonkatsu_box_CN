<p align="center">
  <img src="assets/images/logo.png" width="120" alt="Tonkatsu Box">
</p>

<h1 align="center">Tonkatsu Box CN</h1>

<p align="center">
  <b>为中文用户改造的媒体收藏管理器</b><br>
  游戏 · 电影 · 剧集 · 动画 · 视觉小说 · 漫画 · 图书 · 音乐 · 播客
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License: MIT"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.38+-02569B?logo=flutter&logoColor=white" alt="Flutter 3.38+"></a>
  <img src="https://img.shields.io/badge/Windows-0078D4?style=flat-square&logo=windows&logoColor=white" alt="Windows">
  <img src="https://img.shields.io/badge/Android-3DDC84?style=flat-square&logo=android&logoColor=white" alt="Android">
  <img src="https://img.shields.io/badge/Web-4285F4?style=flat-square&logo=googlechrome&logoColor=white" alt="Web">
</p>

---

> [!IMPORTANT]
> **本仓库是 [`hacan359/tonkatsu_box`](https://github.com/hacan359/tonkatsu_box) 的国内化分支**（上游 0.44.0，MIT 许可）。
>
> 上游的数据源以海外服务为主（TMDB、IGDB、AniList、Google Books…），在国内网络下要么不可达，要么只提供英文元数据。本分支的目标是**接入国内可直连、带中文元数据的数据源**，让搜索与入库真正可用。
>
> 本分支**尚未发布任何构建产物** —— 发布流水线（`.github/workflows/release-cn.yml`，推 `cn-v*` 标签触发）已就位，但首个 Release 尚未推送。需要可用版本请先从源码构建，或使用上游的[官方 Release](https://github.com/hacan359/tonkatsu_box/releases/latest)（不含本分支的国内源）。

---

## 国内数据源接入进度

这是本分支与上游的**核心差异**，也是唯一的改造主线。

| 媒体类型 | 数据源 | 状态 | 备注 |
|---------|--------|:----:|------|
| 动画 | [Bangumi](https://bgm.tv/) | ✅ **已接入** | 免密钥直连；中文标题与标签；分类 / 年份 / 评分 / 排名四类筛选；详情含制作公司与简介 |
| 动画 | [豆瓣](https://movie.douban.com/) | ✅ **已接入** | 复用豆瓣影视接口，动画条目自带中文名与评分，无需另找源 |
| 电影 / 剧集 / 图书 | [NeoDB](https://neodb.social/) | ✅ **已接入** | 免密钥；中文标题与简介，每条挂豆瓣外链；**剧集以「季」为粒度**，仅搜索、不支持空关键词浏览 |
| 电影 / 剧集 | [豆瓣](https://movie.douban.com/) | ✅ **已接入** | 元数据最全；走 HMAC-SHA1 签名的 Frodo 接口，**需自备 API Key / Secret**；**同一搜索端点混出电影与剧集，按行的 `target_type` 分流**；受 403 断路器保护（连打 9 次即冷却 5 分钟） |
| 电影 / 剧集 | [优酷](https://www.youku.com/) / [爱奇艺](https://www.iqiyi.com/) | 📋 计划中 | 搜索接口免密钥可用，字段偏少，适合做列表与海报 |
| 图书 | [微信读书](https://weread.qq.com/) | ✅ **已接入** | 免密钥；中文电子书与网文覆盖面最广；推荐值 0–1000 换算到 0–10；**仅搜索**（官方无 by-id 详情接口） |
| 图书 | [豆瓣](https://book.douban.com/) | ✅ **已接入** | 元数据最全；走 HMAC-SHA1 签名的 Frodo 接口，**需自备 API Key / Secret**；输入 ISBN 时自动改走 by-ISBN 端点；受 403 断路器保护（连打 9 次即冷却 5 分钟） |
| 漫画 | [Bangumi](https://bgm.tv/) | ✅ **已接入** | 免密钥直连；走 Bangumi 的书籍类型（`type=1`）并叠加「漫画」meta 标签，中文标题；分类 / 年份 / 评分 / 排名四类筛选 |
| 漫画 | [MangaDex](https://mangadex.org/) | ✅ **已接入** | 境外托管，但 `altTitles` 里本就有 `zh` / `zh-hk` 中文名（覆盖率 61%，头部作品 83%），让标题默认显示中文即可 |
| 游戏 | [TapTap](https://www.taptap.cn/) | ✅ **已接入** | 免密钥直连；社区评分 0–10 换算到 0–100；**必须带 `X-UA`**，Web 端由自托管服务端补齐 |
| 音乐 | [豆瓣](https://music.douban.com/) | ✅ **已接入** | 免密钥；中文专辑名与曲目表，评分已是 0–10 |
| 播客 | [喜马拉雅](https://www.ximalaya.com/) | ✅ **已接入** | 免密钥直连；中文节目名与主播、集数；**专辑详情接口在黑名单后，仅搜索**，刷新按标题重搜 |
| 视觉小说 | — | 🔍 无境内源 | 上游的 VNDB 保留未删，但路由需出境 |

> 状态图例：✅ 已并入主线并通过全部关卡 · 📋 已选型待实现 · 🔍 尚未确定可行路径。
> 接入一个源需要改动的准确清单与验收口径见 [`RULES.md`](RULES.md) 与 [`TASK.md`](TASK.md)。

---

## 功能总览

上游的功能本分支全部保留（仅数据源侧做增量），以下为概要。

| | 功能 | 说明 |
|:-:|------|------|
| 📦 | **收藏管理** | 按平台、类型或任意维度组织；网格 / 列表 / 表格 / 看板四种视图，支持手动拖拽排序与批量操作 |
| 🔍 | **统一搜索** | 一个搜索框背后是全部目录服务，各有专属筛选器与空关键词浏览模式；一条结果可同时加入多个收藏 |
| ✅ | **进度追踪** | 状态、1–10 评分、起止日期、重看次数、耗时；图书按页、漫画按章、专辑按曲目 |
| 📺 | **剧集追踪** | 季折叠面板，含剧照、播出日期与简介；一键标记单集 / 整季 / 下一集未看 |
| ❤️ | **喜欢与笔记** | 对单集、季、章、卷、页做标记与批注，并可筛选出已标记项 |
| 🏷️ | **标签系统** | 全局标签管理器，支持分组、筛选与批量增删 |
| 📊 | **统计** | 全部时间或单一年度的数据总览：计数器、分类型统计、月度带状图、平台与格式分布、优劣势对比、可分享的总结卡片 |
| ☁️ | **个性化** | 由收藏生成的类型 / 平台 / 年代词云，以及基于已完结与评分的推荐 |
| 🔔 | **播出日历** | 关注的作品自动进入月 / 周 / 日视图，也可自行添加日期 |
| 📝 | **愿望单** | 顶层独立清单；导入器未能匹配的条目会安放于此 |
| 🎨 | **画板** | 拖拽式画布，可放海报、便签与连线 |
| 🏆 | **等级表与情绪网格** | S/A/B/C 分级或 N×M 可视排布，均可导出 PNG |
| 📥 | **数据导入** | Simkl、Steam、IGDB CSV、Trakt.tv、Kinorium、RetroAchievements、MyAnimeList、AniList、Hardcover、**PlayStation 登录**（读取已购游戏库）、**游戏名列表**（粘贴匹配入库），以及自有的 JSON / CSV |
| 🎬 | **Kodi 同步** | 通过 JSON-RPC 拉取电影观看状态与评分 |
| 🎧 | **Discord 状态** | 在 Discord 中显示当前正在玩的 / 看的 / 读的（桌面端） |
| 👤 | **多用户档案** | 一次安装可供多人使用，各自独立收藏、画板与封面 |
| 💾 | **导出与备份** | `.xcoll` / `.xcollx` 文件、设备间同步、一键备份，支持完全离线 |
| 🎮 | **手柄操作** | Xbox 手柄导航（桌面端与安卓掌机） |

## 支持的数据源

本分支共 **34 个搜索源、覆盖 22 个目录服务**（上游基线 21 源 / 16 服务 + 本分支新增的 Bangumi 动画与漫画两个源、NeoDB 的图书 / 电影 / 剧集三个源，微信读书，豆瓣的图书 / 电影 / 剧集 / 动画 / 音乐五个源，TapTap 游戏源，以及喜马拉雅播客源）。**"国内直连"一列仅标注本分支实测过的结论**，未评估的留空 —— 上游源的海外可达性随网络环境而异，本仓库不做保证。

| 类型 | 目录服务 | 密钥 | 国内直连 |
|------|---------|------|:--------:|
| 游戏 | [IGDB](https://www.igdb.com/) | 内置 | |
| **游戏** | **[TapTap](https://www.taptap.cn/)** | **免密钥** | **✅ 已实测** |
| 电影 / 剧集 | [TMDB](https://www.themoviedb.org/) | 内置 | |
| 剧集 | [TVmaze](https://www.tvmaze.com/) | 免密钥 | |
| 剧集 / 电影 | [TheTVDB](https://thetvdb.com/) | 需密钥 | |
| 视觉小说 | [VNDB](https://vndb.org/) | 免密钥 | |
| 动画 / 漫画 | [AniList](https://anilist.co/) | 免密钥 | |
| **动画 / 漫画** | **[Bangumi](https://bgm.tv/)** | **免密钥** | **✅ 已实测** |
| 漫画 | [MangaBaka](https://mangabaka.org/) | 免密钥 | |
| 漫画 | [MangaDex](https://mangadex.org/) | 免密钥 | |
| 动画 / 漫画 | [Kitsu](https://kitsu.io/) | 免密钥 | |
| 图书 / 电影 / 剧集 | [NeoDB](https://neodb.social/) | 免密钥 | **✅ 已实测** |
| **图书** | **[微信读书](https://weread.qq.com/)** | **免密钥** | **✅ 已实测** |
| **图书** | **[豆瓣](https://book.douban.com/)** | **需密钥** | **✅ 已实测** |
| **电影 / 剧集** | **[豆瓣](https://movie.douban.com/)** | **需密钥** | **✅ 已实测** |
| 图书 | [OpenLibrary](https://openlibrary.org/) | 免密钥 | |
| 图书 | [Fantlab](https://fantlab.ru/) | 免密钥 | |
| 图书 | [Google Books](https://books.google.com/) | 可选免费密钥 | |
| 图书 | [Hardcover](https://hardcover.app/) | 需免费令牌 | |
| 漫画 | [ComicVine](https://comicvine.gamespot.com/) | 需免费密钥 | |
| 音乐 | [MusicBrainz](https://musicbrainz.org/) | 免密钥 | |
| 播客 | [Podcast Index](https://podcastindex.org/) | 内置 | |
| **播客** | **[喜马拉雅](https://www.ximalaya.com/)** | **免密钥** | **✅ 已实测** |

另有三个非搜索用途的服务：封面用的 [SteamGridDB](https://www.steamgriddb.com/)（内置密钥）、复古媒体图库 [ScreenScraper](https://www.screenscraper.fr/)（需账号）、成就同步 [RetroAchievements](https://retroachievements.org/)（需账号）。

## 支持的语言

界面支持运行时切换，在 **设置 → 应用语言** 中选择，无需重启。

| 语言 | 状态 |
|------|:----:|
| 简体中文 | ✅ 完整 |
| English | ✅ 完整 |
| Русский | ✅ 完整 |
| Español | ✅ 完整 |
| Português (BR) | ✅ 完整 |
| Français | ✅ 完整 |

## 界面预览

| 主页 | 收藏 |
|---|---|
| <img src="docs/screenshots/mockup_main.jpg" alt="主页"> | <img src="docs/screenshots/mockup_collection.jpg" alt="收藏"> |

| 搜索 | 条目预览 |
|---|---|
| <img src="docs/screenshots/mockup_search.jpg" alt="搜索"> | <img src="docs/screenshots/mockup_title.jpg" alt="条目预览"> |

| 条目详情 | 筛选器 |
|---|---|
| <img src="docs/screenshots/mockup_card.jpg" alt="条目详情"> | <img src="docs/screenshots/mockup_filters.jpg" alt="筛选器"> |

| 剧集追踪 | 等级表 |
|---|---|
| <img src="docs/screenshots/mockup_episode_tracker.jpg" alt="剧集追踪"> | <img src="docs/screenshots/mockup_tierlist.jpg" alt="等级表"> |

## 平台支持

| 功能 | Windows | Linux | macOS | Android | Web |
|------|:-------:|:-----:|:-----:|:-------:|:---:|
| 收藏与搜索 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 进度与剧集追踪 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 统计与个性化 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 画板 / 等级表 / 情绪网格 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 数据导入 | ✅ | ✅ | ✅ | ✅ | ✅ |
| 备份与设备间同步 | ✅ | ✅ | ✅ | ✅ | — |
| Kodi 同步 | ✅ | ✅ | ✅ | ✅ | — |
| 手柄操作 | ✅ | ✅ | ✅ | ✅ | — |
| Discord 状态 | ✅ | ✅ | ✅ | — | — |
| VGMaps 浏览器 | ✅ | — | — | — | — |

> macOS 构建未经维护者测试，且未签名，首次启动会有安全提示。Web 端为自托管形态，浏览器内不保留数据库，深度功能（画板以外）与桌面端有差异。

## 从源码构建

需要 **Flutter 3.38+ / Dart 3.10+**。

```bash
git clone https://github.com/shingo110/tonkatsu_box_CN.git
cd tonkatsu_box_CN

flutter pub get
# 两个子包各自解析依赖，根目录的 pub get 不会代劳
dart pub get --directory packages/core
dart pub get --directory server

flutter run -d windows   # 或 linux / android / chrome
```

> [!NOTE]
> Windows 环境下有四个已探明的坑会伪装成"项目坏了"，实为环境问题 —— 代理变量打死测试、子包依赖未装导致上万条假报错、桌面构建缺 Visual Studio C++ 工作负载、两份 `flutter test` 不可并发。逐条说明与规避命令见 [`RULES.md`](RULES.md)。

### Android 发布版

调试构建开箱可用。打**发布** APK 需要自己的签名密钥（`android/key.properties`），过程见 [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md)。

### 三端发布包

| 平台 | 命令 | 备注 |
|------|------|------|
| Android | `flutter build apk --release` | 产物 `build/app/outputs/flutter-apk/app-release.apk`；**必须自备签名密钥** —— 仓库只带一份一次性验证密钥，且不入库 |
| Web | `flutter build web --release` | 产物 `build/web/`；交付时要**连服务端一起给** —— 浏览器里所有外部请求都经 `/proxy`，光有前端只能渲染、不能搜索 |
| Windows | `flutter build windows --release` | **本机不可用**：缺 Visual Studio C++ 工作负载。装上它即可本地构建，CI 侧由 `windows-2022` 运行器代劳 |

三者由 [`.github/workflows/release-cn.yml`](.github/workflows/release-cn.yml) 打包并发成 GitHub Release，推一个 `cn-v*` 标签即触发；Android 作业需要仓库配置 `KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_ALIAS` 三个 secret。

> [!NOTE]
> **为什么标签前缀是 `cn-`**：上游自带的 `release.yml` 在 `v*` 上触发，会构建五个本分支并不发布的桌面目标，并创建一个不属于本分支的 Release。`cn-v0.44.0` 不匹配 `v*`，两套流水线因此永不一起点火 —— 这也是这份流水线单独立一个文件、而不往 `release.yml` 里塞作业的原因。

## 自托管 Web 版

一个 Docker 容器即可把应用跑在浏览器里，数据库留在服务器上，局域网内所有设备共享同一份收藏。

```bash
git clone https://github.com/shingo110/tonkatsu_box_CN.git
cd tonkatsu_box_CN
docker compose up -d --build
# 首次构建需数分钟（容器内编译 Web 端），随后访问 http://<服务器IP>:8080
```

配置项（`TONKATSU_DATA_PATH` / `TONKATSU_PORT` / `PUID` / `PGID` / API 密钥）见 [`.env.example`](.env.example)。服务端细节见 [`server/README.md`](server/README.md)，接口契约见 [`server/PROTOCOL.md`](server/PROTOCOL.md)。

> [!WARNING]
> Web 版没有账号与密码体系，**只应暴露在可信局域网内**。
>
> 由于浏览器无法直连外部 API（跨域、User-Agent 被剥离、密钥不能下发到标签页），Web 端的所有外部请求都会经由服务端的 `/proxy/<slug>/…` 转发。可转发的目标在 [`packages/core/lib/api/proxy_targets.dart`](packages/core/lib/api/proxy_targets.dart) 中白名单化 —— 它是一张允许清单，不是开放中继。
>
> 这条链路已被证明可用：真实自托管实测 7/7，Bangumi / NeoDB 的代理响应与直连**逐字节相同**；豆瓣
> 无密钥返 503、非白名单目标返 404 均在服务端拦下。复现步骤见 [`TASK.md`](TASK.md) 的 D10。


## 数据安全

收藏数据全部在本地，不需要账号或云服务。升级前请先备份（**设置 → 备份**），因为版本更新可能包含改变数据结构的数据库迁移。

| 平台 | 数据目录 |
|------|---------|
| Windows | `%APPDATA%\Roaming\Tonkatsu Box\Tonkatsu Box` |
| Linux | `~/.local/share/tonkatsu_box` |
| macOS | `~/Library/Application Support/com.hacan359.tonkatsuBox` |
| Android | 使用内置备份功能（设置 → 备份） |

## 测试与质量关卡

提交前必须全绿：

```bash
flutter analyze --fatal-infos --fatal-warnings
flutter test
# 子包要进入自己的目录跑：`dart test --directory <pkg>` 在根目录解析不到 test 包
(cd packages/core && dart test)
(cd server && dart test)
```

若改动了 DAO 或其返回的模型，还须重新生成 RPC 桩并提交生成物：

```bash
cd packages/core && dart run tool/generate_rpc.dart
```

改到 `/proxy`、`proxy_targets.dart` 或 Web 端改写逻辑时，另有两条**离线**护栏（已并入上面两关，
这里点明）：`server/test/proxy_serve_integration_test.dart`（真 socket 全链路）与
`test/core/api/proxy_round_trip_test.dart`（客户端改写 ↔ 服务端还原）。需要真上游复核时，起一次真实
自托管按 `/proxy/<slug>/…` 打真接口即可（步骤见 [`TASK.md`](TASK.md) D10）。**这类活体检查不要塞进
CI**：要外网、会碰上游限流。

## 项目文档

| 文档 | 内容 |
|------|------|
| [`PROJECT.md`](PROJECT.md) | 项目全景：定位、目标、架构地图、里程碑、关键决策 |
| [`TASK.md`](TASK.md) | 任务清单：已完成、进行中、待办与各自的验收口径 |
| [`RULES.md`](RULES.md) | 规约总纲与已知坑点登记册 —— **动手前先读这份** |
| [`CHANGELOG.md`](CHANGELOG.md) | 版本历史（本分支条目以 `[cn]` 标记） |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | 架构分层与模块职责 |
| [`docs/CODESTYLE.md`](docs/CODESTYLE.md) | 编码规范细目 |
| [`docs/COMMITS.md`](docs/COMMITS.md) | 提交信息与分支命名约定 |
| [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) | 开发环境与贡献流程 |
| [`docs/GAMEPAD.md`](docs/GAMEPAD.md) | 手柄导航实现细节 |
| [`docs/RCOLL_FORMAT.md`](docs/RCOLL_FORMAT.md) | `.xcoll` / `.xcollx` 导出格式规范 |
| [`server/README.md`](server/README.md) | 自托管服务端 |
| [`server/PROTOCOL.md`](server/PROTOCOL.md) | `/rpc` 与 `/proxy` 线上契约 |

## 上游致谢

本分支的全部功能来自 [`hacan359/tonkatsu_box`](https://github.com/hacan359/tonkatsu_box)，在此致谢原作者与上游贡献者。上游仓库同时提供[使用文档 Wiki](https://github.com/hacan359/tonkatsu_box/wiki)（英文）与[现成收藏库](https://github.com/hacan359/tonkatsu-collections)（25 000+ 游戏，23 个平台）。

目录服务：IGDB · **TapTap** · TMDB · TVmaze · TheTVDB · VNDB · AniList · **Bangumi** · MangaBaka · MangaDex · Kitsu · **NeoDB** · **微信读书** · **豆瓣** · OpenLibrary · Fantlab · Google Books · Hardcover · ComicVine · MusicBrainz · Podcast Index · **喜马拉雅**

导入与扩展：Simkl · Trakt.tv · Steam · Kinorium · MyAnimeList · RetroAchievements · SteamGridDB · ScreenScraper · Kodi

*This product uses the TMDB API but is not endorsed or certified by TMDB.*

## 许可

[MIT](LICENSE) —— 与上游一致。衍生分发时请保留上游版权声明。
