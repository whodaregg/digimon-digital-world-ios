# 修改优化功能开发指令

## 1. 目标

不要只制作静态 UI、演示界面或无实际功能的按钮。所有功能必须连接真实游戏逻辑、状态管理、动画、数据记录及存档系统。

## 2. UI 与视觉设计

- 统一使用彩色版本LCD的暴龙机
- 保留对应型号的功能图标、外壳及实体按键布局。
- 使用 Pixel Font 显示名称、数字、时间及状态。
- 现代化收藏、图鉴及设置页面必须与暴龙机LCD页面保持独立。
- 支持不同 iPhone 屏幕尺寸及安全区域适配。

## 3. 实体暴龙机按键模拟

实现三个核心虚拟按键：

- A Button：选择、切换菜单、移动选项。
- B Button：确认、执行、进入功能页面。
- C Button：取消、返回及退出菜单。

支持短按、长按、组合按键及对应型号的特殊操作。

按键必须具有像素音效、触觉反馈、按压动画及合理的防重复触发机制。

同时提供可选的 Touch Mode，允许玩家直接点击 LCD 功能图标。

## 4. 主屏幕 Home Screen

展示：

- 当前数码兽像素角色。
- 当前设备时间。
- 当前环境及背景。
- 当前设备支持的所有功能图标。
- 功能图标选中状态。
- 排泄物。
- 睡眠状态。
- 生病及受伤状态。
- 需求警报。
- 进化状态。
- 战斗及其他事件动画。

实现数码兽自主活动，包括左右移动、跳跃、眨眼、等待、转身、开心、饥饿、疲劳、睡眠及其他状态反馈。

不得让数码兽长时间保持完全静止的图片。

## 5. 状态系统 Status

实现独立的 Status 页面，使用多个可切换的 LCD 像素子页面。

记录以下数据：

- Name：数码兽名称。
- Species ID：数码兽唯一编号。
- Evolution Stage：进化阶段。
- Age：年龄。
- Weight：体重。
- Hunger：饱食度。
- Strength：力量。
- Effort：努力值。
- DP：战斗能量。
- HP：生命值。
- Level：等级。
- EXP：经验值。
- Attribute：属性。
- Type：种族。
- Battle Count：战斗次数。
- Win Count：胜利次数。
- Lose Count：失败次数。
- Win Rate：胜率。
- Training Count：训练次数。
- Care Mistakes：照顾失误次数。
- Evolution Timer：进化计时器。

严格区分可显示数据与隐藏养成数据。

经典模式下，不显示原本设备不会公开的进化条件、照顾失误次数及隐藏数值。

## 6. 喂食系统 Feed

提供 MEAT、PROTEIN 及不同版本支持的特殊食物。

MEAT 用于补充饱食度，PROTEIN 用于补充力量或对应版本定义的能力数值。

实现：

- 食物选择页面。
- 像素食物图标。
- 吃东西动画。
- 饱食后拒绝进食动画。
- 体重增加。
- 过度喂食记录。
- 道具数量及使用限制。
- 不同食物的独立作用。

喂食必须真实影响养成数据与进化条件。

## 7. 训练系统 Training

根据暴龙机型号提供不同训练模式。

包括：

- 攻击目标训练。
- 破坏墙壁训练。
- 力量蓄力训练。
- Timing 时机训练。
- 摇晃感应训练。
- 反应力训练。
- 特殊型号专属训练。

通过 Core Motion 使用 iPhone 加速度感应器实现 Pendulum 摇晃训练。

同时提供无需摇晃手机的辅助操作模式。

训练结束后显示 SUCCESS、GREAT、PERFECT 或 FAIL 等对应版本的结果。

训练结果必须影响力量、努力值、训练次数、体重、进化条件及对应设备规定的数据。

## 8. 战斗系统 Battle

建立独立、可配置的 Battle Engine。

支持：

- CPU Battle。
- Single Battle。
- Tag Battle。
- Colosseum。
- Quest Battle。
- Boss Battle。
- Bluetooth / Local Multiplayer。
- Online Battle。

数码兽战斗采用经典像素对战形式。

战斗页面展示己方及敌方角色、攻击动画、命中动画、闪避动画、生命值及战斗结果。

战斗引擎必须考虑：

