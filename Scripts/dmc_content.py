"""COLOR Ver.1 profile: manual operations plus attributed community measurements.

Kept separate from the legacy experimental balance; see RULE_SOURCES.md.
"""
import json

EXTRA = [
 ('devimon','Devimon','恶魔兽','惡魔獸','デビモン','champion','virus','Evil','Death Claw','claw',3),
 ('meramon','Meramon','火焰兽','火焰獸','メラモン','champion','data','Flame','Burning Fist','fire',3),
 ('airdramon','Airdramon','飞龙兽','飛龍獸','エアドラモン','champion','vaccine','Mythical Beast','Spinning Needle','wind',3),
 ('seadramon','Seadramon','海龙兽','海龍獸','シードラモン','champion','data','Aquatic','Ice Arrow','ice',3),
 ('mamemon','Mamemon','豆豆兽','豆豆獸','マメモン','ultimate','data','Mutant','Smiley Bomb','bomb',4),
 ('monzaemon','Monzaemon','熊仔兽','熊仔獸','もんざえモン','ultimate','vaccine','Puppet','Hearts Attack','heart',4),
 ('blitzgreymon','BlitzGreymon','电光暴龙兽','電光暴龍獸','ブリッツグレイモン','mega','virus','Cyborg','Plasma Stake','electric',5),
 ('banchomamemon','BanchoMamemon','番长豆豆兽','番長豆豆獸','バンチョーマメモン','mega','data','Mutant','Golden Rush','bomb',5),
 ('shinmonzaemon','ShinMonzaemon','真熊仔兽','真熊仔獸','しんもんざえモン','mega','vaccine','Puppet','Wonderful Heart','heart',5),
 ('omegamon-alter-s','Omegamon Alter-S','奥米加兽 Alter-S','奧米加獸 Alter-S','オメガモン Alter-S','ultra','virus','Holy Knight','Garuru Sword','sword',6),
]

# id, minimum weight, sleep hour (wake 08:00), evolution minutes,
# approximate heart loss minutes, maximum DP, medicine doses, base power.
STATS = [
 ('botamon',5,None,10,3,0,0,0), ('koromon',10,20,720,30,0,1,0),
 ('agumon',20,20,1440,48,20,2,30), ('betamon',20,21,1440,38,20,2,25),
 ('greymon',30,21,2160,59,30,1,50), ('tyrannomon',20,22,2160,59,30,2,45),
 ('devimon',40,23,2160,48,30,1,50), ('meramon',30,0,2160,48,30,2,45),
 ('airdramon',30,23,2160,38,30,1,50), ('seadramon',20,23,2160,38,30,2,45),
 ('numemon',10,0,2160,28,30,3,40), ('metalgreymon',40,20,2880,59,40,1,100),
 ('mamemon',5,23,2880,59,40,1,85), ('monzaemon',40,21,2880,48,40,1,100),
 ('blitzgreymon',50,23,0,59,50,1,170), ('banchomamemon',5,23,0,59,50,1,150),
 ('shinmonzaemon',40,23,0,48,50,2,170), ('omegamon-alter-s',40,23,0,66,50,1,200),
]

