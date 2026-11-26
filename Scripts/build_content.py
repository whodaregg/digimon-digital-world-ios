"""Build versioned game content. Archived character PNGs are preserved unchanged."""
import json
import struct
import zlib
from pathlib import Path
from dmc_content import EXTRA, extend
from color_content import extend_color
from archive_content import extend_archive

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
ENTRIES += EXTRA
species = []
verified = {'botamon', 'koromon', 'agumon', 'betamon', 'numemon'}
for key, name, sc, tc, jp, stage, attr, typ, move, effect, level in ENTRIES:
    species.append(dict(id=key, name=name, nameSC=sc, nameTC=tc, nameJP=jp, stage=stage,
        attribute=attr, type=typ, family=[], generation='initial-content', firstAppearance=None,
        devices=['ultimate-lab'], stats=dict(hp=35+level*30, attack=8+level*8,
        defense=5+level*6, speed=5+level*3, critical=5, stamina=100, dp=10),
        specialMove=move, effect=effect, rarity='test-content', sleepHour=21, wakeHour=7,
        lifespanMinutes=20160, spriteID=key, artStatus='archived-digital-monster-color',
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
devices = [dict(base, id='ultimate-lab',name='Digital World · COLOR LAB',
                notes='采用 Digital Monster COLOR 角色像素图集的原创融合养成规则；不是实体机规则的精确模拟。')]
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

database = dict(version=2, species=species, devices=devices, foods=foods,
    eggs=[dict(id='founder',name='始源之蛋',hatchMinutes=5,species='botamon',pattern='spots',requiredRaised=0),
          dict(id='signal',name='信号之蛋',hatchMinutes=10,species='botamon',pattern='stripes',requiredRaised=3)],
    maps=[dict(id='signal-garden',name='信号花园 · 原创关卡',questTarget=3,
        enemies=['agumon','betamon','numemon'],rows=[
            '################', '#...#......C...#', '#...#..##......#', '#......##..~~..#',
            '#.C....#...~~..#', '#..###.#.......#', '#......#..C....#', '#..............#',
            '#...~~....##...#', '#...~~.........#', '#..............#', '################'])])
OUT.mkdir(parents=True, exist_ok=True)
extend(database,OUT)
extend_color(database,OUT)
extend_archive(database)
(OUT/'database.json').write_text(json.dumps(database,ensure_ascii=False,indent=2)+'\n')

print(f'Built {len(species)} species and content version {database["version"]}. Character PNGs are preserved unchanged.')
