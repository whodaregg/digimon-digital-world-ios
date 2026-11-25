"""Verify archived sprite bytes, atlas dimensions and nonblank frame references offline."""
from pathlib import Path
import hashlib
import json
import struct

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / 'Sources/DigitalWorldCore/Resources'

def validate():
    database = json.loads((RES/'database.json').read_text())
    manifest = json.loads((RES/'sprites.json').read_text())
    sources = json.loads((RES/'sprite-sources.json').read_text())
    assert manifest['schemaVersion'] == 2
    assert manifest['artStatus'] == 'archived-digital-monster-color'
    assert sources['upstreamCommit'] == '2b05afdaa5a2ebc306b22b4950d35bd55d62c4e0'
    ids = {species['spriteID'] for species in database['species']}
    assert ids == set(manifest['sprites']) == set(sources['files'])
    for key in sorted(ids):
        sheet = manifest['sprites'][key]
        source = sources['files'][key]
        data = (RES/source['file']).read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n', key
        assert hashlib.sha256(data).hexdigest() == source['sha256'], f'{key}: original bytes changed'
        width,height = struct.unpack('!II',data[16:24])
        assert (width,height) == (source['width'],source['height']), key
        assert (width,height) == (sheet['columns']*sheet['tileSize'],sheet['rows']*sheet['tileSize']), key
        available = set(source['availableFrameIndices'])
        assert 0 in available and 1 in available
        for action,animation in sheet['animations'].items():
            assert animation['frameIndices'] and animation['frameSeconds'] > 0, (key,action)
            assert all(i in available for i in animation['frameIndices']), f'{key}/{action}: blank pose'
        assert source['transform'].startswith('none;'), key
    print(f'Validated {len(ids)} archived color sheets: unchanged SHA-256, dimensions and nonblank frame mappings.')

if __name__ == '__main__':
    validate()
