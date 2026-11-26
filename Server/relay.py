"""Two-player room relay. Game validation and saving remain on the clients."""
import asyncio,json,os,re
from urllib.parse import urlsplit
from websockets.asyncio.server import serve
from websockets.exceptions import ConnectionClosed

MAX_BYTES=16_384
class Relay:
    def __init__(self):self.rooms={}
    async def send(self,peer,message):
        try:await peer.send(message)
        except ConnectionClosed:pass
    async def reject(self,peer,reason):
        await self.send(peer,json.dumps({'type':'error','reason':reason}))
        await peer.close(code=1008,reason=reason)
    async def handle(self,peer):
        path=urlsplit(peer.request.path).path.rstrip('/').split('/')
        if len(path)<3 or path[-2]!='room' or not re.fullmatch(r'[A-Z0-9-]{6,32}',path[-1]):
            await self.reject(peer,'invalid-room');return
        code=path[-1]
        if code not in self.rooms and len(self.rooms)>=128:
            await self.reject(peer,'server-full');return
        members=self.rooms.setdefault(code,set())
        if len(members)>=2:
            await self.reject(peer,'room-full');return
        members.add(peer)
        try:
            event=json.dumps({'type':'ready' if len(members)==2 else 'waiting'})
            for member in tuple(members):await self.send(member,event)
            async for message in peer:
                if len(message.encode() if isinstance(message,str) else message)>MAX_BYTES:
                    await self.reject(peer,'message-too-large');return
                try:
                    packet=json.loads(message)
                    if not isinstance(packet,dict) or packet.get('kind') not in ['hello','ready'] or not isinstance(packet.get('fighter'),dict) or packet['fighter'].get('protocolVersion')!=2:
                        raise ValueError('unsupported-packet')
                except (ValueError,TypeError):
                    await self.reject(peer,'unsupported-packet');return
                for member in tuple(members):
                    if member is not peer:await self.send(member,message)
        except ConnectionClosed:pass
        finally:
            members.discard(peer)
            if members:
                for member in tuple(members):await self.send(member,json.dumps({'type':'peer-left'}))
            elif self.rooms.get(code) is members:self.rooms.pop(code,None)

async def main():
    relay=Relay()
    async with serve(relay.handle,os.getenv('HOST','127.0.0.1'),int(os.getenv('PORT','8765')),
                     max_size=MAX_BYTES,max_queue=8,ping_interval=20,ping_timeout=20,close_timeout=5):
        print('Room relay started; use a TLS reverse proxy for public WSS.',flush=True)
        await asyncio.get_running_loop().create_future()
if __name__=='__main__':asyncio.run(main())
