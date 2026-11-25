"""Build the versioned test content and original pixel study sheets. No remote assets."""
import json
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Sources/DigitalWorldCore/Resources'

def evolution(target, minutes, priority=0, training=0, battles=0, wins=0, mistakes=None,
              min_mistakes=0, bond=0, item=None):
    return dict(id=f'to-{target}', target=target, priority=priority, stageMinutes=minutes,
                minimumTraining=training, minimumBattles=battles, minimumWinRate=wins,
                maximumMistakes=mistakes, minimumMistakes=min_mistakes, minimumHealth=25,
                minimumWeight=1, maximumWeight=999, minimumBond=bond, requiredItem=item,
                provenance='original-balance')

ENTRIES = [
    ('botamon', 'Botamon', '黑球兽', '黑球獸', 'ボタモン', 'baby1', 'unknown', 'Slime', 'Acid Bubbles', 'bubble', 0),
    ('koromon', 'Koromon', '滚球兽', '滾球獸', 'コロモン', 'baby2', 'unknown', 'Lesser', 'Foam', 'bubble', 1),
    ('agumon', 'Agumon', '亚古兽', '亞古獸', 'アグモン', 'rookie', 'vaccine', 'Reptile', 'Pepper Breath', 'fire', 2),
    ('betamon', 'Betamon', '蝌蚪兽', '蝌蚪獸', 'ベタモン', 'rookie', 'virus', 'Amphibian', 'Electric Shock', 'electric', 2),
    ('greymon', 'Greymon', '暴龙兽', '暴龍獸', 'グレイモン', 'champion', 'vaccine', 'Dinosaur', 'Mega Flame', 'fire', 3),
    ('tyrannomon', 'Tyrannomon', '巨龙兽', '巨龍獸', 'ティラノモン', 'champion', 'data', 'Dinosaur', 'Fire Breath', 'fire', 3),
    ('numemon', 'Numemon', '鼻涕兽', '鼻涕獸', 'ヌメモン', 'champion', 'virus', 'Mollusk', 'Poop Toss', 'sludge', 3),
    ('metalgreymon', 'MetalGreymon', '机械暴龙兽', '機械暴龍獸', 'メタルグレイモン', 'ultimate', 'virus', 'Cyborg', 'Giga Destroyer', 'missile', 4),
]
ROUTES = {
    'botamon': [evolution('koromon', 60)],
    'koromon': [evolution('agumon', 360, 10, training=3, mistakes=2), evolution('betamon', 360)],
    'agumon': [evolution('greymon', 1440, 20, training=12, battles=5, wins=.6, mistakes=3, bond=15),
               evolution('numemon', 1440, 10, min_mistakes=6), evolution('tyrannomon', 1440)],
    'betamon': [evolution('numemon', 1440, 10, min_mistakes=6), evolution('tyrannomon', 1440)],
    'greymon': [evolution('metalgreymon', 2880, 10, training=20, battles=10, wins=.6, mistakes=5, item='evolution-chip')],
}
species = []
verified = {'botamon', 'koromon', 'agumon', 'betamon', 'numemon'}
for key, name, sc, tc, jp, stage, attr, typ, move, effect, level in ENTRIES:
    species.append(dict(id=key, name=name, nameSC=sc, nameTC=tc, nameJP=jp, stage=stage,
        attribute=attr, type=typ, family=[], generation='initial-content', firstAppearance=None,
        devices=['ultimate-lab'], stats=dict(hp=35+level*30, attack=8+level*8,
        defense=5+level*6, speed=5+level*3, critical=5, stamina=100, dp=10),
        specialMove=move, effect=effect, rarity='test-content', sleepHour=21, wakeHour=7,
        lifespanMinutes=20160, spriteID=key, artStatus='original-test-art-not-official',
        referenceURL=f'https://digimon.net/reference_en/detail.php?directory_name={key}' if key in verified else None,
        verifiedFields=['name', 'stage', 'type', 'specialMove'] + (['attribute'] if attr != 'unknown' else []) if key in verified else [],
        balanceProvenance='original-balance; all stats, sleep, lifespan and routes are game-designed; translations pending review',
        evolutions=ROUTES.get(key, [])))

