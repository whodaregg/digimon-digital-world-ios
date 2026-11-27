# v0.8 原版音频导入与播放

设置 → 原版音频 → 管理音频资源。勾选授权确认后可从 Files 导入 WAV、M4A、MP3、AAC 或 CAF，也可导入 ZIP。v0.9.1内置社区原机录音，默认混合模式可播放。用户导入资源库初始为空。详见[社区录音说明](COMMUNITY_AUDIO.md)。用户填写的来源和授权用于本机记录，应用无法独立确认权利。没有匹配时显示 `Missing Original Asset` 并保持静音。

- Classic Device Mode 仅匹配当前机型标记的设备或限定版资源。没有明确映射时不会播放音乐。
- Original Anime Mode 匹配选定动漫世代的资源。进化流程的设备响应独立匹配当前机型。
- Hybrid Mode 为默认设置，日常事件匹配本机型资源，进化音乐、语音、BOSS、特殊攻击、特殊事件和战斗音乐匹配动漫资源。
- 模式、动漫世代、各频道音量和静音开关按机型 ID 保存在本机。导入资源与养成存档分开。替换文件保留原映射，同内容可被多个映射共享。扫描会核对 SHA-256 并更新可用状态。

## ZIP 格式

使用一个标准、未加密、单卷 ZIP，根目录放置 `manifest.json` 和音频文件。支持 Stored 与 Deflate。文件名必须唯一，不支持链接与子目录。每个文件最大 32 MiB，资源包解压前后各限 128 MiB。映射使用下列结构。每个映射的 UUID 会在导入时重新分配，文件时长由 AVFoundation 读取。示例里的哈希和文件名需要替换。

```json
{
  "version": 1,
  "assets": [
    {
      "filename": "button.wav",
      "sha256": "<button.wav 的 64 位十六进制 SHA-256>",
      "mapping": {
        "id": "44ED9D95-D01A-4E61-B69F-D387AC6C77A8",
        "event": "keyPress",
        "category": "ORIGINAL DEVICE SFX",
        "deviceID": "dmc-ver1",
        "source": "填写文件实际出处",
        "authorization": "填写实际使用许可",
        "channel": "sfx",
        "loop": false,
        "volume": 0.8,
        "priority": 50
      }
    }
  ]
}
```

动漫映射使用 `series`，可加 `deviceID`、`speciesID`、`evolutionType`、`stage`。设备和限定版映射必须填写机型 ID。更具体的匹配优先，同等条件下限定版和较高优先级先选。频道 ID 为 `bgm`、`sfx`、`voice`、`evolutionMusic`、`battle`。背景音乐使用 `backgroundMusic` 或 `battleMusic`，进化音乐使用 `evolutionMusic`，进化语音使用 `evolutionVoice`。各事件的准确 ID 见 [AudioCatalog.swift](../Sources/DigitalWorldCore/Audio/AudioCatalog.swift)。

## 曲目与时序

