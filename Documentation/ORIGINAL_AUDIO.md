# v0.8 原版音频导入与播放

设置 → 原版音频 → 管理音频资源。勾选授权确认后可从 Files 导入 WAV、M4A、MP3、AAC 或 CAF，也可导入 ZIP。应用发行包的音频库初始为空。用户填写的来源和授权用于本机记录，应用无法独立确认权利。没有匹配时显示 `Missing Original Asset` 并保持静音。

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
| `adventure02` | Break Up!、Beat Hit!、brave heart、装甲及联展音效 | 可按 `armorEvolution` 和 `jogress` 分开映射。导入者应按实际片段确认。 |
| `tamers` | EVO、One Vision、SLASH!!、Card Slash、Matrix Evolution | 发行目录有特定 Matrix Evolution 版本的 One Vision。导入时保留原版本信息，不按标题推断所有场景。 |
| `frontier` | With the Will、The Last Element、Spirit／Double Spirit／Hyper Spirit 片段 | 支持分开填写进化条件，具体音轨及场景需核对。 |
| `savers` | Believer、Digisoul、Burst Mode | 支持按事件和进化类型填写，具体音轨及场景需核对。 |
| `xrosWars` | WE ARE クロスハート！、DigiXros、Super Evolution | 支持按事件和进化类型填写，具体音轨及场景需核对。 |

曲目参考：[东映 Adventure 曲目](https://lineup.toei-anim.co.jp/ja/tv/dejimon/song/) · [东映电影音乐公告](https://www.toei-anim.co.jp/movie/digimon-adventure/last-evolution/news/inc/2019121701.php) · [唱片发行目录](https://www.feelmee.jp/index.php/item/product/655)。发布资料只用来核对曲名和公开的曲目用途。当前没有逐集核对其余世代的片段，也没有预置未经确认的曲目绑定。

现有进化动画约 3 秒。时间轴以触发音开始，约 0.2 秒播放设备响应，0.4 秒进化音乐进入，0.63 秒语音，1.2 秒新形态音效，2.85 秒完成提示并恢复背景音乐。导入适合上述时长的自有剪辑，整首长曲会在演出结束处淡出。原始首尾无空白的 WAV／CAF 适合连续循环，带编码延迟或文件本身静音的素材仍需在源文件中处理。已接入常用操作、喂食、训练、战斗和进化时间轴，喝水、洗澡及尚无对应玩法的特殊进化等目前保留事件 ID。

播放在前台遵循独立通道、背景压低、淡入淡出、按键预热和短间隔去重。进入后台停止播放，来电使用系统中断通知，后台及蓝牙耳机的具体行为仍需真机验收。系统本地通知保留文字，前台提醒播放用户导入的对应音频。

## 手机运动输入

增强模式和Sandbox可在设置打开运动输入训练。摇晃使用加速度，倾斜使用重力方向，步行使用系统计步，每10个实测步数触发一次所选按键。虚拟A/B持续可用，权限被拒或传感器不可用时仍能训练。不读取心率。在后台或离开页面时结束传感器采样。LCD亮度、按键触感、长按和组合键沿用现有控制，外壳增加呼叫与喂食灯点反馈。

目前保留现有机型名单，运动输入是独立手机玩法。其它机型及其专有素材没有加入。本阶段不生成IPA。
