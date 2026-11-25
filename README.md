# DIGIMON · DIGITAL WORLD

原生 iOS 17 像素电子宠物工程，使用 SwiftUI、SpriteKit 与独立 Swift 游戏核心。**v0.3 默认以 Digital Monster COLOR Ver.1 为基准：彩色养成＋8区顺序闯关。** 角色采用原版彩色像素归档图集，设置可自由切换复古彩色、高级彩色和经典灰绿色 LCD，并保存选择。

目前是开发版本，未完成最初需求中的全部阶段。操作依据官方说明书，隐藏数值参考社区实测；资料分歧和待验证部分见 [规则出处](Documentation/RULE_SOURCES.md)。

## 在 Xcode 运行

1. 克隆仓库，用 Xcode 16 或更新版本打开 `DigitalWorld.xcodeproj`。
2. 选择 **DigitalWorld** scheme 和 iPhone/iPad 模拟器，按 **Run**。
3. 在欢迎页孵化 Ver.1 数码蛋，约8秒后诞生。应用关闭后再打开会结算离线时间。

Swift Package 位于仓库内，无第三方库依赖。真机需在 Signing & Capabilities 选择自己的开发团队和唯一 Bundle ID；仓库不包含签名证书或已签名 IPA。

## 当前玩法

- 四颗饱食心、四颗力量心、努力、年龄、体重、DP与通算胜率。
- 肉和蛋白质；A上段/B下段五次攻击训练，命中至少三次成功；完整失败训练也计入努力与进化条件。
- 按角色作息睡眠、关灯、睡眠打扰、Cold暂停成长、一只伙伴备份交换、清洁和多次治疗。
- 照顾失误、训练、满腹、睡眠打扰与战绩决定进化；包含Ver.1的17种养成角色。
- Quest按AREA 1～7、F顺序解锁；每区固定3～5个敌人，连续战斗，先命中三次获胜。失败需从本区首战重来，每次整区消耗1DP、减重6g。
- Alter-S作为最终区敌人收录；通信和联展尚未开放。
- 原版角色像素、三种显示模式、可解锁的重绘背景主题、A/B/C按键与触屏快捷操作。
- 图鉴、中文规则说明、成长日志、本地自动存档与损坏恢复、v1/v2旧档兼容、验证后的文件导入与导出。

原味界面已移除平面上下左右探索。旧版实验存档继续按旧规则读取，可在设置中“备份旧档并开始 Ver.1”；切换前会另存完整旧档，显示设置会保留。设置中可直接恢复或导出切换前档案。

## 验证

```sh
swift test
python3 Scripts/build_content.py
python3 Scripts/validate_assets.py
python3 Scripts/generate_project.py
git diff --exit-code
```

macOS原生验证：

```sh
xcodebuild test -project DigitalWorld.xcodeproj -scheme DigitalWorld \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

模拟器名称按 `xcrun simctl list devices available` 调整。GitHub Actions执行核心、原生界面与Release构建检查，实际状态见 [Actions](https://github.com/whodaregg/digimon-digital-world-ios/actions)；已完成验证见 [实测记录](Documentation/VALIDATION.md)。

## 工程与资料

| 目录 | 内容 |
| --- | --- |
| `Sources/DigitalWorldCore/DeviceRules` | Ver.1独立规则、时间/养成/训练/Quest与数据模型 |
| `Sources/DigitalWorldCore/Resources` | 版本化内容、规则JSON、原始角色PNG及出处哈希 |
| `Sources/DigitalWorldCore` 其余目录 | 旧规则兼容、公共模型、存档、素材读取 |
| `iOS` | SwiftUI界面、SpriteKit像素显示、声音、触觉、本地通知 |
| `Tests`, `iOSUITests` | 确定性核心测试与模拟器交互测试 |
| `Scripts` | 内容、素材校验与Xcode工程生成 |

- [中文更新记录](CHANGELOG.md)
- [规则出处与分歧](Documentation/RULE_SOURCES.md)
- [角色像素出处](Documentation/SPRITE_CREDITS.md)
- [范围与未完成功能](Documentation/STATUS.md)
- [真机验收清单](Documentation/DEVICE_CHECKLIST.md)

这是非官方开发工程。角色PNG保留归档原始字节，没有用自绘或生成角色冒充原版。原始素材与权利状态详见出处文档，归档来源不等于官方发行授权。
