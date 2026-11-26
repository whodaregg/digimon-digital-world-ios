"""Add the supplied character archive to the existing general care engine."""
import copy
import json
from pathlib import Path


def extend_archive(database):
    roster = json.loads((Path(__file__).parent / 'Data/archive-roster.json').read_text())
    device_id = 'character-archive'
    template = next(s for s in database['species'] if s['id'] == 'agumon')
    for entry in roster['entries']:
        species = copy.deepcopy(template)
        species.update(id=entry['id'], spriteID=entry['id'], name=entry['name'],
                       nameSC=entry['name'], nameTC=entry['name'], nameJP=entry['name'],
                       stage='待核对', attribute='unknown', type='待核对',
                       devices=[device_id], generation='user-supplied-dmall',
                       specialMove='通用攻击', effect='bubble', rarity='archive',
                       referenceURL=None, verifiedFields=[], evolutions=[],
                       balanceProvenance='original-balance; shared care and battle values; stage and evolution routes unverified')
        database['species'].append(species)
    device = copy.deepcopy(next(d for d in database['devices'] if d['id'] == 'ultimate-lab'))
    device.update(id=device_id, name='数码兽图集养成',
                  notes='844份上传图集可分别选择并独立养成。使用通用喂食、训练、对战、休息和成长规则；阶段与进化路线待补充。',
                  eggs=['founder'])
    database['devices'].append(device)
    database['version'] = 5
