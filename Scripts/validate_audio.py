"""Verify the bundled community recordings against their pinned source hashes."""
import hashlib
import json
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / 'Sources/DigitalWorldCore/Resources'
sources = json.loads((ROOT / 'Scripts/Data/community-audio-sources.json').read_text())
manifest = json.loads((RES / 'community-audio.json').read_text())
assert sources['commit'] == 'b4e3621a55f5906fc7a55107cce3eb7faaf5a60c'
assert len(sources['files']) == 19 and len(manifest['assets']) == 23
for item in sources['files'].values():
    path = RES / item['file']
    data = path.read_bytes()
    assert hashlib.sha256(data).hexdigest() == item['sha256']
    assert len(data) == item['bytes']
    with wave.open(str(path)) as recording:
        assert recording.getcomptype() == 'NONE'
        duration = recording.getnframes() / recording.getframerate()
        assert abs(duration - item['duration']) < 0.0001
        assert any(recording.readframes(recording.getnframes()))
for asset in manifest['assets']:
    item = next(v for v in sources['files'].values() if v['file'] == asset['originalFilename'])
    assert asset['sha256'] == item['sha256']
    assert asset['mapping']['category'] == 'COMMUNITY DEVICE RECORDING'
    assert asset['mapping'].get('deviceID') is None
    assert asset['mapping']['source'] == item['url']
print('Validated 19 unmodified WAV recordings and 23 community event mappings.')