- 基础战斗力。
- 属性克制。
- 当前等级。
- 努力值。
- 设备版本。
- 训练结果。
- 命中率。
- 普通攻击。
- 强力攻击。
- DP 消耗。
- 特殊能力。

支持 Vaccine、Virus、Data、Free 等属性。

Vaccine 克制 Virus，Virus 克制 Data，Data 克制 Vaccine；具体修正数值根据版本规则决定。

禁止直接让等级高的一方必定胜利。

战斗结束后真实更新胜负记录、经验值、受伤状态及进化数据。

## 9. 清洁系统 Clean

数码兽必须根据时间及成长阶段自动产生排泄物。

排泄物需要显示在 LCD 主屏幕中并持续累积。

实现清理动画、冲水动画及清洁音效。

长期不清洁会根据对应设备规则导致疾病、健康恶化及其他养成影响。

## 10. 睡眠系统 Sleep

每种数码兽及成长阶段拥有独立的睡眠时间与起床时间配置。

实现：

- 自动进入疲劳状态。
- 睡眠需求提醒。
- 开灯及关灯操作。
- 睡眠像素动画。
- ZZZ 状态。
- 自动起床。
- 睡眠干扰记录。
- 照顾失误判断。
- 睡眠期间的养成规则。

不得统一设置所有数码兽拥有相同睡眠时间。

## 11. 医疗系统 Medical

实现生病、受伤及健康异常状态。

疾病来源由设备规则决定，包括环境不卫生、战斗受伤、长期未满足需求及其他条件。

提供药物治疗、像素治疗动画及治疗结果。

支持需要多次治疗的状态。

疾病持续恶化时，可能导致数码兽死亡。

## 12. 呼叫系统 Call

实现 Attention Alert。

当数码兽饥饿、力量不足、需要睡眠或符合其他设备警报条件时，自动触发呼叫提醒。

表现形式：

- Attention Icon 闪烁。
- 经典电子提示音。
- 数码兽需求动画。
- iOS 本地通知。

玩家未在规定时间内处理指定需求时，记录 Care Mistake。

呼叫有效时间及哪些事件计入 Care Mistake 必须根据设备版本配置，不得统一使用同一规则。

## 13. 实时养成引擎 Real-Time Simulation

建立独立的 Real-Time Pet Engine。

即使玩家退出软件、锁定手机或关闭应用，数码兽的成长时间及养成状态仍需根据经过的真实时间变化。

记录 lastUpdatedAt 时间戳。

应用重新启动时，计算离线经过的时间，按照事件发生顺序补算：

- 饱食度消耗。
- 力量消耗。
- 排泄物产生。
- 睡眠及起床。
- 需求呼叫。
- 照顾失误。
- 疾病恶化。
- 成长及进化。
- 死亡状态。

禁止依赖应用在 iOS 后台永久运行。

支持时间异常检测，防止简单修改手机系统时间导致无限进化、刷经验或重复奖励。

## 14. 完整进化系统 Digivolution

支持：

- Digitama。
- Baby I / Fresh。
- Baby II / In-Training。
- Child / Rookie。
- Adult / Champion。
- Perfect / Ultimate。
- Ultimate / Mega。
- Special Evolution。
- Mega+ / Super Ultimate。

支持不同设备专属的分支进化、特殊进化、Jogress、X-Antibody 及其他适用进化类型。

使用数据驱动的 Evolution Rule Engine。

每条进化路线必须包含：

- 来源数码兽 ID。
- 目标数码兽 ID。
- 适用设备版本。
- 最短成长时间。
- Care Mistakes 条件。
- 训练次数条件。
- 努力值条件。
- 战斗次数条件。
- 胜率条件。
- 等级条件。
- 特殊道具条件。
- 关卡解锁条件。
- 合体对象条件。
- 优先级及冲突处理。

在满足对应设备的真实进化时间及条件后，自动触发进化。

进化过程展示 LCD 闪烁、像素角色变化、轮廓变化、进化音效及新数码兽登场动画。

禁止使用固定直线进化或让所有数码兽共用相同进化规则。

## 15. Jogress 合体进化

建立独立的 Jogress 页面及规则引擎。

根据不同设备支持：

- 当前数码兽与 Backup 数码兽合体。
- 双数码兽合体。
- 与其他玩家的数码兽连接进化。
- 特定种族组合。
- 特定属性组合。
- 特殊进化解锁。

