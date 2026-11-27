# 上传图集养成

v0.9 接入用户提供的 `dmall.zip`，含844份数码兽PNG。目录、逐文件字节与上游固定提交 `2b05afdaa5a2ebc306b22b4950d35bd55d62c4e0` 的 `assets/dmall` 对应。新增角色使用 `archive-` 前缀，原有35个角色ID和存档继续可用。内容库总计879条记录，部分相同名称角色保留了不同来源的条目。

## 操作

打开「机型与规则」，选择「选择数码兽开始养成」。搜索使用原英文文件名，例如 `Agumon (Black) X`。点「开始养成」后建立独立档案，当前档案先保存。之后可通过现有主页进行喂食、精准训练、离线成长、清洁、治疗、睡眠、冷冻和通用PVE对战，并通过设备收藏切换档案。

图集养成采用现有通用游戏规则和统一初始战斗数值。来源仅提供图像，因此新增条目的阶段、属性、招式和进化路线待核对。当前角色以所选形态开始养成，没有给844个角色虚构进化分支。对应字段保留待核对状态，名称沿用原文件名。

PNG原始字节与配色保留，三种显示模式可继续切换。动作沿用图集帧序，缺失或空白帧回退至已有姿态，并记录在 `sprites.json` 的 `fallbackActions`。本次资源只取上传包的 `dmall/*.png`。

## 来源

用户上传包的SHA-256、角色名和稳定ID在 `Scripts/Data/archive-roster.json`。每份图片的SHA-256、尺寸、非空帧、原路径和来源URL在 `sprite-sources.json`。上游第三方权利说明继续有效，新增图片保留该声明，不改变原始素材许可。

[固定版本素材目录](https://github.com/furudbat/wayland-vpets/tree/2b05afdaa5a2ebc306b22b4950d35bd55d62c4e0/assets/dmall) · [素材权利声明](https://github.com/furudbat/wayland-vpets/blob/2b05afdaa5a2ebc306b22b4950d35bd55d62c4e0/assets/COPYRIGHT.md)

## 验证

94项核心、23项原生界面和4项中继测试，以及Debug/Release模拟器编译已通过。详细范围见[实测记录](VALIDATION.md)。
