"""Apply reviewed names and UI terminology to the bundled catalog without network access."""
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
path=root/'Sources/DigitalWorldCore/Resources/translations.json'
catalog=json.loads(path.read_text())
entries={entry['source']:entry for entry in catalog['entries']}
overrides=json.loads((root/'Scripts/Data/localization-overrides.json').read_text())
for source,values in overrides.items():
    entry=entries.setdefault(source,dict(source=source,values={}))
    entry['values'].update(values)
catalog['entries']=sorted(entries.values(),key=lambda entry:entry['source'])
path.write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
print('Applied reviewed localization terminology:',len(overrides))
