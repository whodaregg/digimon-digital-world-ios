# 手机连接对战

当前同应用COLOR Ver.1/Ver.2之间的手机通信使用真实Multipeer Connectivity附近连接，或WebSocket在线房间。双方准备后交换伙伴快照，由相同的双方身份与随机标识计算同一场结果，各自先保存，再播放交替出招、命中、回避和胜败。v0.7协议为2，双方都须更新；确认消息携带已确认的伙伴快照，过期搜索和邀请回调不会跨会话使用。

通信演出参考COLOR资料：前三轮双方攻击均命中，第四轮决定胜负。它不复用Quest先中三次的回放规则。基础力量来自角色规则，四心和强力蛋参与修正；Sandbox可使用独立测试力量覆盖。

- 当前允许dmc-ver1/dmc-ver2组合，Sandbox与正式档案不能混战。
- Ver.1电光暴龙兽与Ver.2偃月加鲁鲁兽通信对战后，无论胜败，各自伙伴可联展为奥米加兽Alter-S。不消耗本机备份，不强行合并两份同机备份；重复收据不能再次联展或发奖。
- 清醒、无伤、成长期以上、有DP且无未完成训练才能准备。伙伴在等待中变化时拒绝使用过期快照。
- 双方确认后的记录有稳定通信ID；再次收到同一结果不会重复扣DP、增加战绩或进化战斗次数。
- 本协议用于朋友间对战，不是服务器裁决、排名或反作弊认证；存档校验也不是数字签名。
- Multipeer链路由系统选择可用本地网络，须允许本地网络权限。附近双机配对、断线与恢复仍待真实iPhone联调。
- 手机无线协议不能直接连接实体暴龙机，实体机物理通信属于独立硬件扩展，尚未实现。

## 侧装在线房间

按用户要求，默认使用普通WebSocket房间，不要求Apple开发账号或上架。连接页面填写已部署服务器地址和同一房间号，第一人等待，第二人进入后双方确认；结果仍由同一ConnectionEngine计算、保存、回放及防重放。

Server目录提供两人中继、依赖和Dockerfile。服务端限制房间人数、协议和消息大小，隔离不同房间并通知离开；不保存养成，不是排行榜裁决。客户端只允许公网WSS，本机/局域网可用WS测试。见[Server说明](../Server/README.md)。没有内置虚假的公网地址；实际公网使用需部署并填写地址，真实两台iPhone端到端待验收。

## 可选Game Center配置（侧装版默认不使用）

认证、系统匹配界面和可靠数据适配已写入ConnectionCoordinator，但当前Info.plist的GameCenterEnabled为false，普通构建不展示未配置的匹配按钮。

启用需项目所有者在Apple开发团队注册对应Bundle ID、启用Game Center并准备有效签名。工程提供配置命令：

```sh
python3 Scripts/configure_capabilities.py --team-id YOURTEAMID --bundle-id your.registered.bundle --game-center
```

命令验证公开的团队/Bundle标识，写入Configuration/Capabilities.json并重新生成工程、Game Center开关和entitlements；不保存证书或密码。validate_project.py按该配置校验，未配置团队时保持关闭。随后需两台已登录Game Center的真实iPhone验证认证、系统好友邀请/匹配、消息、断线和保存。当前仓库未包含项目所有者的开发团队配置，不宣称在线匹配已验收。

参考：[Apple Multipeer Connectivity](https://developer.apple.com/documentation/multipeerconnectivity)、[Apple GameKit](https://developer.apple.com/documentation/gamekit)、[COLOR说明资料](https://humulos.com/digimon/dmc/manual/)。