合体前验证全部条件。

合体成功后根据版本规则更新参与合体的数码兽、存档及图鉴。

## 16. Quest 冒险系统

实现经典像素关卡冒险玩法。

包括：

- Area Select。
- Stage Select。
- Enemy Encounter。
- Battle。
- Boss Battle。
- Victory / Defeat。
- EXP Reward。
- Item Reward。
- Unlock Reward。

支持区域地图、随机事件、隐藏敌人及特殊数码兽。

Digital Monster X 模式需要实现对应版本的 XAI 随机机制。

Pendulum 系列需要实现对应版本的摇晃战斗机制。

关卡数量、敌人、BOSS、解锁条件及奖励必须通过独立数据文件管理。

## 17. 死亡及重生系统

当数码兽满足对应设备的死亡条件时：

- 播放死亡像素动画。
- 显示墓碑或对应型号的死亡画面。
- 记录最终数码兽形态。
- 保存生命周期。
- 保存年龄及战斗记录。
- 保存养成历史。
- 提供重新孵化数码蛋的操作。

死亡后不得删除玩家已解锁的图鉴、收藏及历史记录。

新数码蛋必须拥有独立养成数据。

特殊继承机制仅在对应设备支持时启用。

## 18. 数码兽像素动画系统

每个数码兽根据支持的动画素材提供：

- Idle。
- Walk。
- Jump。
- Happy。
- Sad。
- Hungry。
- Eat。
- Refuse Food。
- Sleep。
- Wake Up。
- Sick。
- Injured。
- Training。
- Attack。
- Critical Attack。
- Dodge。
- Hit。
- Victory。
- Defeat。
- Evolution。
- Death。

使用统一 Sprite Animation Controller 管理每个数码兽的动画帧、播放速度、循环方式及状态切换。

使用 Sprite Sheet 或独立像素帧素材。

禁止用 Emoji 或文字占位符代替正式数码兽角色。

缺少授权素材时，允许在开发阶段使用明确标记的原创测试像素素材。

## 19. 多世代暴龙机系统

建立 Device Profile 系统，支持：

- Digital Monster Original。
- Digimon Pendulum。
- Pendulum Progress。
- Pendulum X。
- Digimon Accel。
- Digimon Mini。
- Digimon Twin。
- Digital Monster Ver.20th。
- Pendulum Ver.20th。
- Digital Monster X。
- Pendulum Z。
- Digital Monster Color。
- Pendulum Color。
- Vital Bracelet。
- Vital Bracelet BE。
- 后续新增型号及限定版本。

每个 Device Profile 独立定义：

- 设备外观。
- LCD 尺寸。
- 像素色彩模式。
- 功能图标。
- 按键规则。
- 数码兽名单。
- 数码蛋种类。
- 进化路线。
- 养成参数。
- 训练方式。
- 战斗引擎配置。
- 冒险关卡。
- 死亡规则。
- 存档规则。
- 特殊功能。

禁止仅通过更换外壳颜色来区分不同世代。

## 20. 暴龙机收藏库 Device Collection

创建独立的设备收藏页面。

展示每款暴龙机的名称、发行系列、版本、设备外观、养成名单及收藏进度。

允许选择不同设备进行养成，并保存各自独立的养成存档。

切换设备时，原有数码兽状态必须正确保存，并按照其设备规则继续成长或暂停。

## 21. 数码兽图鉴 Digidex

建立完整的数据驱动图鉴。

展示：

- 数码兽编号。
- 中英文及日文名称。
- 像素角色。
- 进化阶段。
- 属性。
- 种族。
- 所属设备。
- 动画预览。
- 进化路线。
- 已解锁状态。
- 首次获得日期。
- 获得次数。
- 收藏完成率。

未解锁数码兽显示黑色剪影或问号。

支持搜索、属性筛选、成长阶段筛选、设备版本筛选及收藏筛选。

新增数码兽数据后自动更新图鉴，无需重新编写页面。

## 22. Backup、Freeze 与多宠养成

根据设备版本支持：

- Backup Slot。
- Cold Mode / Freeze。
- 双数码兽同时养成。
- 数码兽切换。
- 独立状态记录。
- 独立进化计时。
- 存储数码兽的成长暂停。

