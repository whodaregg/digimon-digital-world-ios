# 实测记录

## v0.6 LCD养成、独立设备与动画

记录日期：2026-11-26（Australia/Sydney）。保留既有项目、旧档和原图，在原工程上续做。最终源码为`f1ff3682fcb972536e28248fa0447fd50ee6e8aa`，[最终验证任务](https://github.com/whodaregg/digimon-digital-world-ios/actions/runs/45736796091)已全部通过。其后仅整理文档与实测截图，不修改应用、核心或测试源码。

- 本地Linux / Swift 6.0.3及GitHub macOS 15：**80项核心测试通过，0失败**。
- Xcode 16.4 / iPhone 16 Pro / iOS 18.5 / arm64：**13项原生UI测试通过，0失败**，用例执行398.603秒，另有模拟器启动和测试基础设施耗时。
- Debug应用与测试runner、通用iOS Simulator目标的Release构建通过。同型号设备的Sandbox来源由核心测试覆盖；原生用例验证返回时保留经典模式，以及指定角色、道具、力量和恢复调试快照的完整流程。
- 18份角色PNG的SHA-256、尺寸、非空帧引用均通过，保持归档原始字节；三份像素字体SHA-256与出处记录一致。
- 内容和Xcode工程重新生成无差异；像素字体注册、字体资源、本地网络和运动权限声明、Game Center默认关闭检查通过。

### 覆盖范围

核心覆盖离线成长与分支、四心喂养/训练/睡眠/伤势/死亡、Cold和备份、逐场Quest与回放、存档迁移/损坏/容量保护、按键组合、独立设备与Sandbox、生命周期/图鉴、通知预测、通信双方一致性与防重放，以及设备钟面不快进成长。

13项原生用例实际操作：经典按键及隐藏数据限制；访问码与后台重新上锁；开发指定角色、道具、力量与恢复；设备新增/切换；动态图鉴；孵化/时钟/状态；大角色走动/转向/开心与真实字体注册；LCD喂食/训练并核对状态；旧实验档备份恢复；三种配色；首区三场连续攻击/回避/命中/胜败；重置取消/确认；Sandbox推进后返回正式设备。

前轮检查曾发现LCD容器覆盖子控件标识、空视图承载弹窗/确认、行点击范围、角色朝向及生成工程丢失字体声明等实际问题，已修复并加入对应验收。早先一次主分支任务在`simctl list`超时，发生于原生编译之前；重跑该iOS任务后13项全部通过，不将基础设施失败误报为应用测试通过。

### 本轮实际截图

下列PNG从最终任务的`native-ios-validation`结果包直接提取，保持测试附件原始字节，未用设计图代替。结果包SHA-256已核对为`79c92e7cdd18b3570a78327a4e037a893173ee91c89a1e7276c79eea6e188796`。

- 主页[走动](Screenshots/lcd-home-walk.png)、[转向](Screenshots/lcd-home-turn.png)、[开心](Screenshots/lcd-home-happy.png)。测试同时读取实际节点位置和朝向，截图只是其中的定格。
- 首区[第一战](Screenshots/lcd-quest-attack-1.png)、[第二战](Screenshots/lcd-quest-attack-2.png)、[第三战](Screenshots/lcd-quest-attack-3.png)出招，以及[命中标记](Screenshots/lcd-quest-hit.png)、[区域通关](Screenshots/lcd-quest-clear.png)。
- [灰绿色LCD](Screenshots/lcd-gray-green.png)、[动态图鉴](Screenshots/lcd-digidex.png)、[Sandbox开发数值](Screenshots/lcd-developer-stats.png)、[旧实验档恢复](Screenshots/lcd-legacy-preserved.png)。

### 验证边界

本轮不生成IPA，也未运行真机打包工作流。模拟器编译和交互通过不等于真实iPhone安装验收。两台手机附近连接、Game Center账号匹配、虚拟A/B/C多指与触觉、运动传感器、通知实际送达、iOS17最低版本、多屏幕/无障碍和长期性能仍按[真机清单](DEVICE_CHECKLIST.md)待验。其它世代、联展和完整翻译等未实现项目见[28项状态与依赖](FEATURE_STATUS.md)。

以下v0.4/v0.3均为历史记录，其IPA和截图不代表v0.6。

## v0.4.0 真机IPA

[真机打包任务](https://github.com/whodaregg/digimon-digital-world-ios/actions/runs/45695925289)已成功，构建源码为`2ac41ec9aa1b2fd6cdf4609c2fdcda45ec397e14`；游戏应用、核心与测试源码与下述已验证版本保持一致。

- 使用iPhoneOS SDK编译Release，通过Mach-O平台IOS与arm64架构检查，最低iOS17.0。
- IPA包含正确的Payload应用、Info.plist和游戏内容，ZIP完整性检查通过，不包含个人描述文件。
- 已发布[未签名开发测试包](https://github.com/whodaregg/digimon-digital-world-ios/releases/tag/v0.4.0)，文件`DigitalWorld-v0.4.0-unsigned.ipa`，899335字节。
- 从发布页重新下载后，包结构、iPhoneOS标记、18份原始角色PNG哈希及SHA-256均核验一致。
- IPA SHA-256：`61f5d2f82d98b87c9e1872d91a7fbc52ea3aef615bb80f8c748005e60c3ebb95`。

此包需要用户自行签名，尚未完成真实iPhone安装与运行验收；不能把真机SDK构建成功表述为真机实测通过。

## v0.4 隐藏开发测试

记录日期：2026-11-26（Australia/Sydney）。[本轮完整验证任务](https://github.com/whodaregg/digimon-digital-world-ios/actions/runs/45691269111)已全部通过，实际验证源码为 `7bc23b87c9264c45bb61bd90b0028f6f83656a00`，其后仅整理文档与实测截图。

- Linux / Swift 6.0.3及GitHub macOS 15：**56项核心测试通过，0失败**。新增9项覆盖全部18种角色指定、道具/自定义库存边界、原子拒绝、实际Quest力量覆盖、DP容量、旧版HP/攻防战斗、过期草稿、保留另一只备份伙伴及v3→v4迁移。
- Xcode 16.4 / iPhone 16 Pro / iOS 18.5 / arm64：**7项原生UI测试通过，0失败**，用例执行约199秒，另有模拟器启动与测试基础设施耗时。
- 新增界面用例实际验证错误访问码拒绝、正确码解锁、后台与关闭后重新上锁；另一用例走通选择电光暴龙兽→选择并发放8个进化芯片→设置战斗力量500→保存→恢复调试前亚古兽存档。
- Debug应用与测试runner编译、通用iOS Simulator目标的Release构建均通过。
- 18份原版角色PNG的哈希、尺寸与帧映射校验通过；重新生成内容和Xcode工程无差异。

[开发数值页实测截图](Screenshots/developer-stats.png)已保留。

初轮检查发现道具行的空白区域没有响应选择，已修复整行点击范围，并增加发放前的选中状态及实际ID断言；上述完整通过结果来自修复后的版本。

真机Release安装、硬件触觉、长期使用和系统分享导出仍按[真机清单](DEVICE_CHECKLIST.md)待验。固定访问码只提供本机隐藏开关，不构成账号访问控制；功能与备份行为见[开发测试说明](DEVELOPER_TOOLS.md)。

## v0.3 原味养成验证（历史）

记录日期：2026-11-26（Australia/Sydney）。本页记录实际执行结果，不代表真机发行或实体机逐项一致性验收完成。

[本轮验证任务](https://github.com/whodaregg/digimon-digital-world-ios/actions/runs/45684163845)，应用及测试源码原验证提交为 `fec9074067f9940ddc115508d2bca81e4f6def62`，在中文提交历史中对应 `dd37719b9c176da139e1c8e8bf009434d4f2ad41`，两者文件树哈希一致。后续截图和文档整理不修改应用、规则或测试源码；提交说明中文化只修改历史提交元数据，并逐提交校验文件树一致。

### 游戏核心与素材

- 恢复任务后在Linux / Swift 6.0.3重新运行核心测试：**47项通过，0失败**。
- 本轮GitHub macOS 15核心测试：**47项通过，0失败**。
- 初次核心任务因托管arm64执行器容量不足、未被领取而取消；单独重试该项后成功。整轮核心、原生界面和Release检查现已全部通过。
- 28项公共/旧档测试与19项Ver.1专项测试覆盖8秒孵化、成长阈值、离线与分次结算、四心/满腹/蛋白质、训练成败与取消、照顾失误、分支边界、高阶战绩、固定Quest/解锁/重试/一次消耗、Cold/一只备份、睡眠与DP恢复、伤势死亡计时、时间倒退及存档损坏拒绝。
- 18份角色图集的SHA-256、尺寸和非空帧引用校验通过，保存的PNG保持归档原始字节。
- 内容及Xcode工程重新生成后，应用、核心、测试和工程文件没有差异；JSON、plist和scheme XML已通过解析检查。

补充开发机模拟时钟回放已走通黑球兽→滚球兽→亚古兽→暴龙兽→机械暴龙兽→电光暴龙兽的完整路线。这是加速软件回放，不是8天真实设备养成验证，不计入上述47项测试。

### 原生应用与显示切换

环境：**Xcode 16.4 / iPhone 16 Pro / iOS 18.5 / arm64**。Debug应用与测试runner编译成功，**5项UI测试全部通过，0失败**，测试用例合计约203秒：

1. 喂肉、A/B五次攻击训练并验证成功、进入显示设置。
2. 新蛋孵化与A/B按键导航，未选择图标时B打开时钟。
3. 旧版养成切换至Ver.1，保存并恢复切换前档案。
4. 默认彩色，依次选择灰绿色LCD、高级彩色、复古彩色并检查勾选状态。
5. 固定Quest首区可挑战、后区锁定、战斗结果/返回区域选择、图鉴搜索；没有方向移动按钮。

日志包含 `Executed 5 tests, with 0 failures`。此前弹出式显示菜单的点击定位失败，改为页面内直接选择后，本轮已通过；不能将之前失败的整轮任务描述为成功。

### Release构建

本轮通用iOS Simulator目标的Release构建成功。它验证编译，不包含真机签名、安装或运行。

### 实际截图

下列图片来自本轮成功的原生UI测试结果包，未使用设计图代替。场景背景为本工程重绘，角色为归档原版像素。

- [彩色主界面](Screenshots/ver1-color-home.png)
- [固定顺序Quest区域](Screenshots/ver1-quest-areas.png)
- [三次命中判定与败北结果](Screenshots/ver1-quest-result.png)
- [灰绿色LCD](Screenshots/ver1-lcd-preview.png)、[高级彩色](Screenshots/ver1-advanced-preview.png)、[复古彩色](Screenshots/ver1-color-preview.png)
- [伙伴状态](Screenshots/ver1-status.png)

### 尚未验证或实现

真实iPhone/iPad安装、iOS17最低系统、通知实际送达、硬件静音/触觉、长期养成、性能/内存、VoiceOver/大字体与iPad分屏仍待验收。隐藏参数存在资料分歧，尚无实体机并行一致性验证。通信、跨版本联展、其他历代机型、Watch、Widget、HealthKit、iCloud等未完成。

详见[规则出处](RULE_SOURCES.md)与[真机验收清单](DEVICE_CHECKLIST.md)。
