"""Native CI peer fixture; never launched or bundled by the application."""
import asyncio,json,uuid
from websockets.asyncio.client import connect

async def main():
    fighter=dict(protocolVersion=2,petID=str(uuid.uuid4()),nonce=str(uuid.uuid4()),deviceID='dmc-ver1',
                 speciesID='agumon',strength=4,traited=False,sandbox=False,powerOverride=None)
    async with connect('ws://127.0.0.1:8765/room/UITEST01',proxy=None) as peer:
        async for message in peer:
            packet=json.loads(message)
            if packet.get('type')=='ready':await peer.send(json.dumps(dict(kind='hello',fighter=fighter)))
            elif packet.get('kind')=='hello':await peer.send(json.dumps(dict(kind='ready',fighter=fighter)))
            elif packet.get('kind')=='ready':print('Native opponent received matching ready packet',flush=True)
            elif packet.get('type')=='peer-left':break
if __name__=='__main__':asyncio.run(main())
