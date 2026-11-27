# 社区原机录音

v0.9.1 内置19份WAV，总计763,136字节，接入23个事件。安装后默认Hybrid Mode可使用这些音效，已有音量和静音选择继续生效。

## 来源

原始文件取自社区 `joeltco/tuipet` 的固定提交 `b4e3621a55f5906fc7a55107cce3eb7faaf5a60c`，该提交保留了DVPet归档的原始WAV。后续版本有重新合成与转换，本次保留所选历史WAV的原始字节。

DVPet公开资料将PenOG／DMOG录音贡献归于BladeSabre，但尚未完成每个文件与具体硬件型号的对应核对。清单类别为 `COMMUNITY DEVICE RECORDING`，资源不标为COLOR Ver.1或Ver.2专属原版。第三方权利声明继续保留，社区代码许可不扩展为官方音频发行授权。

[固定版本WAV目录](https://github.com/joeltco/tuipet/tree/b4e3621a55f5906fc7a55107cce3eb7faaf5a60c/src/tuipet/data/sounds) · [DVPet原作者发布页](https://theundersigned.itch.io/dvpet) · [录音贡献者资料](https://withthewill.net/threads/digimon-v-pet-fangame-for-pc-alpha.18418/)

## 使用

打开「设置 → 原版音频」。Hybrid Mode 下「混合模式使用社区原机录音」默认开启，按机型保存，可随时关闭。导入的匹配资源优先于内置社区音效。Classic Device Mode和Original Anime Mode继续按对应机型或动漫世代播放资源。

「试听社区按键录音」直接读取内置WAV。若听不到，检查游戏音效音量、系统音量、iPhone静音开关及蓝牙输出，可按需关闭「遵循iPhone静音模式」。试听失败会显示系统返回的错误。

已接入按键、菜单选择、确认、错误、孵化、呼叫、饥饿、喂食、吃肉、蛋白质、拒食、排泄、清理、训练成功/失败、战斗开始、攻击、特殊攻击、受伤、胜利/失败、进化触发及联展。多个事件共享同一录音时，同一次喂食序列只播放一次。

本组资源只含社区设备录音。动漫音乐与语音仍通过用户资源库导入，缺失时继续显示Missing Original Asset。

## 完整性

逐文件URL、提交、大小、时长和SHA-256位于 `Scripts/Data/community-audio-sources.json`。映射位于 `Sources/DigitalWorldCore/Resources/community-audio.json`，运行 `python3 Scripts/validate_audio.py` 核对原始字节、WAV格式、时长及事件清单。构建时由Swift Package打包，启动时校验内置文件哈希，读取直接使用应用Bundle，不依赖Files手动导入。

96项核心、24项界面、4项中继及Debug/Release模拟器构建均已通过，包含无需导入文件的真实WAV试听启动流程。[实测记录](VALIDATION.md)
