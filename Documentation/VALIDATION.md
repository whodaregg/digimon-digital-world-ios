# 实测记录

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
