"""Check every bundled translation and interpolation before native builds."""
from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[1]
catalog=json.loads((root/'Sources/DigitalWorldCore/Resources/translations.json').read_text())
assert catalog['version']==1
assert len(catalog['entries'])>700
sources=set()
for entry in catalog['entries']:
    source=entry['source']
    assert source not in sources,source
    sources.add(source)
    assert '\\(' not in source,source
    expected=sorted(re.findall(r'\{\d+\}',source))
    for language in ['zh-Hant','en','ja']:
        value=entry['values'][language]
        assert value and sorted(re.findall(r'\{\d+\}',value))==expected,(source,language)
print('Validated',len(sources),'four-language entries and interpolation tokens')