| 世代 | 可填写的曲目或素材名称 | 场景校对 |
| --- | --- | --- |
| `adventure` | brave heart、Butter-Fly、进化设备／场景音效和语音 | 东映地区资料区分开场《Butter-Fly》和插曲《brave heart》。不通过曲名把开场曲绑定到所有进化。 |
| `adventure02` | Break Up!、Beat Hit!、brave heart、装甲及联展音效 | 已核对发行目录和东映公布的装甲、联展分类。应以实际片段确认曲目后分别映射为 `armorEvolution` 和 `jogress`。[唱片](https://www.feelmee.jp/index.php/item/product/665) · [东映](https://lineup.toei-anim.co.jp/ja/tv/digimon02/story/) |
| `tamers` | EVO、One Vision、SLASH!!、Card Slash、Matrix Evolution | 电视原声有 EVO 及 One Vision 的进化时长版，电影原声另有红莲骑士兽 Matrix Evolution 版。使用对应版本与场景。[电视原声](https://www.feelmee.jp/index.php/item/product/769) · [电影原声](https://www.feelmee.jp/index.php/item/product/755) |
| `frontier` | With the Will、The Last Element、Spirit／Double Spirit／Hyper Spirit 片段 | 发行目录区分和田光司原唱与翻唱，也确认《The last element》为本作插曲。三类武装进化的片段需分开核对。[原唱与翻唱](https://www.feelmee.jp/index.php/item/product/1435) · [插曲](https://www.feelmee.jp/index.php/item/product/749) |
| `savers` | Believer、Digisoul、Burst Mode | 东映标注《Believer》为插曲。具体音轨及场景需核对。[东映曲目](https://lineup.toei-anim.co.jp/ja/tv/digimon_s/song/) |
| `xrosWars` | WE ARE クロスハート！、DigiXros、Super Evolution | 东映将该曲列入插曲。可按事件和进化类型填写，不能仅凭曲名绑定所有合体。[东映曲目](https://lineup.toei-anim.co.jp/ja/tv/digimon_xw/song/) |

曲目参考：[东映 Adventure 曲目](https://lineup.toei-anim.co.jp/ja/tv/dejimon/song/) · [东映电影音乐公告](https://www.toei-anim.co.jp/movie/digimon-adventure/last-evolution/news/inc/2019121701.php) · [唱片发行目录](https://www.feelmee.jp/index.php/item/product/655)。发布资料只用来核对曲名和公开的曲目用途。当前没有逐集核对其余世代的片段，也没有预置未经确认的曲目绑定。

后续世代的下列资料已核对，世代选项和具体角色条件尚未接入。

- 东映将 2020 年版《Break the chain》标为进化插曲。[2020 年官方发布](https://www.toei-anim.co.jp/tv/digimon/news/2021042401.php)
- Ghost Game 的《First Riders》是战斗插曲，《MAKUAKE》是究极体插曲。[First Riders 官方发布](https://www.toei-anim.co.jp/tv/digimon_ghost_game/news/2021110201.php) · [MAKUAKE 官方发布](https://www.toei-anim.co.jp/tv/digimon_ghost_game/news/2022121801.php)
- 东映确认《Edge of Limit》用于 BEATBREAK 第 12 集 Geckomon 的进化场景。同批公开的《Resonance》是作品主题曲，单独记录用途。[BEATBREAK 官方发布](https://www.toei-anim.co.jp/tv/digimon_beatbreak/news/detail/?id=2025122106)

现有进化动画约 3 秒。时间轴以触发音开始，约 0.2 秒播放设备响应，0.4 秒进化音乐进入，0.63 秒语音，1.2 秒新形态音效，2.85 秒完成提示并恢复背景音乐。导入适合上述时长的自有剪辑，整首长曲会在演出结束处淡出。原始首尾无空白的 WAV／CAF 适合连续循环，带编码延迟或文件本身静音的素材仍需在源文件中处理。

按键、养成、训练、顺序闯关和现有进化演出可触发映射。喝水、洗澡、防御、特殊攻击、独立必杀和未实现的进化剧情目前预留事件 ID，游戏内还没有对应触发流程。

播放在前台遵循独立通道、背景压低、淡入淡出、按键预热和短间隔去重。进入后台停止播放，来电使用系统中断通知，后台及蓝牙耳机的具体行为仍需真机验收。系统本地通知保留文字，前台提醒播放用户导入的对应音频。

## 手机运动输入

增强模式和Sandbox可在设置打开运动输入训练。摇晃使用加速度，倾斜使用重力方向，步行使用系统计步，每10个实测步数触发一次所选按键。虚拟A/B持续可用，权限被拒或传感器不可用时仍能训练。不读取心率。在后台或离开页面时结束传感器采样。LCD亮度、按键触感、长按和组合键沿用现有控制，外壳增加呼叫与喂食灯点反馈。

目前运动输入是独立手机玩法，适用于现有 COLOR Ver.1 和 Ver.2。[v0.8.0 侧装测试包](https://github.com/whodaregg/digimon-digital-world-ios/releases/tag/v0.8.0)
