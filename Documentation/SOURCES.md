# 数据来源与核验边界

核验日期：2026-11-26。来源为官方 Digimon Encyclopedia 的公开角色页。只记录少量结构化身份字段，不复制简介、立绘或素材。

| 角色 | 官方页面 | 此次核实字段 |
| --- | --- | --- |
| Botamon | https://digimon.net/reference_en/detail.php?directory_name=botamon | 英文名称、In-Training I、Slime、Acid Bubbles；属性栏为空 |
| Koromon | https://digimon.net/reference_en/detail.php?directory_name=koromon | 英文名称、In-Training II、Lesser、Foam；属性栏为空 |
| Agumon | https://digimon.net/reference_en/detail.php?directory_name=agumon | 英文名称、Rookie、Reptile、Vaccine、Pepper Breath |
| Betamon | https://digimon.net/reference_en/detail.php?directory_name=betamon | 英文名称、Rookie、Amphibian、Virus、Electric Shock |
| Numemon | https://digimon.net/reference_en/detail.php?directory_name=numemon | 英文名称、Champion、Mollusk、Virus、Poop Toss |

`baby1`/`baby2` 是游戏内部阶段标签，对应官方页面的 In-Training I/II。英文 Ultimate 与日文 Ultimate 存在阶段译名差异，内部枚举通过固定顺序区分，不能按字符串相似性当作同一阶段。

Greymon、Tyrannomon、MetalGreymon 为开发用种子条目，此次未完成对应官方版本身份核验，`verifiedFields` 为空，`referenceURL` 留空。特别注意 Greymon 的官方目录可能指向 2010 动画版；不能仅凭相似页面路径声明已核实 1997 版本。

所有角色的中文/日文显示名、首次登场、家族、世代归属、官方机型名单仍需逐项复核。目前 `generation=initial-content` 和 `devices=[ultimate-lab]` 仅表示本次内容包归属，不宣称为官方历史分类。

以下全部属于本游戏原创参数：HP、攻击、防御、速度、暴击、体力、DP、技能伤害计算、食物影响、睡眠时间、寿命、全部进化阈值与路线、稀有度测试标记、解锁条件、运动以外的训练计分、地图与任务。官方角色页不是这些参数的来源。

实体机说明书核验尚未完成。机型选择目录来自需求范围，用于跟踪工作；不是已核验的产品型号清单，也不是已支持机型数量。Original Mode 暂不开放。

v0.2 已将 8 个自绘测试角色图替换为 Digital Monster COLOR 的彩色角色归档图集，来源与 SHA-256 记录见 [素材出处](SPRITE_CREDITS.md)。原版角色像素、原创场景/按键音、原创养成规则分别管理；没有把归档来源标为官方发行授权。
