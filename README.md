# DIGIMON · DIGITAL WORLD

原生 iOS 17 像素电子宠物工程。SwiftUI 界面、SpriteKit 最近邻像素渲染，以及可以脱离 Apple 框架编译测试的 Swift 游戏核心。无需联网、账号或在线 AI 服务。

**当前为 v0.1 开发版本，不是需求中全部十个阶段的最终成品。** 可游玩内容采用明确标注的原创融合规则；不宣称复刻了未经核实的实体机规则。官方角色资料、原创游戏数值、原创测试素材分别标注。

## 在 Xcode 运行

1. 使用 GitHub 的 **Code → Open with Xcode** 或克隆本仓库。
2. 用 Xcode 16 或更新版本打开 `DigitalWorld.xcodeproj`，选择 **DigitalWorld** scheme。
3. 选择 iPhone 或 iPad 模拟器，按 **Run**。Swift Package 是仓库内的本地依赖，不需要下载第三方库。
4. 在欢迎页选择「孵化这枚数码蛋」。5 分钟真实时间后出生；关闭应用再打开也会结算。

真机运行：在应用 target 的 **Signing & Capabilities** 中选择自己的开发团队，改为自己的唯一 Bundle ID，然后选择已连接的 iPhone。仓库不包含签名证书、描述文件或已签名 IPA。

## 目前能玩什么

- 孵化 → 喂食 → 互动时机训练 → 分支进化 → 离线 PVE → 原创地图探索 → 死亡与重生。
- 饱食、力量、幸福、能量、体重、年龄、健康、体力、DP、训练表现、战绩、失误、疾病、伤势、亲密度和忠诚度记录。
- 自然睡眠、关灯、手动休息、冷冻成长，以及生病、清洁与治疗。
- 8 个角色、7 种食物、2 枚蛋（其中 1 枚有解锁要求）、原创「信号花园」地图及数据碎片任务。
- 图鉴搜索和属性/阶段筛选，可平移缩放的进化分支图，角色资料与规则条件说明。
- 三种显示模式、A/B/C 虚拟按键、触屏快捷操作、基础电子按键音与触觉反馈。
- 原子本地自动存档、上一版有效备份、损坏检查与备份恢复、v1→v2 升级、系统分享导出与验证后的备份导入。
- 经过用户授权的基础本地提醒与安静时段。

完整范围与限制见 [阶段状态](Documentation/STATUS.md)。

## 时间与养成

养成不是自动挂机升级。训练需要实际的三次时机输入；进化条件综合成长时间、照顾失误、训练、体重、战绩、健康、亲密度与道具。当前所有阈值均为**本游戏原创平衡参数**。

时间引擎以保存的分钟游标进行确定性结算，保留不足一分钟的余量。每次操作、回到前台及前台定时刷新时都会结算；不依赖应用在后台永久运行。存档建立时固定养成时区，旅行不会重写作息；夏令时按这个时区的当地小时处理。时间倒退会阻止获得额外成长与执行养成操作；离线本地存档不能可靠防止所有改时作弊，在线竞技仍须服务端校验。

照顾不周会使伙伴生病、改变分支甚至死亡。可以在「睡眠」或「档案」中冷冻伙伴，暂停成长。

## 验证

```sh
swift test
python3 Scripts/build_content.py
python3 Scripts/generate_project.py
git diff --exit-code
```

在 macOS / Xcode 环境验证原生应用：

```sh
xcodebuild test -project DigitalWorld.xcodeproj -scheme DigitalWorld \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO
```

用 `xcrun simctl list devices available` 查找自己安装的模拟器名称并替换。GitHub Actions 会自动选择可用 iPhone 模拟器，运行核心测试、原生 UI 测试及 Release 构建，保存测试结果包和截图附件。测试状态以 [Actions](https://github.com/whodaregg/digimon-digital-world-ios/actions) 的实际结果为准。

## 结构

| 位置 | 职责 |
| --- | --- |
| `Sources/DigitalWorldCore` | 不依赖 UI 的养成、时间、进化、训练、战斗、探索与存档 |
| `Sources/DigitalWorldCore/Resources` | 独立版本化 JSON 数据与 PNG 动画图集 |
| `iOS/App`, `ViewModels`, `Views` | SwiftUI 应用与 MVVM 状态协调 |
| `iOS/PixelRenderer` | SpriteKit 动画，nearest filtering |
| `iOS/AudioSystem`, `NotificationSystem` | 原生声音、触觉、本地通知 |
| `Tests/DigitalWorldCoreTests` | 注入时钟的确定性单元测试 |
| `iOSUITests` | 模拟器上的交互与截图检查 |
| `Scripts` | 无第三方依赖的内容、素材与工程生成 |
| `Documentation` | 架构、数据来源、阶段缺口和真机验收 |

新增角色只需要扩充 JSON、PNG 和动画配置；添加已经受支持的条件组合无需修改进化引擎。新增特殊进化机制需先扩展规则 schema 和测试，不能仅靠写一个角色名字自动获得完整机制。

## 资料与素材

这是非官方开发工程。Digimon 相关名称与角色权益属于相应权利人。仓库没有复制官方立绘、动画、音乐、剧情文本或实体机 Sprite Sheet。当前 PNG 是为开发绘制的原创测试研究稿，**不属于已获授权的正式角色美术**。商用或公开发行前仍需完成相关权利、地区译名和发布审查。

资料核验与未核实字段见 [数据来源](Documentation/SOURCES.md)。
