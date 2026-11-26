# 侧装在线房间

普通WebSocket通信，不依赖Apple开发账号、Game Center或上架。双方填写同一个服务器地址和6～32位房间号即可连接；第一人等待，第二人加入后双方确认对战。房间只容纳两人，消息限制16KiB、协议2、独立房间隔离，并通知断线。

```sh
python3 -m venv .venv
.venv/bin/pip install -r Server/requirements.txt
.venv/bin/python -m unittest discover -s Server -p 'test_*.py'
HOST=0.0.0.0 PORT=8765 .venv/bin/python Server/relay.py
```

本机验证地址为`ws://127.0.0.1:8765`。两台手机连同一局域网时填写服务器电脑的实际局域网IP，例如`ws://192.168.1.10:8765`，并允许本地网络访问。公网部署必须使用HTTPS/WSS反向代理和有效证书；客户端拒绝公网明文WS。Dockerfile可供部署，公网地址须由实际服务器提供，不内置虚假的可用地址。

服务器只转发两端确认消息，不保存养成、账号或战绩，不是排名和反作弊裁决服务。房间号属于好友邀请信息，不应当作账号身份认证。正式/Sandbox隔离、机型、过期快照、联展和一次结算仍由客户端ConnectionEngine验证。真实公网两台iPhone连接和服务部署仍需验收。
