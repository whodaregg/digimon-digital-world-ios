# 实测记录

记录日期：2026-11-26（Australia/Sydney）。以下仅记录实际执行的验证，不代表全部需求或真机发布验收完成。

## 游戏核心

- Linux / Swift 6.0.3：`swift build` 成功，`swift test` **26 项通过，0 失败**。
- GitHub macOS 15 runner：相同核心 **26 项通过，0 失败**。
- 测试覆盖：内容引用、素材存在、Original Mode 门禁、孵化阈值、离线/分次结算一致性、不足一分钟余量、重复结算、时钟倒退、固定时区/夏令时睡眠、冷冻、疾病/治疗、过量喂食、死亡/重生、旧档案防重复重生、照顾/训练分支、进化道具一次性消耗、时机训练成功/失败/防重放、种子战斗、属性克制、地图碰撞/宝箱去重/任务奖励、存档回读/损坏恢复/版本迁移/未来版本拒绝。
- 内容与工程重新生成后 `git diff --exit-code` 通过；JSON、plist、scheme XML 格式检查通过。

核心验证与原生 UI 使用应用源码提交 `49a9c3f3548c719291b57c4dd17c3ec53f7e5469`。

## 原生 iOS 应用

环境：**Xcode 16.4 / iPhone 16 Pro 模拟器 / iOS 18.5 / arm64**。

原生 Debug 构建和测试 runner 编译成功，**3 项 UI 测试通过，0 失败**：

1. 原创冒险地图打开、图鉴搜索。
2. 实际喂食、开始训练、确认输入、取消训练、打开显示设置。
3. 首次孵化与虚拟 B 键打开伙伴状态。

执行记录显示 `Executed 3 tests, with 0 failures` 和 `** TEST SUCCEEDED **`，测试用例合计约 138 秒。测试基础设施还花费较长时间启动模拟器，因此该总步骤耗时约 9 分钟。附图为这次测试中实际捕获的屏幕，没有用设计图替代。

[核心与 UI 验证任务](https://github.com/whodaregg/digimon-digital-world-ios/actions/runs/45663871437)

这次工作流整体标记为 **cancelled**：取得诊断日志时，编译及 UI 步骤已经成功，停止操作中断了随后开始的 Release 构建；不能把整体状态描述为全流程成功。之后将 Release 拆为独立任务补验。

## Release 构建

[独立 Release 验证任务](https://github.com/whodaregg/digimon-digital-world-ios/actions/runs/45666176087)

**结果：成功。** Xcode 16.4 的 `Release` 配置在通用 iOS Simulator 目标上构建通过，日志为 `** BUILD SUCCEEDED **`。任务于 2026-11-26 04:35（Australia/Sydney）完成。该任务使用同一应用、核心、资源和 UI 测试源码；后续变更仅涉及文档、截图和 CI 的步骤拆分。真机签名与设备运行仍未验证。

## 尚未验证

- 真实 iPhone/iPad 安装、签名与 iOS 17 最低系统运行。
- 通知实际送达、静音/触觉硬件表现、文件选择器跨设备恢复。
- 一周以上连续养成、真实电量、Instruments 性能/内存、VoiceOver/大字体和 iPad 分屏。
- 后续尚未实现的联机、历代实体机规则、特殊进化、Watch、HealthKit、Widget、iCloud 等功能。

真机后续工作见 [验收清单](DEVICE_CHECKLIST.md)。