foods = []
for key, name, values in [
    ('meat', '肉', (25,0,1,0,0,1)), ('protein','蛋白质',(0,20,0,0,0,2)),
    ('fruit','水果',(15,0,8,5,0,1)), ('vegetable','蔬菜',(10,0,3,0,2,0)),
    ('energy','能量饮料',(0,0,0,30,-1,1)), ('special','特别食物',(20,10,15,10,5,2)),
    ('recovery','恢复食物',(10,0,0,10,15,1))]:
    foods.append(dict(id=key,name=name,**dict(zip(['fullness','strength','happiness','energy','health','weight'],values))))

base = dict(enabled=True, verifiedOriginal=False, mode='ultimate', hungerEveryMinutes=45,
            strengthEveryMinutes=90, wasteEveryMinutes=120, careGraceMinutes=30,
            freezeSupported=True, manualRestSupported=True, foods=[f['id'] for f in foods],
            eggs=['founder','signal'])
devices = [dict(base, id='ultimate-lab',name='Digital World · 1997 LAB',
                notes='原创融合规则，初代外形研究；不是实体 Ver.1 的精确模拟。')]
catalog = [
    ('dm1','Digital Monster Ver.1–5'), ('pendulum','Digimon Pendulum'),
    ('progress','Pendulum Progress'), ('pendulum-x','Pendulum X'), ('accel','Digimon Accel'),
    ('mini','Digimon Mini'), ('twin','Digimon Twin L / R'), ('catch','Digimon Catch'),
    ('dm20','Digital Monster Ver.20th'), ('pen20','Pendulum Ver.20th'), ('dmx','Digital Monster X Ver.1–3'),
    ('pendulum-z','Pendulum Z / Z II'), ('vital','Vital Bracelet / BE'), ('color','Digital Monster COLOR'),
    ('pen-color','Pendulum COLOR'), ('digivice99','Digivice 1999'), ('d3','D-3'), ('dark','D-Ark / D-Power'),
    ('scanner','D-Scanner'), ('ic','Digivice iC / Burst'), ('xros','Xros Loader'),
    ('appli','Appli Drive / DUO'), ('complete','Digivice Ver.15th / Complete'),
    ('25color','Digivice 25th COLOR EVOLUTION'), ('wave','ORIGINAL NEW WAVE'), ('revival','Digivice Ver.REVIVAL')]
for key, name in catalog:
    devices.append(dict(base,id=key,name=name,enabled=False,mode='original',
                        notes='计划目录；版本名单、说明书、规则与素材尚待逐项核实，暂不可游玩。'))

database = dict(version=1, species=species, devices=devices, foods=foods,
    eggs=[dict(id='founder',name='始源之蛋',hatchMinutes=5,species='botamon',pattern='spots',requiredRaised=0),
          dict(id='signal',name='信号之蛋',hatchMinutes=10,species='botamon',pattern='stripes',requiredRaised=3)],
    maps=[dict(id='signal-garden',name='信号花园 · 原创关卡',questTarget=3,
        enemies=['agumon','betamon','numemon'],rows=[
            '################', '#...#......C...#', '#...#..##......#', '#......##..~~..#',
            '#.C....#...~~..#', '#..###.#.......#', '#......#..C....#', '#..............#',
            '#...~~....##...#', '#...~~.........#', '#..............#', '################'])])
OUT.mkdir(parents=True, exist_ok=True)
(OUT/'database.json').write_text(json.dumps(database,ensure_ascii=False,indent=2)+'\n')

# 24x24 hand-built studies. Each species has its own silhouette and palette.
COLORS = [(53,58,64),(240,149,172),(240,174,58),(78,174,130),
          (214,137,45),(205,85,66),(103,169,76),(102,135,159)]
ANIMATIONS = ['idle','walk','happy','sad','hungry','eat','sleep','training','attack',
              'special','hit','injured','victory','defeat','evolution']

def png(path, width, height, pixels):
    def chunk(key, data):
        return struct.pack('!I',len(data))+key+data+struct.pack('!I',zlib.crc32(key+data)&0xffffffff)
    raw = b''.join(b'\x00'+bytes(pixels[y*width*4:(y+1)*width*4]) for y in range(height))
    path.write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!2I5B',width,height,8,6,0,0,0))+
                     chunk(b'IDAT',zlib.compress(raw))+chunk(b'IEND',b''))

