# 工程结构与规则隔离

## 两种存档语义

默认设备`dmc-ver1`使用独立的`DMCV1Engine`和`dmc-ver1.json`。`TimeEngine`、`GameEngine`按设备分派；旧训练/战斗/地图入口拒绝接收Ver.1存档。旧`ultimate-lab`档案继续走原实验规则，避免迁移后重新解释已有养成结果。

`Species.stats/evolutions/lifespanMinutes`保留旧规则所需字段。Ver.1从`DMCV1Rules`读取力量、作息、DP、进化和固定Quest数据，不套用旧HP伤害、体重进化门槛、亲密度或14天寿命。

## 模型与时间

`Pet.dmc`保存本阶段训练、失误、满腹、睡眠打扰、伤势等计数；`GameState.dmc`保存Quest进度、训练循环、背景和一只备份。公共模型继续提供图鉴、历史、设置、日志和旧档兼容。

孵化使用独立8秒截止时间，之后分钟游标锚定实际孵化时刻，不丢弃不足一分钟的余量。前台刷新、恢复前台、操作前和离线结算共享同一引擎；不依赖后台永久运行。固定养成时区，时间倒退不授予成长或操作。Cold和备份暂停成长；睡眠仍计进化时间，暂停伤势/空心死亡计时。

随机行为使用存档中的种子生成器。进化截止时间只判定一次，不因重开应用重复抽取。普通分支使用可配置规则，跨版本联展不会伪装成普通进化。

## Quest事务与界面

Ver.1的8区固定敌人顺序写入独立数据，每次整区挑战在事务副本中计算到通关或败北。每场记录战绩，整区仅消耗1DP/6g；胜过区域Boss后解锁下一区及对应背景。完整结果先保存，再播放交替出招、回避/命中与胜败分镜，关闭演出不能重抽战果。

`BattleRecord.hitSequence`是兼容旧档的可选字段。`QuestReplay`验证并转换命中序列，旧战绩兼容读取原日志；不执行随机数、扣除或养成变更。`DMCQuestResult.playerSpeciesID`固定入场形态。`QuestPlaybackController`只推进演出和切换已保存的敌人，`QuestBattleScene`以原图姿势和像素特效播放，自动续战与跳过使用同一份结果。

原味界面显示四心、DP与三次命中标记，没有方向坐标或HP。七个可操作图标加一个呼叫指示，A选择、B确认，未选择时B显示时钟，C清空选择。图鉴、档案、设置另有触屏入口。

## 存档与恢复

外层信封包含版本、FNV-1a校验及Base64编码的JSON载荷。校验用于意外损坏检测，不是防篡改加密。内层格式v5；v1补齐时间水位，v1/v2/v3/v4解码缺失的原味及测试可选字段为nil，保留原设备与养成语义。未来版本拒绝打开。

写入使用Foundation原子写入；上一版备份只从已验证的主档更新。主档损坏时恢复有效备份并保留损坏文件。导入先验证再恢复，并另存恢复前完整档案。

“备份旧档并开始Ver.1”先保存独立文件，再创建新档并继承显示设置。设置提供“恢复切换前档案”和该文件的导出；恢复前同样保留当前档案。单伙伴备份交换与整份存档恢复是独立功能。

## 像素与生成

角色PNG保留归档原始字节，64×64画布、12/13列、1行。`sprites.json`为每个角色配置存在的帧及缺失姿势回退，最近邻采样；灰绿色通过显示着色器转换，原图不改色。背景是本工程重绘主题。

`PixelAtlas/PixelActor`共享最近邻纹理缓存、姿势和LCD着色器，主页与战斗使用相同的原图。主页移动使用可测试的AmbientPetTimeline，图集帧使用统一SpriteAnimationClock，照顾或身体状态变化会中断闲逛；SwiftUI时钟刷新不反复重启动作。系统减弱动态效果关闭位移、循环帧与闪烁。

`build_content.py`与`dmc_content.py`生成JSON，`validate_assets.py`核对SHA-256、尺寸、角色引用与非空帧，`generate_project.py`生成本地依赖的Xcode工程。核心、UI和Release由GitHub Actions分别验证。

## 开发测试

`DeveloperEngine`在事务副本上应用角色、库存或数值修改并通过存档验证后提交。`DeveloperTuning`按伙伴保存战斗覆盖，不修改共享资料；`developerModifiedAt`标记测试档。界面模型每次会话首次写入前保存独立快照，成功落盘后发布新状态。解锁状态仅在内存中，后台和关闭时清除。详见[开发测试说明](DEVELOPER_TOOLS.md)。

## 设备库与三种模式

GameMode继续表示原味/旧实验规则；PlayStyle单独表示classic/enhanced/sandbox，避免把界面模式当成另一套养成数值。DeviceLibraryStore在devices.json保存设备索引，每个UUID拥有独立的SaveStore目录、主档与备份。旧world.json只读迁入独立设备，原文件保留。切换先保存当前设备，再验证/结算目标并更新索引；不覆盖其它设备。

Sandbox首次进入复制当前伙伴到独立文件。DeveloperEngine只通过Sandbox页面调用；正式收藏按CollectionManager过滤Sandbox、旧实验与测试标记。SandboxEngine以持久化时间偏移调用同一TimeEngine，不改系统时间。导入保留前档，并创建独立设备。

生命周期会在死亡时捕获，在32个Pet档位满后将已归档死者移出活动数组，保留独立LifecycleRecord、形态、战绩和日志。重置使用reset原因归档，不伪造死亡。首次获得只使用实际记录的SpeciesAppearance；旧档没有日期时不编造。

## LCD与现代页面导航

WorldView -> ColorDeviceView -> LCD主页/状态分页/食物/训练/区域/对战/电源/时钟/设置。DeviceInputRouter解释真实A/B/C事件，输出命令再由WorldViewModel执行核心和保存；Touch Mode走同一命令。经典模式只有原机公开的状态分页，禁止在连战中取消。

图鉴、设备收藏、档案、设置、开发测试和手机连接使用独立现代页面。完整页面范围和未完成部分见FEATURE_STATUS.md。

## 提醒、运动与连接

AttentionForecast在世界副本上运行同一时间引擎，预测空腹/力量/睡眠等呼叫，不修改真实存档；NotificationCoordinator收集多个正式设备计划并应用安静时间和系统通知数量限制。

MotionInputCounter只负责电话传感器输入的去抖与峰值计数；MotionTrainingController将Sandbox输入送入真实A/B训练，提供按钮替代。它不冒充Pendulum固件或机型规则。

ConnectionEngine验证机型、档案域与过期快照，计算一致战果并用持久化通信收据防重放。ConnectionCoordinator负责Multipeer/GameKit传输；实际结果仍通过同一保存事务落盘后演出。配置与实机依赖见CONNECTION.md。
