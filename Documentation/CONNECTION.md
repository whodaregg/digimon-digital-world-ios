# 手机连接对战

当前同应用、同COLOR Ver.1规则之间的手机通信使用真实Multipeer Connectivity发现、广告、邀请/接受及可靠消息，不是预置对手或假联机。双方准备后交换伙伴快照，由相同的双方身份与随机标识计算同一场结果，各自先保存，再播放交替出招、命中、回避和胜败。

通信演出参考COLOR资料：前三轮双方攻击均命中，第四轮决定胜负。它不复用Quest先中三次的回放规则。基础力量来自角色规则，四心和强力蛋参与修正；Sandbox可使用独立测试力量覆盖。

- 当前兼容性仅允许dmc-ver1与dmc-ver1。Sandbox与正式档案不能混战。
- 清醒、无伤、成长期以上、有DP且无未完成训练才能准备。伙伴在等待中变化时拒绝使用过期快照。
- 双方确认后的记录有稳定通信ID；再次收到同一结果不会重复扣DP、增加战绩或进化战斗次数。
- 本协议用于朋友间对战，不是服务器裁决、排名或反作弊认证；存档校验也不是数字签名。
- Multipeer链路由系统选择可用本地网络，须允许本地网络权限。附近双机配对、断线与恢复仍待真实iPhone联调。
- 手机无线协议不能直接连接实体暴龙机，实体机物理通信属于独立硬件扩展，尚未实现。

## Game Center配置

认证、系统匹配界面和可靠数据适配已写入ConnectionCoordinator，但当前Info.plist的GameCenterEnabled为false，普通构建不展示未配置的匹配按钮。

启用需项目所有者在Apple开发团队注册对应Bundle ID并启用Game Center，在Xcode为应用加入Game Center能力/有效签名配置，并将GameCenterEnabled设为true。该开关由Scripts/generate_project.py管理，不能只改生成后的Info.plist；启用时必须同步生成器的能力/签名配置和validate_project.py的默认关闭检查。随后用两台已登录Game Center的真实iPhone验证认证、匹配、消息、断线和保存。当前未做该配置，也不宣称在线匹配已验收。

参考：[Apple Multipeer Connectivity](https://developer.apple.com/documentation/multipeerconnectivity)、[Apple GameKit](https://developer.apple.com/documentation/gamekit)、[COLOR说明资料](https://humulos.com/digimon/dmc/manual/)。