def frame(index, action, frame):
    grid = [[None]*24 for _ in range(24)]
    body = COLORS[index]; ink=(35,43,47); light=tuple(min(255,c+37) for c in body)
    def rect(x,y,w,h,color):
        for yy in range(max(0,y),min(24,y+h)):
            for xx in range(max(0,x),min(24,x+w)): grid[yy][xx]=color
    def blob(x,y,w,h,color):
        rect(x+2,y,w-4,h,color);rect(x,y+2,w,h-4,color)
    shift = (-1 if frame==1 else 0) if action not in ['sleep','defeat'] else 2
    def r(x,y,w,h,c): rect(x,y+shift,w,h,c)
    if index in [0,1,6]:
        blob(5,10+shift,15,11,ink);blob(6,11+shift,13,9,body)
        if index==0:
            r(5,8,3,4,ink);r(10,7,2,4,ink);r(16,8,3,4,ink)
        if index==1:
            r(4,3,3,10,ink);r(5,4,1,8,body);r(17,2,3,11,ink);r(18,3,1,9,body)
        if index==6:
            r(7,8,3,4,ink);r(16,8,3,4,ink);r(8,8,1,4,(255,255,230));r(17,8,1,4,(255,255,230))
            r(5,19,16,2,body);r(11,18,6,2,(223,123,139))
        eyes=[(9,14),(16,14)]
    elif index==3:
        blob(3,11+shift,18,9,ink);blob(4,12+shift,16,7,body)
        r(8,5,4,7,(226,109,71));r(11,3,3,9,(226,109,71));r(14,6,3,6,(226,109,71))
        r(3,19,4,3,ink);r(17,19,4,3,ink);eyes=[(6,14),(17,14)]
    else:
        r(8,4,11,10,ink);r(9,5,9,8,body);r(16,8,6,6,ink);r(17,9,4,4,body)
        r(7,12,10,8,ink);r(8,12,8,7,body);r(3,14,6,4,ink);r(2,13,3,3,body)
        r(6,19,5,3,ink);r(14,19,5,3,ink);r(11,14,4,5,light)
        r(16,15,4+(frame if action in ['attack','special','training'] else 0),2,body)
        if index==4:
            r(7,3,12,5,(110,71,51));r(17,1,3,6,ink);r(8,1,2,4,ink)
            r(7,12,2,3,(95,74,72));r(13,16,2,3,(95,74,72))
        if index==5:
            r(7,2,3,4,body);r(10,1,3,4,body);r(7,12,3,6,(218,202,141))
            r(4,10,3,4,ink)
        if index==7:
            r(7,3,12,5,(174,187,194));r(13,5,9,5,(174,187,194));r(1,9,8,5,(99,107,144))
            r(1,7,4,4,ink);r(4,15,5,3,(174,187,194))
        eyes=[(14,7)]
    for x,y in eyes:
        if action in ['sleep','defeat'] or (action=='idle' and frame==2): r(x,y,3,1,ink)
        else:
            r(x,y,3,3,(250,250,230));r(x+1,y+1,2,2,ink)
    if action in ['happy','victory']:
        r(20,2,1,5,(231,185,65));r(18,4,5,1,(231,185,65))
    if action in ['hungry','eat']:
        r(19,16,4,3,(163,88,71));r(22,15,1,4,(250,240,220))
    if action in ['sad','injured']:
        r(19,12,2,4,(83,162,215))
    if action=='hit' and frame==1:
        grid=[[tuple(min(255,c+65) for c in pixel) if pixel else None for pixel in row] for row in grid]
    if action=='evolution':
        grid=[[((245,238,170) if pixel else None) if frame==1 else pixel for pixel in row] for row in grid]
    return grid

for i, entry in enumerate(ENTRIES):
    pixels=[0]*(72*360*4)
    for row, action in enumerate(ANIMATIONS):
        for f in range(3):
            for y, line in enumerate(frame(i,action,f)):
                for x, color in enumerate(line):
                    if color:
                        at=((row*24+y)*72+f*24+x)*4
                        pixels[at:at+4]=[*color,255]
    png(OUT/f'{entry[0]}.png',72,360,pixels)
(OUT/'sprites.json').write_text(json.dumps(dict(tileSize=24,columns=3,rows=15,
    artStatus='original-test-art-not-official',
    animations={name:dict(row=i,frames=3,frameSeconds=.22 if name!='sleep' else .65) for i,name in enumerate(ANIMATIONS)}),indent=2)+'\n')
print(f'Built {len(species)} species, {len(devices)} device records, {len(foods)} foods, 8 original study sheets.')