被冷冻的数码兽必须按照对应规则停止成长、消耗及疾病变化。

经典模式必须保留设备原有功能限制。

## 23. 联机系统 Connection

实现 iPhone 之间的本地连接及在线对战。

支持：

- 好友连接。
- 搜索附近玩家。
- 邀请战斗。
- 本地无线对战。
- 在线房间。
- 好友切磋。
- 支持版本之间的 Jogress。
- 战斗历史记录。

使用 Multipeer Connectivity、GameKit 或适合项目架构的网络模块。

必须建立设备兼容性规则。

真实实体暴龙机的物理通信连接应作为独立扩展模块，需要兼容硬件及通信协议，不得将普通手机蓝牙直接视为能够连接所有实体暴龙机。

## 24. 设备设置 Settings

提供：

- 音效开关。
- 音量调整。
- 触觉反馈。
- LCD 对比度。
- 屏幕亮度。
- 外壳颜色。
- LCD 配色。
- 彩色背景。
- 系统时间显示。
- 本地通知。
- 语言设置。
- 存档备份。
- 恢复存档。
- 重置设备。

重置操作必须提供二次确认。

支持简体中文、繁体中文、英文及日文。

## 25. 游戏模式

提供三个独立模式。

CLASSIC MODE：

严格遵循实体暴龙机原有的养成规则、按键限制、进化条件及隐藏数据。

ENHANCED MODE：

在经典养成基础上增加触屏操作、完整图鉴、收藏、通知、养成历史及现代辅助功能。

SANDBOX MODE：

允许测试不同数码兽、进化路线、战斗、动画及时间变化。

Sandbox 的数据必须与正式养成记录隔离，不得用于解锁正式收藏及在线战斗优势。

## 26. 技术架构

优先采用原生 iOS 架构：

- Swift。
- SwiftUI。
- SpriteKit 或适合像素渲染的原生组件。
- SwiftData / SQLite。
- Core Motion。
- UserNotifications。
- AVFoundation。
- Core Haptics。
- GameKit。
- Multipeer Connectivity。
- CloudKit / iCloud。

如果现有项目已经采用其他成熟技术架构，应优先兼容现有项目，不得无理由重写整个软件。

建立独立核心模块：

- DeviceManager
- PetEngine
- TimeSimulationEngine
- EvolutionEngine
- BattleEngine
- TrainingEngine
- CareEngine
- SleepManager
- QuestManager
- JogressEngine
- SpriteAnimationManager
- NotificationManager
- SaveManager
- CollectionManager
- MultiplayerManager

所有游戏规则必须与 UI 层分离。

## 27. 数据结构及扩展性

使用 JSON、数据库及可配置的数据模型管理：

- DigimonSpecies
- DeviceProfile
- EvolutionRule
- PetInstance
- SpriteDefinition
- FoodDefinition
- ItemDefinition
- TrainingRule
- BattleRule
- QuestStage
- JogressRule
- CareEvent
- BattleRecord
- LifecycleRecord
- SaveData

所有数码兽使用唯一 ID。

所有设备使用唯一 Device ID。

新增数码兽、进化路线、设备版本及像素素材时，不需要修改核心游戏引擎。

未经验证的数码兽名单、数值及进化条件必须标记为待补充数据，不得编造为官方规则。

## 28. 最终开发要求

首先检查现有项目的目录结构、页面、数据模型、资源文件及游戏逻辑。

保留现有已经正常工作的功能与设计。

补全缺少的功能模块，修复重复及冲突的状态管理。

不得为了新增功能而删除原有正常功能。

禁止创建只有视觉效果而无法操作的页面。

所有按钮、功能图标、训练、战斗、养成及进化都必须可以真实执行。

建立自动存档、异常恢复、数据迁移及错误处理机制。

针对离线成长、分支进化、死亡、重生、时间变更、训练、战斗及设备切换建立自动化测试。

最终输出：

1. 完整项目架构。
2. 所有页面及导航结构。
3. 可运行的游戏核心逻辑。
4. 数据模型及数据库。
5. 像素素材管理系统。
6. 所有功能的实际操作逻辑。
7. 测试报告。
8. 未实现功能及依赖清单。

最终效果必须是一款真正可长期游玩的实体数码暴龙机模拟器，而不是一个只有数码宝贝主题的普通宠物应用。