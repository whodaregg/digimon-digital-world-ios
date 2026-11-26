"""Expand only COLOR profiles with an attributed, bundled rule and original sprite package."""
import json
from pathlib import Path

def extend_color(database,out):
    package=json.loads((Path(__file__).parent/'Data/color-ver2.json').read_text())
    rules=package['rules']; device=rules['deviceID']
    existing={s['id']:s for s in database['species']}
    for species in package['species']:
        if species['id'] in existing:
            existing[species['id']]['devices'].append(device)
        else:
            database['species'].append(species)
    database['version']=4
    database['devices'].insert(1,dict(id=device,name='Digital Monster COLOR Ver.2',enabled=True,
        verifiedOriginal=True,mode='original',notes='采用Ver.1/Ver.2共用说明书及Ver.2社区实测规则；独立名单、分支、作息、力量和Quest，支持与Ver.1指定角色通信联展。',
        hungerEveryMinutes=48,strengthEveryMinutes=48,wasteEveryMinutes=120,careGraceMinutes=10,
        freezeSupported=True,manualRestSupported=False,foods=['meat','protein'],eggs=['dmc-v2-egg']))
    database['eggs'].append(dict(id='dmc-v2-egg',name='Ver.2 数码蛋',hatchMinutes=1,species='punimon',pattern='stripes',requiredRaised=0))
    (out/'dmc-ver2.json').write_text(json.dumps(rules,ensure_ascii=False,indent=2)+'\n')
