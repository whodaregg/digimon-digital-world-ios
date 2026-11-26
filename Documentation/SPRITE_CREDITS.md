# 原版角色像素图集出处

v0.2 / v0.3 按用户要求使用 Digital Monster COLOR 的彩色角色像素，替换 v0.1 的自绘测试角色。彩色原图用于复古彩色和高级彩色；经典 LCD 是可选显示滤色，不改变保存的原图。

## 来源

- 图集归档：[furudbat/wayland-vpets — assets/dmc](https://github.com/furudbat/wayland-vpets/tree/2b05afdaa5a2ebc306b22b4950d35bd55d62c4e0/assets/dmc)。
- 固定上游提交：`2b05afdaa5a2ebc306b22b4950d35bd55d62c4e0`。
- 角色与机型交叉索引：[Digital Monster COLOR 资料页](https://humulos.com/digimon/dmc/)。
- 图集排列说明：[TamaDigi 素材说明](https://github.com/joop0810/TamaDigi#sprites)。
- 原始归档的 [第三方权利声明](https://github.com/furudbat/wayland-vpets/blob/2b05afdaa5a2ebc306b22b4950d35bd55d62c4e0/docs/fragments/copyright.md)。

| 游戏 ID | 图集角色 | 画布与帧列数 |
| --- | --- | --- |
| botamon | Botamon / 黑球兽 | 64×64，13 列 |
| koromon | Koromon / 滚球兽 | 64×64，12 列 |
| agumon | Agumon / 亚古兽 | 64×64，12 列 |
| betamon | Betamon / 蝌蚪兽 | 64×64，13 列 |
| greymon | Greymon / 暴龙兽 | 64×64，12 列 |
| tyrannomon | Tyranomon / 巨龙兽 | 64×64，12 列 |
| numemon | Numemon / 鼻涕兽 | 64×64，13 列 |
| metalgreymon | Metal Greymon (Virus) / 机械暴龙兽（病毒种） | 64×64，12 列 |

v0.3补齐Ver.1名单：Devimon、Meramon、Airdramon、Seadramon、Mamemon、Monzaemon、Blitz Greymon、Bancho Mamemon、Shin Monzaemon、Omegamon Alter-S，均来自上述同一固定提交，当时共18份原始PNG。

v0.7从相同固定提交的assets/dmc目录补入17份Ver.2原始PNG，包括Punimon、Tsunomon、Gabumon、Elecmon、Kabuterimon、Garurumon、Angemon、Yukidarumon、Birdramon、Whamon、Vegimon、Skull Greymon、Metal Mamemon、Vademon、Skull Mammon、Cres Garurumon、Ebemon。共用Alter-S后，素材包合计35种角色，Ver.1/Ver.2各17种常规养成角色及共用联展形态。每份PNG的原始哈希、尺寸、非空帧与回退动作在机器可读清单中记录；旧18份字节保持不变。

Alter-S仍是最终区敌人，也可由Ver.1电光暴龙兽与Ver.2偃月加鲁鲁兽的指定通信联展获得，不通过普通养成分支赠送。喂食图标、进食场景、外壳、背景和战斗特效为重绘，角色图集不改色、不重绘。

## 完整性与动作

这些 PNG 直接复制归档文件字节，没有重绘、修改颜色或使用生成图替代。逐文件来源 URL、SHA-256、尺寸和可用姿态记录在 `Sources/DigitalWorldCore/Resources/sprite-sources.json`，可离线运行 `python3 Scripts/validate_assets.py` 核验。

原图包含站立、开心、愤怒、倒下、进食、睡眠、拒绝等不同姿态，但部分角色有空白或缺失格。游戏动作只引用存在的原图帧，缺失时使用已有姿态回退；回退记录在 `sprites.json` 的 `fallbackActions`，不把它们宣称为完整官方动作序列。游戏自己的组合顺序和播放速度也不宣称是实体机的官方时序。

原始归档使用 64×64 画布，不代表数码兽最初的原生像素分辨率为 64×64。运行时始终采用最近邻采样。

## 权利状态

Digimon、相关角色与像素形象的权利属于 Bandai、Akiyoshi Hongo、Toei Animation 等相应权利人。归档仓库不是权利人，仓库代码的 MIT 许可不能自动覆盖这些角色像素。本项目未取得官方发行授权，素材状态标记为 `archived-digital-monster-color`，不能改标为官方授权素材。正式发行仍需完成相应权利核验。

本次没有引入上游程序代码、其他作品角色、音乐、立绘或剧情文本。游戏规则、数值、原创场景和 UI 仍由本工程独立维护。