def profile():
    roster = {s[0]: dict(zip(('id','minimumWeight','sleepHour','evolutionMinutes','heartLossMinutes','maxDP','healDoses','power'),s)) for s in STATS}
    routes=[]
    def route(src,dst,priority=10,cm=(0,None),tr=(0,None),ov=(0,None),sd=(0,None),battles=0,prob=False,summary=''):
        routes.append(dict(id=f'{src}-to-{dst}',**{'from':src},target=dst,priority=priority,
            minimumMistakes=cm[0],maximumMistakes=cm[1],minimumTraining=tr[0],maximumTraining=tr[1],
            minimumOverfeeds=ov[0],maximumOverfeeds=ov[1],minimumSleepDisturbances=sd[0],
            maximumSleepDisturbances=sd[1],minimumBattles=battles,probabilistic=prob,summary=summary))
    route('botamon','koromon',summary='孵化后 10 分钟')
    route('koromon','agumon',cm=(0,3),summary='照顾失误 0～3 次')
    route('koromon','betamon',cm=(4,None),summary='照顾失误至少 4 次')
    route('agumon','greymon',cm=(0,3),tr=(32,None),summary='失误≤3、训练≥32')
    route('agumon','devimon',cm=(0,3),tr=(0,31),summary='失误≤3、训练≤31')
    route('agumon','tyrannomon',cm=(4,None),tr=(5,15),ov=(3,None),sd=(4,5),summary='失误≥4、训练5～15、满腹≥3、睡眠打扰4～5')
    route('agumon','meramon',cm=(4,None),tr=(16,None),ov=(3,None),sd=(6,None),summary='失误≥4、训练≥16、满腹≥3、睡眠打扰≥6')
    route('agumon','numemon',priority=0,cm=(4,None),summary='失误≥4且未满足其他分支')
    route('betamon','devimon',cm=(0,3),tr=(48,None),summary='失误≤3、训练≥48')
    route('betamon','meramon',cm=(0,3),tr=(0,47),summary='失误≤3、训练≤47')
    route('betamon','airdramon',cm=(4,None),tr=(8,31),ov=(0,3),sd=(9,None),summary='失误≥4、训练8～31、满腹≤3、睡眠打扰≥9')
    route('betamon','seadramon',cm=(4,None),tr=(8,31),ov=(4,None),sd=(0,8),summary='失误≥4、训练8～31、满腹≥4、睡眠打扰≤8')
    route('betamon','numemon',priority=0,cm=(4,None),summary='失误≥4且未满足其他分支')
    for src,dst in [('greymon','metalgreymon'),('devimon','metalgreymon'),('airdramon','metalgreymon'),('tyrannomon','mamemon'),('meramon','mamemon'),('seadramon','mamemon'),('numemon','monzaemon')]:
        route(src,dst,battles=15,prob=True,summary='成长期起累计至少15战；依通算胜率判定')
    for src,dst in [('metalgreymon','blitzgreymon'),('mamemon','banchomamemon'),('monzaemon','shinmonzaemon')]:
        route(src,dst,cm=(0,1),battles=15,prob=True,summary='本阶段失误≤1、至少15战；依通算胜率判定')
    areas=[
      [('betamon','virus',15),('agumon','vaccine',19),('meramon','data',23)],
      [('numemon','virus',19),('seadramon','data',23),('devimon','virus',28)],
      [('tyrannomon','data',28),('airdramon','vaccine',37),('greymon','vaccine',45)],
      [('seadramon','data',45),('meramon','data',55),('devimon','virus',65),('mamemon','data',80)],
      [('airdramon','vaccine',55),('tyrannomon','data',70),('greymon','vaccine',85),('metalgreymon','virus',105)],
      [('meramon','data',65),('mamemon','data',80),('monzaemon','vaccine',95),('banchomamemon','data',120)],
      [('numemon','virus',75),('metalgreymon','virus',90),('monzaemon','vaccine',110),('blitzgreymon','virus',130),('shinmonzaemon','vaccine',145)],
      [('metalgreymon','virus',85),('banchomamemon','data',100),('shinmonzaemon','vaccine',135),('blitzgreymon','virus',160),('omegamon-alter-s','virus',220)]]
    return dict(version=1,deviceID='dmc-ver1',manualURL='https://toy.bandai.co.jp/manuals/files/2645513.pdf',
      referenceURLs=['https://humulos.com/digimon/dmc/manual/','https://humulos.com/digimon/dmc/quest/','https://nhoko.xxxxxxxx.jp/digicolor.html','https://nhoko.xxxxxxxx.jp/dc-evo-list.html'],
      verificationNotes=['按官方说明书核对操作，隐藏阈值、敌人力量和心值下降周期使用社区实测资料；周期为分钟近似值。',
       '胜率60～69%的进化概率资料有分歧：本配置采用Humulos的50%，NHOKO记为25%，尚待实体机复核。',
       '完全体15战采用NHOKO的成长期与成熟期合计；究极体须在完全体阶段另战15次。',
       '实体机通信与联展尚未实现；手机同版本对战由独立通信模块处理；奥米加兽Alter-S仅作为最终关敌人，不会通过普通养成赠送。'],
      hatchSeconds=8,trainingPatterns=['BBBAA','ABABB','BABBA','ABBAB','AAABA','BBAAB','ABBBA','BAABB','BABAB','ABAAA'],
      roster=roster,evolutions=routes,areas=[dict(id=i,name='AREA '+('F' if i==8 else str(i)),
        opponents=[dict(speciesID=s,attribute=a,power=p) for s,a,p in enemies],
        backgroundReward={1:'grid',4:'dmc-logo',8:'box-art'}.get(i)) for i,enemies in enumerate(areas,1)])

def extend(database,out):
    rules=profile()
    database['version']=3
    # Legacy balance remains attached to Species for old saves; the original profile
    # exclusively reads the separate rule tables above.
    for s in database['species']:
        s['devices'].append('dmc-ver1')
    database['devices'].insert(0,dict(id='dmc-ver1',name='Digital Monster COLOR Ver.1',enabled=True,
      verifiedOriginal=True,mode='original',notes='以Ver.1说明书操作及社区实测数据实现彩色养成与8区顺序Quest；隐藏参数仍有待实体机复核。',
      hungerEveryMinutes=48,strengthEveryMinutes=48,wasteEveryMinutes=120,careGraceMinutes=10,
      freezeSupported=True,manualRestSupported=False,foods=['meat','protein'],eggs=['dmc-v1-egg']))
    database['eggs'].append(dict(id='dmc-v1-egg',name='Ver.1 数码蛋',hatchMinutes=1,species='botamon',pattern='spots',requiredRaised=0))
    (out/'dmc-ver1.json').write_text(json.dumps(rules,ensure_ascii=False,indent=2)+'\n')
