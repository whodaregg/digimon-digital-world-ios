import asyncio,json,unittest
from websockets.asyncio.client import connect
from websockets.asyncio.server import serve
from websockets.exceptions import ConnectionClosed
from relay import Relay,MAX_BYTES

class RelayTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.relay=Relay()
        self.server=await serve(self.relay.handle,'127.0.0.1',0,max_size=MAX_BYTES,ping_interval=None)
        self.address='ws://127.0.0.1:'+str(self.server.sockets[0].getsockname()[1])+'/room/'
    async def asyncTearDown(self):
        self.server.close();await self.server.wait_closed()
    async def test_two_players_relay_without_leaking_to_another_room(self):
        async with connect(self.address+'ABC123',proxy=None) as a:
            self.assertEqual(json.loads(await a.recv())['type'],'waiting')
            async with connect(self.address+'ABC123',proxy=None) as b,connect(self.address+'XYZ987',proxy=None) as other:
                self.assertEqual(json.loads(await a.recv())['type'],'ready')
                self.assertEqual(json.loads(await b.recv())['type'],'ready')
                await other.recv()
                packet=json.dumps({'kind':'hello','fighter':{'protocolVersion':2,'speciesID':'agumon'}})
                await a.send(packet);self.assertEqual(await b.recv(),packet)
                with self.assertRaises(asyncio.TimeoutError):await asyncio.wait_for(other.recv(),timeout=0.1)
            self.assertEqual(json.loads(await a.recv())['type'],'peer-left')
    async def test_third_player_is_rejected(self):
        async with connect(self.address+'ABC123',proxy=None) as a:
            await a.recv()
            async with connect(self.address+'ABC123',proxy=None) as b:
                await a.recv();await b.recv()
                async with connect(self.address+'ABC123',proxy=None) as third:
                    self.assertEqual(json.loads(await third.recv())['reason'],'room-full')
    async def test_clients_cannot_spoof_relay_control_events(self):
        async with connect(self.address+'ABC123',proxy=None) as a:
            await a.recv();await a.send(json.dumps({'type':'ready'}))
            self.assertEqual(json.loads(await a.recv())['reason'],'unsupported-packet')
            with self.assertRaises(ConnectionClosed):await a.recv()
    async def test_oversize_messages_close_before_forwarding(self):
        async with connect(self.address+'ABC123',proxy=None) as a:
            await a.recv();await a.send('x'*(MAX_BYTES+1))
            with self.assertRaises(ConnectionClosed):await a.recv()
if __name__=='__main__':unittest.main()
